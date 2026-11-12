import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'services/local_account_store.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, LocalAccountStore? localAccounts})
    : _auth = auth ?? FirebaseAuth.instance,
      _localAccounts = localAccounts ?? LocalAccountStore();

  final FirebaseAuth _auth;
  final LocalAccountStore _localAccounts;
  final StreamController<LocalAccount?> _localSessionController =
      StreamController<LocalAccount?>.broadcast();
  int _localSessionVersion = 0;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;
  AuthCredential? _pendingCredential;
  String? _pendingCredentialEmail;

  User? get currentUser => _auth.currentUser;
  Future<void> setRememberMe(bool remember) async {
    if (kIsWeb) {
      await _auth.setPersistence(
        remember ? Persistence.LOCAL : Persistence.SESSION,
      );
    }
  }

  Stream<User?> get userChanges => _auth.userChanges();

  Stream<LocalAccount?> get localSessionChanges =>
      Stream<LocalAccount?>.multi((controller) {
        final version = _localSessionVersion;
        final subscription = _localSessionController.stream.listen(
          controller.add,
          onError: controller.addError,
        );
        _localAccounts
            .activeAccount()
            .then((account) {
              if (!controller.isClosed && version == _localSessionVersion) {
                controller.add(account);
              }
            })
            .catchError((Object error, StackTrace stackTrace) {
              if (!controller.isClosed) {
                controller.addError(error, stackTrace);
              }
            });
        controller.onCancel = subscription.cancel;
      });

  void _publishLocalSession(LocalAccount? account) {
    _localSessionVersion++;
    _localSessionController.add(account);
  }

  Future<void> signInWithEmail(String email, String password) async {
    final localAccount = await _localAccounts.findByEmail(email);
    if (localAccount?.firebaseAccountCreated == true) {
      try {
        final result = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await _linkPendingCredential(result.user);
        await _localAccounts.clearActive();
        _publishLocalSession(null);
        return;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'network-request-failed') {
          throw AuthFailure(_messageFor(error));
        }
      }
    }

    if (localAccount != null) {
      if (!await _localAccounts.verifyPassword(localAccount, password)) {
        throw const AuthFailure('Email or password is incorrect.');
      }
      await _localAccounts.setActive(localAccount.uid);
      if (_auth.currentUser != null) await _auth.signOut();
      _publishLocalSession(localAccount);
      return;
    }
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _linkPendingCredential(result.user);
      await _localAccounts.clearActive();
      _publishLocalSession(null);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    }
  }

  Future<LocalAccount> createEmailAccount({
    required String displayName,
    required String email,
    required String password,
    String phoneNumber = '',
  }) async {
    if (await _localAccounts.findByEmail(email) != null) {
      throw const AuthFailure(
        'An account for this email already exists on this device.',
      );
    }
    if (_auth.currentUser != null) await _auth.signOut();
    final LocalAccount account;
    try {
      account = await _localAccounts.create(
        displayName: displayName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );
    } on StateError catch (error) {
      throw AuthFailure(error.message);
    }
    _publishLocalSession(account);
    return account;
  }

  Future<LocalAccount?> currentLocalAccount() => _localAccounts.activeAccount();

  Future<void> verifyLocalAccount({String? password}) async {
    final localAccount = await _localAccounts.activeAccount();
    if (localAccount == null) {
      await resendVerification();
      return;
    }

    final accountPassword = localAccount.pendingPassword ?? password;
    final currentUser = _auth.currentUser;
    if (currentUser?.email?.toLowerCase() == localAccount.email) {
      await currentUser!.reload();
      if (_auth.currentUser?.emailVerified == true) {
        await _localAccounts.markFirebaseAccountCreated(
          localAccount.uid,
          emailVerified: true,
        );
        _publishLocalSession(
          localAccount.copyWith(
            clearPendingPassword: true,
            firebaseAccountCreated: true,
            emailVerified: true,
          ),
        );
        return;
      }
      await resendVerification();
      await _localAccounts.markFirebaseAccountCreated(
        localAccount.uid,
        emailVerified: false,
      );
      _publishLocalSession(
        localAccount.copyWith(
          clearPendingPassword: true,
          firebaseAccountCreated: true,
        ),
      );
      return;
    }

    if (accountPassword == null) {
      throw const AuthFailure(
        'Enter your password to continue email verification.',
      );
    }
    User? user;
    try {
      user = (await _auth.signInWithEmailAndPassword(
        email: localAccount.email,
        password: accountPassword,
      )).user;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') {
        throw AuthFailure(_messageFor(error));
      }
      try {
        user = (await _auth.createUserWithEmailAndPassword(
          email: localAccount.email,
          password: accountPassword,
        )).user;
        await user?.updateDisplayName(localAccount.displayName);
      } on FirebaseAuthException catch (createError) {
        if (createError.code != 'email-already-in-use') {
          throw AuthFailure(_messageFor(createError));
        }
        try {
          user = (await _auth.signInWithEmailAndPassword(
            email: localAccount.email,
            password: accountPassword,
          )).user;
        } on FirebaseAuthException catch (signInError) {
          throw AuthFailure(_messageFor(signInError));
        }
      }
    }
    if (user == null) {
      throw const AuthFailure('The account could not be linked to Firebase.');
    }
    if (!user.emailVerified) await user.sendEmailVerification();
    await _localAccounts.markFirebaseAccountCreated(
      localAccount.uid,
      emailVerified: user.emailVerified,
    );
    _publishLocalSession(
      localAccount.copyWith(
        clearPendingPassword: true,
        firebaseAccountCreated: true,
        emailVerified: user.emailVerified,
      ),
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        return await _completeProviderSignIn(_auth.signInWithPopup(provider));
      }

      if (!_googleInitialized) {
        await _googleSignIn.initialize(
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? DefaultFirebaseOptions.ios.iosClientId
              : null,
          serverClientId:
              '546532456793-jnc2pa6iu10atffffhghcgl8l123mpao.apps.googleusercontent.com',
        );
        _googleInitialized = true;
      }
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(
          'Google did not return an ID token. Check this app’s OAuth setup.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _completeProviderSignIn(
        _auth.signInWithCredential(credential),
      );
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      _rememberPendingCredential(error);
      throw AuthFailure(_messageFor(error));
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('cancel')) {
        throw const AuthFailure('Google sign-in was cancelled.');
      }
      throw const AuthFailure(
        'Google sign-in could not start. Check the Firebase OAuth client and Android signing fingerprints.',
      );
    }
  }

  Future<UserCredential> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        final provider = FacebookAuthProvider()..addScope('email');
        return await _completeProviderSignIn(_auth.signInWithPopup(provider));
      }

      final rawNonce = _createNonce();
      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
        nonce: rawNonce,
      );
      if (result.status == LoginStatus.cancelled) {
        throw const AuthFailure('Facebook sign-in was cancelled.');
      }
      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw AuthFailure(
          result.message ?? 'Facebook sign-in could not be completed.',
        );
      }

      final token = result.accessToken!;
      final OAuthCredential credential;
      if (token is LimitedToken) {
        credential = OAuthProvider(
          'facebook.com',
        ).credential(idToken: token.tokenString, rawNonce: rawNonce);
      } else {
        credential = FacebookAuthProvider.credential(token.tokenString);
      }
      return await _completeProviderSignIn(
        _auth.signInWithCredential(credential),
      );
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      _rememberPendingCredential(error);
      throw AuthFailure(_messageFor(error));
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('cancel')) {
        throw const AuthFailure('Facebook sign-in was cancelled.');
      }
      throw const AuthFailure(
        'Facebook sign-in is not configured for this platform. Add the Facebook App ID, client token and URL scheme, then try again.',
      );
    }
  }

  Future<UserCredential> _completeProviderSignIn(
    Future<UserCredential> signIn,
  ) async {
    final result = await signIn;
    await _linkPendingCredential(result.user);
    await _localAccounts.clearActive();
    _publishLocalSession(null);
    return result;
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    }
  }

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Sign in again before requesting verification.');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    }
  }

  Future<void> refreshCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthFailure(
          'Sign in again before checking email verification.',
        );
      }
      await user.reload();
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // The Firebase session is still cleared if a provider is unavailable.
      }
      try {
        await FacebookAuth.instance.logOut();
      } catch (_) {
        // Facebook credentials may not be configured on this platform.
      }
    }
    await _auth.signOut();
    await _localAccounts.clearActive();
    _publishLocalSession(null);
  }

  Future<void> _linkPendingCredential(User? user) async {
    final credential = _pendingCredential;
    if (user == null || credential == null) return;
    if (_pendingCredentialEmail != null &&
        user.email?.toLowerCase() != _pendingCredentialEmail!.toLowerCase()) {
      return;
    }
    try {
      await user.linkWithCredential(credential);
      _pendingCredential = null;
      _pendingCredentialEmail = null;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'credential-already-in-use' ||
          error.code == 'provider-already-linked') {
        _pendingCredential = null;
        _pendingCredentialEmail = null;
        return;
      }
      throw AuthFailure(_messageFor(error));
    }
  }

  void _rememberPendingCredential(FirebaseAuthException error) {
    if (error.code == 'account-exists-with-different-credential' &&
        error.credential != null) {
      _pendingCredential = error.credential;
      _pendingCredentialEmail = error.email;
    }
  }

  String _createNonce([int length = 32]) {
    const characters =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
    'invalid-email' => 'Enter a valid email address.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for this email.',
    'weak-password' => 'Choose a stronger password with at least 8 characters.',
    'user-disabled' => 'This account is disabled. Contact NAYS support.',
    'too-many-requests' => 'Too many attempts. Wait a little and try again.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'operation-not-allowed' =>
      'This sign-in method is not enabled in Firebase.',
    'account-exists-with-different-credential' =>
      'An account already uses this email with another sign-in method. Sign in with that method to link it.',
    'credential-already-in-use' =>
      'This provider is already linked to another Firebase account.',
    _ => 'Authentication could not be completed. Please try again.',
  };
}

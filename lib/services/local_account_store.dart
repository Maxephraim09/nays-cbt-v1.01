import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'offline_exam_store.dart';

class LocalAccount {
  const LocalAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    required this.passwordSalt,
    required this.passwordHash,
    required this.pendingPassword,
    required this.firebaseAccountCreated,
    required this.emailVerified,
  });

  final String uid;
  final String email;
  final String displayName;
  final String phoneNumber;
  final String passwordSalt;
  final String passwordHash;
  final String? pendingPassword;
  final bool firebaseAccountCreated;
  final bool emailVerified;

  LocalAccount copyWith({
    String? pendingPassword,
    bool clearPendingPassword = false,
    bool? firebaseAccountCreated,
    bool? emailVerified,
  }) => LocalAccount(
    uid: uid,
    email: email,
    displayName: displayName,
    phoneNumber: phoneNumber,
    passwordSalt: passwordSalt,
    passwordHash: passwordHash,
    pendingPassword: clearPendingPassword
        ? null
        : pendingPassword ?? this.pendingPassword,
    firebaseAccountCreated:
        firebaseAccountCreated ?? this.firebaseAccountCreated,
    emailVerified: emailVerified ?? this.emailVerified,
  );

  Map<String, Object?> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'phoneNumber': phoneNumber,
    'passwordSalt': passwordSalt,
    'passwordHash': passwordHash,
    'pendingPassword': pendingPassword,
    'firebaseAccountCreated': firebaseAccountCreated,
    'emailVerified': emailVerified,
  };

  factory LocalAccount.fromMap(Map<String, dynamic> map) => LocalAccount(
    uid: map['uid'] as String,
    email: map['email'] as String,
    displayName: map['displayName'] as String,
    phoneNumber: map['phoneNumber'] as String? ?? '',
    passwordSalt: map['passwordSalt'] as String,
    passwordHash: map['passwordHash'] as String,
    pendingPassword: map['pendingPassword'] as String?,
    firebaseAccountCreated: map['firebaseAccountCreated'] as bool? ?? false,
    emailVerified: map['emailVerified'] as bool? ?? false,
  );
}

class LocalAccountStore {
  LocalAccountStore({CbtOfflineKeyStore? secureStore})
    : _secureStore = secureStore ?? FlutterCbtOfflineKeyStore();

  static const _accountPrefix = 'nays_local_account_';
  static const _emailPrefix = 'nays_local_email_';
  static const _activeKey = 'nays_local_active_account';
  static const _iterations = 120000;
  static final _passwordHasher = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  final CbtOfflineKeyStore _secureStore;

  Future<LocalAccount?> findByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;
    final uid = await _secureStore.read(_emailKey(normalizedEmail));
    if (uid == null) return null;
    return _readAccount(uid);
  }

  Future<LocalAccount?> activeAccount() async {
    final uid = await _secureStore.read(_activeKey);
    if (uid == null || uid.isEmpty) return null;
    final account = await _readAccount(uid);
    if (account == null) {
      await _secureStore.write(_activeKey, '');
      return null;
    }
    return account;
  }

  Future<LocalAccount> create({
    required String displayName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (await findByEmail(normalizedEmail) != null) {
      throw StateError(
        'An account for this email already exists on this device.',
      );
    }
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final hash = await _passwordHasher.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final uidBytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    final uid =
        'local_${uidBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    final account = LocalAccount(
      uid: uid,
      email: normalizedEmail,
      displayName: displayName.trim(),
      phoneNumber: phoneNumber.trim(),
      passwordSalt: base64Encode(salt),
      passwordHash: base64Encode(await hash.extractBytes()),
      pendingPassword: null,
      firebaseAccountCreated: false,
      emailVerified: false,
    );
    await _writeAccount(account);
    await _secureStore.write(_emailKey(normalizedEmail), uid);
    await setActive(uid);
    return account;
  }

  Future<bool> verifyPassword(LocalAccount account, String password) async {
    final hash = await _passwordHasher.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: base64Decode(account.passwordSalt),
    );
    final actual = await hash.extractBytes();
    final expected = base64Decode(account.passwordHash);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var index = 0; index < actual.length; index++) {
      difference |= actual[index] ^ expected[index];
    }
    return difference == 0;
  }

  Future<void> setActive(String uid) => _secureStore.write(_activeKey, uid);

  Future<void> clearActive() => _secureStore.write(_activeKey, '');

  Future<void> markFirebaseAccountCreated(
    String uid, {
    required bool emailVerified,
  }) async {
    final account = await _readAccount(uid);
    if (account == null) throw StateError('The local account is unavailable.');
    await _writeAccount(
      account.copyWith(
        clearPendingPassword: true,
        firebaseAccountCreated: true,
        emailVerified: emailVerified,
      ),
    );
  }

  Future<LocalAccount?> _readAccount(String uid) async {
    final stored = await _secureStore.read(_accountKey(uid));
    if (stored == null) return null;
    final account = LocalAccount.fromMap(
      jsonDecode(stored) as Map<String, dynamic>,
    );
    if (account.pendingPassword == null) return account;
    final sanitized = account.copyWith(clearPendingPassword: true);
    await _writeAccount(sanitized);
    return sanitized;
  }

  Future<void> _writeAccount(LocalAccount account) =>
      _secureStore.write(_accountKey(account.uid), jsonEncode(account.toMap()));

  String _accountKey(String uid) => '$_accountPrefix$uid';

  String _emailKey(String email) =>
      '$_emailPrefix${base64Url.encode(utf8.encode(email))}';
}

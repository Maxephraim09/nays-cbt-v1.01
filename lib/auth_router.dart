import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'auth_user_profile.dart';
import 'screens/auth_screens.dart';
import 'screens/entry_screens.dart';
import 'screens/main_shell.dart';
import 'services/local_account_store.dart';
import 'theme/app_theme.dart';

class AuthRouter extends StatefulWidget {
  const AuthRouter({
    required this.controller,
    required this.authService,
    super.key,
  });

  final DemoAppController controller;
  final FirebaseAuthService authService;

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  bool? _onboardingComplete;
  late Stream<LocalAccount?> _localSessionChanges;
  late Stream<User?> _userChanges;

  @override
  void initState() {
    super.initState();
    _bindAuthStreams();
    unawaited(_restoreOnboarding());
  }

  @override
  void didUpdateWidget(covariant AuthRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService) _bindAuthStreams();
  }

  void _bindAuthStreams() {
    _localSessionChanges = widget.authService.localSessionChanges;
    _userChanges = widget.authService.userChanges;
  }

  Future<void> _restoreOnboarding() async {
    final complete = await widget.controller.hasCompletedOnboarding();
    if (mounted) setState(() => _onboardingComplete = complete);
  }

  Future<void> _completeOnboarding() async {
    await widget.controller.completeOnboarding();
    if (mounted) setState(() => _onboardingComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) return const SplashScreen();
    if (_onboardingComplete == false) {
      return OnboardingScreen(onFinished: _completeOnboarding);
    }

    return StreamBuilder<LocalAccount?>(
      stream: _localSessionChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SplashScreen();
        }
        final localAccount = snapshot.data;
        if (localAccount != null) {
          return MainShell(
            controller: widget.controller,
            authService: widget.authService,
            profile: AuthUserProfile(
              uid: localAccount.uid,
              displayName: localAccount.displayName,
              email: localAccount.email,
              phoneNumber: localAccount.phoneNumber,
              photoUrl: null,
              providerIds: const ['password'],
              createdAt: null,
              emailVerified: localAccount.emailVerified,
              isLocalAccount: true,
            ),
          );
        }
        return StreamBuilder<User?>(
          stream: _userChanges,
          initialData: widget.authService.currentUser,
          builder: (context, authSnapshot) {
            if (authSnapshot.hasError) {
              return const _AuthUnavailableScreen();
            }
            if (authSnapshot.connectionState == ConnectionState.waiting &&
                !authSnapshot.hasData) {
              return const SplashScreen();
            }
            final user = authSnapshot.data;
            if (user == null) {
              return FirebaseLoginScreen(authService: widget.authService);
            }
            return MainShell(
              controller: widget.controller,
              authService: widget.authService,
              profile: AuthUserProfile.fromFirebaseUser(user),
            );
          },
        );
      },
    );
  }
}

class _AuthUnavailableScreen extends StatelessWidget {
  const _AuthUnavailableScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppTheme.brand(context),
            ),
            const SizedBox(height: 15),
            Text(
              'We could not check your sign-in status.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and restart the app. No account data was changed.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

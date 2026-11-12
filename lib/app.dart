import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth_router.dart';
import 'auth_service.dart';
import 'screens/cbt_screens.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';

class NaysApp extends StatefulWidget {
  const NaysApp({this.authService, super.key});
  final FirebaseAuthService? authService;

  @override
  State<NaysApp> createState() => _NaysAppState();
}

class _NaysAppState extends State<NaysApp> {
  late final _controller = DemoAppController();
  late final _authService = widget.authService ?? FirebaseAuthService();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => AppScope(
      controller: _controller,
      authService: _authService,
      child: MaterialApp(
        title: 'NAYS CBT',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _controller.themeMode,
        home: AuthRouter(controller: _controller, authService: _authService),
      ),
    ),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class FirebaseStartupFailureApp extends StatelessWidget {
  const FirebaseStartupFailureApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NAYS CBT',
    theme: AppTheme.light,
    home: PracticeSubjectsScreen(
      service: FirestoreCbtService(localUserId: 'local-device'),
    ),
  );
}

class AppScope extends InheritedNotifier<DemoAppController> {
  const AppScope({
    required this.controller,
    required this.authService,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  final DemoAppController controller;
  final FirebaseAuthService authService;
  static DemoAppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.controller;
  static FirebaseAuthService auth(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.authService;
}

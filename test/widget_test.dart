import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nays_mobile/app.dart';
import 'package:nays_mobile/app_state.dart';
import 'package:nays_mobile/auth_service.dart';
import 'package:nays_mobile/auth_user_profile.dart';
import 'package:nays_mobile/screens/cbt_screens.dart';
import 'package:nays_mobile/screens/auth_screens.dart';
import 'package:nays_mobile/screens/home_dashboard.dart';
import 'package:nays_mobile/screens/info_screens.dart';
import 'package:nays_mobile/screens/main_shell.dart';
import 'package:nays_mobile/screens/reminders_screen.dart';
import 'package:nays_mobile/screens/terms_of_service_screen.dart';
import 'package:nays_mobile/services/firestore_models.dart';
import 'package:nays_mobile/services/firestore_service.dart';
import 'package:nays_mobile/services/offline_exam_store.dart';
import 'package:nays_mobile/services/local_account_store.dart';
import 'package:nays_mobile/theme/app_theme.dart';

class _FakeFirestoreCbtService extends FirestoreCbtService {
  _FakeFirestoreCbtService({required this.subjects})
    : super(offlineStore: CbtOfflineExamStore(enableOfflineStorage: false));

  final List<NaysSubject> subjects;
  final Set<String> registeredIds = {};
  List<NaysAnnouncement> announcements = const [];
  Object? announcementError;
  final Map<String, dynamic> profileData = {};
  String? savedDisplayName;
  String? savedPhoneNumber;
  String? startedSubjectId;
  Object? startError;

  @override
  Future<List<NaysSubject>> fetchActiveSubjects() async => subjects;

  @override
  Stream<List<NaysSubject>> watchActiveSubjects() => Stream.value(subjects);

  @override
  Stream<List<NaysSubject>> watchQuestionBankSubjects() =>
      Stream.value(subjects);

  @override
  Stream<List<NaysSubject>> watchRegisteredSubjects() => Stream.value(
    subjects
        .where((subject) => registeredIds.contains(subject.subjectId))
        .toList(),
  );

  @override
  Future<void> registerSubject(String subjectId) async {
    registeredIds.add(subjectId);
  }

  @override
  Future<void> unregisterSubject(String subjectId) async {
    registeredIds.remove(subjectId);
  }

  @override
  Future<NaysCbtPreferences> fetchCbtPreferences() async =>
      const NaysCbtPreferences();

  @override
  Future<List<NaysAnnouncement>> fetchAnnouncements() async {
    final error = announcementError;
    if (error != null) throw error;
    return announcements;
  }

  @override
  Future<Map<String, dynamic>> loadAuthenticatedProfile() async => profileData;

  @override
  Future<void> updateUserProfile({
    required String displayName,
    required String phoneNumber,
  }) async {
    savedDisplayName = displayName;
    savedPhoneNumber = phoneNumber;
    profileData['fullName'] = displayName;
    profileData['phone'] = phoneNumber;
  }

  @override
  Future<CbtExamSession> startExam({required String subjectId}) async {
    final error = startError;
    if (error != null) throw error;
    startedSubjectId = subjectId;
    return CbtExamSession(
      sessionId: 'session-1',
      subjectId: subjectId,
      subjectName: 'Biology',
      startedAt: DateTime.now(),
      durationMinutes: 60,
      questions: const [
        CbtExamQuestion(
          questionId: 'question-1',
          questionText: 'Which process do green plants use to make their food?',
          questionType: 'multiple_choice',
          options: [
            CbtExamOption(key: 'A', text: 'Photosynthesis'),
            CbtExamOption(key: 'B', text: 'Respiration'),
          ],
          marks: 1,
        ),
      ],
    );
  }

  @override
  Future<OfflineExamAttempt?> loadActiveExam() async => null;

  @override
  Future<void> clearSavedExam(String sessionId) async {}

  @override
  Future<List<OfflineExamAttempt>> loadPendingSubmissions() async => const [];

  @override
  bool get supportsOfflineRecovery => false;

  @override
  Future<void> saveExamProgress({
    required CbtExamSession session,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) async {}

  @override
  Future<Map<String, dynamic>> submitExam({
    required String sessionId,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) async => {
    'score': 1,
    'totalMarks': 1,
    'percentage': 100,
    'correctAnswers': 1,
    'incorrectAnswers': 0,
    'unanswered': 0,
    'questionCount': 1,
    'timeSpent': 20,
    'status': 'completed',
  };

  @override
  Stream<List<NaysResult>> watchResults() => Stream.value(const []);

  @override
  Stream<List<NaysLeaderboardEntry>> watchLeaderboard({
    String subjectId = 'overall',
  }) => Stream.value(const []);
}

class _AutoSubmitService extends FirestoreCbtService {
  _AutoSubmitService()
    : super(
        localUserId: 'auto-submit-test',
        offlineStore: CbtOfflineExamStore(enableOfflineStorage: false),
      );

  bool submitted = false;

  @override
  Future<Map<String, dynamic>> submitExam({
    required String sessionId,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) async {
    submitted = true;
    return {
      'score': 0,
      'totalMarks': 1,
      'percentage': 0,
      'correctAnswers': 0,
      'incorrectAnswers': 0,
      'unanswered': 1,
      'questionCount': 1,
      'timeSpent': 7200,
      'status': 'completed',
      'topicPerformance': const <String, Object?>{},
    };
  }

  @override
  Future<void> clearSavedExam(String sessionId) async {}
}

class _MemorySecureStore implements CbtOfflineKeyStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

FirebaseAuthService _mockAuthService() => FirebaseAuthService(
  auth: MockFirebaseAuth(
    signedIn: false,
    mockUser: MockUser(
      uid: 'test-user',
      email: 'maxwell@example.com',
      displayName: 'Maxwell Ephraim',
      isEmailVerified: true,
    ),
  ),
  localAccounts: LocalAccountStore(secureStore: _MemorySecureStore()),
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('registered-subject names remain distinct by subject ID', () {
    final controller = DemoAppController();

    controller.setRegisteredSubjects({
      'biology-jss': 'Biology (JSS)',
      'biology-sss': 'Biology (SSS)',
    });

    expect(controller.registeredSubjectNamesById, {
      'biology-jss': 'Biology (JSS)',
      'biology-sss': 'Biology (SSS)',
    });
    expect(controller.subjects, ['Biology (JSS)', 'Biology (SSS)']);
  });

  test('legacy CBT preferences normalize to the supported exam limits', () {
    final preferences = NaysCbtPreferences.fromMap({
      'difficulty': 'invalid',
      'durationMinutes': 500,
      'questionsPerExam': 100,
      'shuffleQuestions': 'yes',
    });

    expect(preferences.difficulty, 'Mixed');
    expect(preferences.durationMinutes, 120);
    expect(preferences.questionsPerExam, 30);
    expect(preferences.shuffleQuestions, isTrue);
    expect(preferences.questionsPerExam, lessThanOrEqualTo(30));
  });
  testWidgets('onboarding leads to Firebase-backed login and dashboard', (
    tester,
  ) async {
    final service = _mockAuthService();
    await tester.pumpWidget(NaysApp(authService: service));
    await tester.pumpAndSettle();
    expect(find.text('GET READY TO GROW'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'maxwell@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Maxwell!'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);
  });

  testWidgets('onboarding renders all four bundled slides', (tester) async {
    await tester.pumpWidget(NaysApp(authService: _mockAuthService()));
    await tester.pumpAndSettle();
    const slideTitles = [
      'GET READY TO GROW',
      'PRACTISE WITH PURPOSE',
      'TRACK YOUR PROGRESS',
      'YOUR JOURNEY, YOUR PACE',
    ];
    for (var index = 0; index < slideTitles.length; index++) {
      expect(find.text(slideTitles[index]), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (index < slideTitles.length - 1) {
        await tester.tap(find.byKey(const ValueKey('onboarding-next')));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets(
    'registration works locally and allows email verification later',
    (tester) async {
      final auth = MockFirebaseAuth(verifyEmailAutomatically: false);
      final service = FirebaseAuthService(
        auth: auth,
        localAccounts: LocalAccountStore(secureStore: _MemorySecureStore()),
      );
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});

      await tester.pumpWidget(NaysApp(authService: service));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Create account'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('register-name')),
        'Amina Bello',
      );
      await tester.enterText(
        find.byKey(const ValueKey('register-email')),
        'amina@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('register-password')),
        'securePass123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('register-confirm-password')),
        'securePass123',
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('register-submit')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('register-submit')));
      await tester.pumpAndSettle();

      expect(auth.currentUser, isNull);
      expect(find.byKey(const ValueKey('nav-home')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-profile')));
      await tester.pumpAndSettle();
      expect(find.text('amina@example.com'), findsOneWidget);
      expect(find.text('Verify email'), findsOneWidget);
      expect(find.text('NAYS membership'), findsOneWidget);
    },
  );

  testWidgets('verified returning session restores the dashboard', (
    tester,
  ) async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'existing-member',
        email: 'member@example.com',
        displayName: 'Existing Member',
        isEmailVerified: true,
      ),
    );
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    await tester.pumpWidget(
      NaysApp(
        authService: FirebaseAuthService(
          auth: auth,
          localAccounts: LocalAccountStore(secureStore: _MemorySecureStore()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello, Existing!'), findsOneWidget);
    expect(find.text('NAYS membership not linked'), findsOneWidget);
  });

  testWidgets('password reset requests Firebase email safely', (tester) async {
    final service = FirebaseAuthService(auth: MockFirebaseAuth());
    await tester.pumpWidget(
      MaterialApp(home: FirebaseForgotPasswordScreen(authService: service)),
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-email')),
      'member@example.com',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'If an account exists for this address, a reset email has been sent.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('remember-me option is hidden on native platforms', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: FirebaseLoginScreen(authService: _mockAuthService())),
    );

    expect(find.text('Remember me'), findsNothing);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('announcements screen uses live data and a dynamic heading', (
    tester,
  ) async {
    final service = _FakeFirestoreCbtService(subjects: const []);
    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to NAYS CBT'), findsOneWidget);
    expect(find.text('No other announcements yet.'), findsOneWidget);
    expect(find.text('NAYS CBT is now available.'), findsNothing);

    service.announcements = const [
      NaysAnnouncement(
        announcementId: 'update-1',
        title: 'Exam schedule',
        message: 'The exam schedule is available.',
        image: '',
        isActive: true,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          key: const ValueKey('loaded-announcements'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Announcements'), findsWidgets);
    expect(find.text('Welcome to NAYS CBT'), findsOneWidget);
    expect(find.text('Exam schedule'), findsOneWidget);
    expect(find.text('The exam schedule is available.'), findsOneWidget);
  });

  testWidgets('home dashboard shows NAYS shortcuts and the default avatar', (
    tester,
  ) async {
    var selectedTab = -1;
    Widget? openedPage;
    final controller = DemoAppController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeDashboardTab(
            controller: controller,
            onTab: (tab) => selectedTab = tab,
            onOpen: (page) => openedPage = page,
          ),
        ),
      ),
    );

    expect(find.text('Hello, Student!'), findsOneWidget);
    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const ValueKey('home-avatar')),
    );
    expect(
      (avatar.backgroundImage! as AssetImage).assetName,
      'assets/images/avarta.png',
    );
    expect(find.text('My Results'), findsOneWidget);
    expect(find.text('JAMB\nSimulation'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('JAMB\nSimulation'));
    expect(selectedTab, -1);
    expect(openedPage, isA<JambSimulationWaitingScreen>());

    await tester.tap(find.text('Available\nExaminations'));
    expect(openedPage, isA<CbtAccessScreen>());
    await tester.tap(find.text('My Results'));
    expect(openedPage, isA<HistoryScreen>());
    await tester.scrollUntilVisible(
      find.text('Settings'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Settings'));
    expect(selectedTab, 2);
    await tester.scrollUntilVisible(
      find.text('Support'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Support'));
    expect(openedPage, isA<SupportScreen>());
    await tester.scrollUntilVisible(
      find.text('Reminders'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reminders'));
    expect(openedPage, isA<RemindersScreen>());
  });

  testWidgets('Profile tab uses the supplied default avatar asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MainShell(controller: DemoAppController())),
    );
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const ValueKey('profile-avatar')),
    );
    expect(
      (avatar.backgroundImage! as AssetImage).assetName,
      'assets/images/avarta.png',
    );
  });

  testWidgets('home support contact chips use readable light-mode colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeDashboardTab(
            controller: DemoAppController(),
            onTab: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Need Help?'),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
    expect(chips, hasLength(2));
    for (final chip in chips) {
      expect(chip.backgroundColor, Colors.white);
      expect((chip.label as Text).style?.color, AppTheme.forest);
      expect((chip.avatar as Icon).color, AppTheme.forest);
    }
  });

  testWidgets('JAMB timer, answers, and avatar stay readable in both themes', (
    tester,
  ) async {
    const questionId = 'jamb-visual-question';
    const photoUrl = 'https://example.test/profile.png';
    final question = CbtExamQuestion(
      questionId: questionId,
      questionText: 'Which option is correct?',
      questionType: 'multiple_choice',
      options: const [
        CbtExamOption(key: 'A', text: 'Option A'),
        CbtExamOption(key: 'B', text: 'Option B'),
      ],
      marks: 1,
      correctAnswer: 'A',
      explanation: 'Option A is correct.',
    );
    final profile = AuthUserProfile(
      uid: 'profile-user',
      displayName: 'Student',
      email: 'student@example.test',
      phoneNumber: null,
      photoUrl: photoUrl,
      providerIds: const [],
      createdAt: null,
      emailVerified: true,
    );

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final session = CbtExamSession(
        sessionId: 'jamb_local_visual',
        subjectId: 'english_language',
        subjectName: 'JAMB Simulation',
        startedAt: DateTime.now(),
        durationMinutes: 120,
        questions: [question],
      );
      final controller = DemoAppController()..setAnswer(questionId, 'A');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          builder: (context, child) => Theme(data: theme, child: child!),
          home: ExamScreen(
            controller: controller,
            service: FirestoreCbtService(localUserId: 'visual-test'),
            session: session,
            profile: profile,
          ),
        ),
      );
      await tester.pump();

      final timerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
      );
      final timer = tester.widget<Text>(timerFinder);
      expect(
        Theme.of(tester.element(timerFinder)).brightness,
        theme.brightness,
      );
      expect(
        timer.style?.color,
        theme.brightness == Brightness.dark ? Colors.white : AppTheme.forest,
      );
      expect(
        tester.widget<Text>(find.text('Option A')).style?.color,
        AppTheme.ink,
      );
      final profileImage = tester
          .widgetList<Image>(find.byType(Image))
          .where((image) => image.image is NetworkImage)
          .first;
      expect((profileImage.image as NetworkImage).url, photoUrl);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          builder: (context, child) => Theme(data: theme, child: child!),
          home: ReviewScreen(
            session: session,
            answers: const {questionId: 'A'},
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('Option A')).style?.color,
        AppTheme.ink,
      );
      expect(
        tester.widget<Text>(find.text('Option A is correct.')).style?.color,
        AppTheme.ink,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          builder: (context, child) => Theme(data: theme, child: child!),
          home: ExamScreen(
            controller: controller,
            service: FirestoreCbtService(localUserId: 'visual-test'),
            session: session,
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .any(
              (image) =>
                  image.image is AssetImage &&
                  (image.image as AssetImage).assetName ==
                      'assets/images/avarta.png',
            ),
        isTrue,
      );
    }
  });

  testWidgets('expired JAMB session submits automatically', (tester) async {
    final service = _AutoSubmitService();
    final session = CbtExamSession(
      sessionId: 'jamb_local_expired',
      subjectId: 'english_language',
      subjectName: 'JAMB Simulation',
      startedAt: DateTime.now().subtract(const Duration(minutes: 121)),
      durationMinutes: 120,
      questions: const [
        CbtExamQuestion(
          questionId: 'expired-question',
          questionText: 'Question',
          questionType: 'multiple_choice',
          options: [CbtExamOption(key: 'A', text: 'Option A')],
          marks: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          controller: DemoAppController(),
          service: service,
          session: session,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(service.submitted, isTrue);
    expect(find.text('Examination result'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard uses dark theme without layout exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: HomeDashboardTab(
            controller: DemoAppController(),
            onTab: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('home-dashboard'))),
      ).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings tab contains all secondary navigation and no drawer', (
    tester,
  ) async {
    final service = _FakeFirestoreCbtService(subjects: const []);
    final controller = DemoAppController();
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        authService: _mockAuthService(),
        child: MaterialApp(
          home: MainShell(controller: controller, firestoreService: service),
        ),
      ),
    );
    expect(find.byTooltip('Open menu'), findsNothing);
    expect(find.byKey(const ValueKey('nav-settings')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    for (final title in [
      'Exam history',
      'Notifications',
      'App settings',
      'Exams settings',
      'Help & support',
      'About NAYS',
      'Terms of service',
    ]) {
      expect(find.text(title), findsWidgets);
    }

    await tester.tap(find.byKey(const ValueKey('settings-link-0')));
    await tester.pumpAndSettle();
    expect(find.text('Exam history'), findsWidgets);
    expect(
      find.text('Completed examinations will appear here.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('settings-exams')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-exams')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('exams-settings-content')),
      findsOneWidget,
    );
    for (final destination in [
      ('exam-settings-register-subjects', 'Register subjects'),
      ('exam-settings-cbt', 'CBT settings'),
      ('exam-settings-jamb', 'JAMB Simulation Settings'),
      ('exam-settings-history', 'Exam history'),
    ]) {
      await tester.tap(find.byKey(ValueKey(destination.$1)));
      await tester.pumpAndSettle();
      expect(find.text(destination.$2), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('exams-settings-content')),
        findsOneWidget,
      );
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<NavigationBar>(find.byKey(const ValueKey('main-navigation')))
          .selectedIndex,
      2,
    );
  });

  testWidgets('Settings destinations open their matching screens', (
    tester,
  ) async {
    final controller = DemoAppController();
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        authService: _mockAuthService(),
        child: MaterialApp(
          home: MainShell(
            controller: controller,
            firestoreService: _FakeFirestoreCbtService(subjects: const []),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();

    for (final destination in [
      (1, 'Announcements'),
      (3, 'Help & support'),
      (4, 'About NAYS CBT'),
      (5, 'Terms of service'),
    ]) {
      final link = find.byKey(ValueKey('settings-link-${destination.$1}'));
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text(destination.$2), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Services navigation opens the CBT service screen', (
    tester,
  ) async {
    final service = _FakeFirestoreCbtService(subjects: const []);
    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(
          controller: DemoAppController(),
          firestoreService: service,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-services')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<NavigationBar>(find.byKey(const ValueKey('main-navigation')))
          .selectedIndex,
      1,
    );
    expect(find.byKey(const ValueKey('cbt-hub-content')), findsOneWidget);
    expect(find.text('CBT centre'), findsOneWidget);

    for (final destination in [
      ('cbt-register-subjects', 'Register subjects'),
      ('cbt-settings', 'CBT settings'),
      ('cbt-jamb-settings', 'JAMB Simulation Settings'),
      ('cbt-exam-history', 'Exam history'),
    ]) {
      final action = find.byKey(ValueKey(destination.$1));
      await tester.scrollUntilVisible(
        action,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text(destination.$2), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cbt-hub-content')), findsOneWidget);
    }
  });

  testWidgets('Services navigation keeps a local account on the selected tab', (
    tester,
  ) async {
    const localUid = 'local_services-test';
    final secureStore = _MemorySecureStore()
      ..values['nays_local_active_account'] = localUid
      ..values['nays_local_account_$localUid'] = jsonEncode({
        'uid': localUid,
        'email': 'learner@example.test',
        'displayName': 'Offline learner',
        'phoneNumber': '',
        'passwordSalt': '',
        'passwordHash': '',
        'pendingPassword': null,
        'firebaseAccountCreated': false,
        'emailVerified': false,
      });
    final localAccounts = LocalAccountStore(secureStore: secureStore);
    final authService = FirebaseAuthService(
      auth: MockFirebaseAuth(),
      localAccounts: localAccounts,
    );
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(NaysApp(authService: authService));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-services')));
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byKey(const ValueKey('cbt-hub-content')), findsOneWidget);
    expect(
      tester
          .widget<NavigationBar>(find.byKey(const ValueKey('main-navigation')))
          .selectedIndex,
      1,
    );
  });

  testWidgets('App settings opens privacy and omits exams settings', (
    tester,
  ) async {
    final service = _FakeFirestoreCbtService(subjects: const []);
    final controller = DemoAppController();
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        authService: _mockAuthService(),
        child: MaterialApp(
          home: MainShell(controller: controller, firestoreService: service),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-link-2')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy'), findsWidgets);
    expect(
      find.textContaining('NAYS CBT is designed to work offline.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-exams-settings')), findsNothing);
  });

  testWidgets('support includes contacts and local issue reporting', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
    expect(find.text('mgtechs09@gmail.com'), findsOneWidget);
    expect(find.text('08161595906'), findsOneWidget);
    expect(find.text('+2348161595906'), findsOneWidget);
    expect(find.byType(FaIcon), findsOneWidget);
    expect(find.text('Frequently asked questions'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('report-issue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unable to open practice');
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(find.text('Report recorded locally'), findsOneWidget);
    expect(find.textContaining('does not send issue reports'), findsOneWidget);
  });

  testWidgets('profile edits save name and phone to the account service', (
    tester,
  ) async {
    final service = _FakeFirestoreCbtService(subjects: const []);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileTab(onOpen: (_) {}, service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Naysa Student');
    await tester.enterText(find.byType(TextFormField).at(1), '+2348000000000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.savedDisplayName, 'Naysa Student');
    expect(service.savedPhoneNumber, '+2348000000000');
    expect(find.text('Naysa Student'), findsOneWidget);
    expect(find.text('+2348000000000'), findsOneWidget);
  });

  testWidgets('app settings displays version 1.0.1', (tester) async {
    await tester.pumpWidget(
      AppScope(
        controller: DemoAppController(),
        authService: _mockAuthService(),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    expect(find.text('App Version'), findsOneWidget);
    expect(find.text('v1.0.1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('App Version')).dy,
      greaterThan(tester.getTopLeft(find.text('Terms of use')).dy),
    );
    await tester.scrollUntilVisible(find.text('Log out'), 300);
    expect(
      tester.getTopLeft(find.text('Log out')).dy,
      greaterThan(tester.getTopLeft(find.text('App Version')).dy),
    );
  });

  testWidgets('JAMB settings displays the fixed PIN without an input field', (
    tester,
  ) async {
    const subjects = [
      NaysSubject(
        subjectId: 'english_language',
        subjectCode: 'ENG',
        subjectName: 'English Language',
        description: '',
        category: 'Arts',
        educationLevel: 'SSS',
        isActive: true,
        totalQuestions: 60,
      ),
      NaysSubject(
        subjectId: 'mathematics',
        subjectCode: 'MTH',
        subjectName: 'Mathematics',
        description: '',
        category: 'Science',
        educationLevel: 'SSS',
        isActive: true,
        totalQuestions: 40,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: JambSimulationSettingsScreen(
          service: _FakeFirestoreCbtService(subjects: subjects),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('JAMB Examination PIN'), findsOneWidget);
    expect(find.text('NAYSCBT1234'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('JAMB palette switches subjects and keeps local numbering', (
    tester,
  ) async {
    CbtExamQuestion makeQuestion({
      required String id,
      required String text,
      required String subjectId,
      required String subjectName,
    }) => CbtExamQuestion(
      questionId: id,
      questionText: text,
      questionType: 'multiple_choice',
      options: [CbtExamOption(key: 'A', text: '$text answer')],
      marks: 1,
      subjectId: subjectId,
      subjectName: subjectName,
    );

    final questions = [
      for (var index = 1; index <= 60; index++)
        makeQuestion(
          id: 'english-$index',
          text: 'English question $index',
          subjectId: 'english_language',
          subjectName: 'English Language',
        ),
      for (var index = 1; index <= 40; index++)
        makeQuestion(
          id: 'mathematics-$index',
          text: 'Mathematics question $index',
          subjectId: 'mathematics',
          subjectName: 'Mathematics',
        ),
    ];
    final session = CbtExamSession(
      sessionId: 'jamb_local_navigation',
      subjectId: 'english_language',
      subjectName: 'JAMB Simulation',
      startedAt: DateTime.now(),
      durationMinutes: 120,
      questions: questions,
    );
    final controller = DemoAppController();
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          controller: controller,
          service: _FakeFirestoreCbtService(subjects: const []),
          session: session,
        ),
      ),
    );
    await tester.pump();
    int remainingSeconds() {
      final timer = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
            ),
          )
          .single
          .data!;
      final parts = timer.split(':').map(int.parse).toList();
      return parts[0] * 3600 + parts[1] * 60 + parts[2];
    }

    ChoiceChip subjectChip(String label) => tester.widget<ChoiceChip>(
      find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
    );

    expect(find.text('QUESTION 1 OF 60'), findsOneWidget);
    expect(find.text('English question 1'), findsOneWidget);
    await tester.tap(find.text('English question 1 answer'));
    await tester.pump();
    expect(controller.answers['english-1'], 'A');

    await tester.tap(find.text('Question palette'));
    await tester.pumpAndSettle();
    expect(subjectChip('English Language').selected, isTrue);
    Finder paletteNumbers(String subjectId) => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'jamb-palette-$subjectId-',
          ),
    );
    expect(
      tester.widgetList<Widget>(paletteNumbers('english_language')).length,
      60,
    );
    expect(paletteNumbers('mathematics'), findsNothing);
    expect(subjectChip('English Language').selected, isTrue);

    final timeBeforeSubjectSwitch = remainingSeconds();
    await tester.tap(find.text('Mathematics'));
    await tester.pump();
    expect(find.text('QUESTION 1 OF 40'), findsOneWidget);
    expect(find.text('Mathematics question 1'), findsOneWidget);
    expect(subjectChip('Mathematics').selected, isTrue);
    expect(tester.widgetList<Widget>(paletteNumbers('mathematics')).length, 40);
    expect(paletteNumbers('english_language'), findsNothing);
    final lastMathDot = find.byKey(
      const ValueKey('jamb-palette-mathematics-40'),
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(of: lastMathDot, matching: find.byType(Text)),
          )
          .data,
      '40',
    );
    final lastMathQuestion = find.byKey(
      const ValueKey('jamb-palette-mathematics-2'),
    );
    await tester.tap(
      find.descendant(
        of: lastMathQuestion,
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    expect(find.text('QUESTION 2 OF 40'), findsOneWidget);
    expect(find.text('Mathematics question 2'), findsOneWidget);

    await tester.tap(find.text('English Language'));
    await tester.pump();
    expect(find.text('English question 1'), findsOneWidget);
    expect(subjectChip('English Language').selected, isTrue);
    expect(controller.answers['english-1'], 'A');
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(remainingSeconds(), lessThanOrEqualTo(timeBeforeSubjectSwitch));
    await tester.tap(
      find.byKey(const ValueKey('jamb-palette-english_language-2')),
    );
    await tester.pump();
    final answeredDot = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('jamb-palette-english_language-1')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(answeredDot.style?.backgroundColor?.resolve({}), AppTheme.forest);
  });

  testWidgets(
    'About and Terms screens show the supplied organization details',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
      expect(find.text('About NAYS CBT'), findsOneWidget);
      expect(find.textContaining('OUR MISSION'), findsOneWidget);
      expect(
        find.textContaining('MGTechs Smart Innovations Limited'),
        findsWidgets,
      );

      await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));
      expect(find.text('Terms of service'), findsOneWidget);
      expect(find.textContaining('Effective Date'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('GOVERNING LAW'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('GOVERNING LAW'), findsOneWidget);
    },
  );

  testWidgets('subject registration uses the local question-bank catalog', (
    tester,
  ) async {
    const subject = NaysSubject(
      subjectId: 'biology',
      subjectCode: 'BIO',
      subjectName: 'Biology',
      description: 'Life sciences',
      category: 'Science',
      educationLevel: 'JSS',
      isActive: true,
      totalQuestions: 1,
    );
    final controller = DemoAppController();
    final service = _FakeFirestoreCbtService(subjects: const [subject]);
    await tester.pumpWidget(
      MaterialApp(
        home: SubjectRegistrationScreen(
          controller: controller,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Biology'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(service.registeredIds, contains('biology'));
  });

  test('CBT preference state and answers use typed identifiers', () {
    final controller = DemoAppController();
    controller.updateSettings(
      nextDifficulty: 'Hard',
      nextDuration: 30,
      nextQuestionCount: 10,
    );
    controller.setAnswer('biology-q1', 'A');
    expect(controller.difficulty, 'Hard');
    expect(controller.durationMinutes, 30);
    expect(controller.questionsPerExam, 10);
    expect(controller.answers['biology-q1'], 'A');
  });

  test('saved appearance preferences are restored locally', () async {
    SharedPreferences.setMockInitialValues({
      'dark_theme': true,
      'notifications': false,
      'onboarding_complete': true,
    });
    final controller = DemoAppController();

    expect(await controller.hasCompletedOnboarding(), isTrue);
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.notificationsEnabled, isFalse);
  });

  testWidgets('exam access starts a server-backed session without a PIN', (
    tester,
  ) async {
    const subject = NaysSubject(
      subjectId: 'biology',
      subjectCode: 'BIO',
      subjectName: 'Biology',
      description: 'Life sciences',
      category: 'Science',
      educationLevel: 'JSS',
      isActive: true,
      totalQuestions: 1,
    );
    final controller = DemoAppController();
    controller.setRegisteredSubjects({'biology': 'Biology'});
    final service = _FakeFirestoreCbtService(subjects: const [subject])
      ..registeredIds.add('biology');
    await tester.pumpWidget(
      MaterialApp(
        home: CbtAccessScreen(
          controller: controller,
          service: service,
          selectedSubject: subject,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cbt-access-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(ExamScreen), findsOneWidget);
    expect(service.startedSubjectId, 'biology');
    expect(find.text('PIN'), findsNothing);
    expect(
      find.text('Which process do green plants use to make their food?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Photosynthesis'));
    await tester.pump();
    expect(controller.answers['question-1'], 'A');

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Exam'));
    await tester.pumpAndSettle();
    expect(find.text('Examination result'), findsOneWidget);
  });

  testWidgets('exam access explains when the callable service is missing', (
    tester,
  ) async {
    const subject = NaysSubject(
      subjectId: 'biology',
      subjectCode: 'BIO',
      subjectName: 'Biology',
      description: 'Life sciences',
      category: 'Science',
      educationLevel: 'JSS',
      isActive: true,
      totalQuestions: 1,
    );
    final service = _FakeFirestoreCbtService(subjects: const [subject])
      ..registeredIds.add('biology')
      ..startError = FirebaseFunctionsException(
        code: 'not-found',
        message: 'Function not found.',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: CbtAccessScreen(
          controller: DemoAppController(),
          service: service,
          selectedSubject: subject,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cbt-access-continue')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The exam service is not available yet. Please try again later or contact support.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ExamScreen), findsNothing);
  });

  testWidgets('CBT hub loads subjects and questions from the local catalog', (
    tester,
  ) async {
    const subject = NaysSubject(
      subjectId: 'biology-jss',
      subjectCode: 'JS-BIOLO',
      subjectName: 'Biology',
      description: 'Junior secondary biology',
      category: 'JSS',
      educationLevel: 'JSS',
      isActive: true,
      totalQuestions: 1,
    );
    final service = _FakeFirestoreCbtService(subjects: const [subject])
      ..registeredIds.add('biology-jss');
    final controller = DemoAppController();
    controller.setRegisteredSubjects({'biology-jss': 'Biology'});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CbtHubScreen(
            controller: controller,
            service: service,
            onOpen: (page) => Navigator.push(
              tester.element(find.byType(CbtHubScreen)),
              MaterialPageRoute<void>(builder: (_) => page),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Registered subjects'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);

    await tester.tap(find.text('Biology').first);
    await tester.pumpAndSettle();
    expect(find.byType(CbtPreparationScreen), findsOneWidget);
  });
}

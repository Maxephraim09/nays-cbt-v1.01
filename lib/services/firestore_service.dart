import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/nays_cbt_database.dart';
import 'jamb_simulation_config.dart';
import 'firestore_models.dart';
import 'offline_exam_store.dart';

class FirestoreCbtService {
  FirestoreCbtService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    NaysCbtDatabase? database,
    CbtOfflineExamStore? offlineStore,
    String? localUserId,
  }) : _providedFirestore = firestore,
       _providedAuth = auth,
       _providedFunctions = functions,
       _database = database ?? NaysCbtDatabase.instance,
       _providedLocalUserId = localUserId,
       _offlineStore =
           offlineStore ??
           CbtOfflineExamStore(database: database ?? NaysCbtDatabase.instance);

  final FirebaseFirestore? _providedFirestore;
  final FirebaseAuth? _providedAuth;
  final FirebaseFunctions? _providedFunctions;
  final NaysCbtDatabase _database;
  final String? _providedLocalUserId;
  final CbtOfflineExamStore _offlineStore;
  Future<List<Map<String, dynamic>>>? _syncInFlight;

  FirebaseFirestore get firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get auth => _providedAuth ?? FirebaseAuth.instance;
  FirebaseFunctions get functions =>
      _providedFunctions ??
      FirebaseFunctions.instanceFor(region: 'us-central1');

  String requireUid() {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in before accessing CBT data.');
    }
    return uid;
  }

  String get localUserId {
    final provided = _providedLocalUserId?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    try {
      return auth.currentUser?.uid ?? 'local-device';
    } on FirebaseException {
      return 'local-device';
    }
  }

  Future<Map<String, dynamic>> loadAuthenticatedProfile() async {
    final user = auth.currentUser;
    if (user == null && localUserId == 'local-device') {
      throw StateError('Sign in before loading your profile.');
    }
    final preferences = await SharedPreferences.getInstance();
    return {
      'fullName':
          preferences.getString(_profileNameKey(localUserId)) ??
          user?.displayName ??
          '',
      'email': user?.email ?? '',
      'phone':
          preferences.getString(_profilePhoneKey(localUserId)) ??
          user?.phoneNumber ??
          '',
      'profileImage': user?.photoURL ?? '',
    };
  }

  Future<void> updateUserProfile({
    required String displayName,
    required String phoneNumber,
  }) async {
    final user = auth.currentUser;
    if (user == null && localUserId == 'local-device') {
      throw StateError('Sign in before editing your profile.');
    }
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError('Enter your name.');
    final uid = user?.uid ?? localUserId;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileNameKey(uid), name);
    await preferences.setString(_profilePhoneKey(uid), phoneNumber.trim());
  }

  Future<bool> changeAccountPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError(
        'Sign in with an email account to change your password.',
      );
    }
    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    if (!hasPasswordProvider) {
      await auth.sendPasswordResetEmail(email: user.email!);
      return false;
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      ),
    );
    await user.updatePassword(newPassword);
    return true;
  }

  Future<List<NaysSubject>> fetchActiveSubjects() async {
    final rows = await _database.getSubjects();
    return rows.map(_subjectFromLocal).toList(growable: false);
  }

  Stream<List<NaysSubject>> watchActiveSubjects() =>
      watchQuestionBankSubjects();

  Stream<List<NaysSubject>> watchQuestionBankSubjects() => Stream.fromFuture(
    _database.getSubjects().then(
      (rows) => rows.map(_subjectFromLocal).toList(growable: false),
    ),
  );

  Future<List<String>> loadJambSubjectIds() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_jambSubjectsKey) ?? const [];
  }

  Future<void> saveJambSubjectIds(List<String> subjectIds) async {
    final subjects = await _database.getSubjects(activeOnly: false);
    final availableIds = subjects.map((subject) => subject['id']! as String);
    if (!JambSimulationConfig.isConfigured(
      subjectIds,
      availableSubjectIds: availableIds,
    )) {
      throw ArgumentError(
        'Select English Language and exactly three different available subjects.',
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_jambSubjectsKey, subjectIds);
  }

  String get _jambSubjectsKey => 'jamb_subjects_$localUserId';

  Future<CbtExamSession> startJambExam({
    required List<String> subjectIds,
  }) async {
    final uid = localUserId;
    final allSubjects = await _database.getSubjects(activeOnly: false);
    final subjectsById = {
      for (final subject in allSubjects)
        subject['id']! as String: subject['name']! as String,
    };
    if (!JambSimulationConfig.isConfigured(
      subjectIds,
      availableSubjectIds: subjectsById.keys,
    )) {
      throw StateError(
        'Configure English and three additional subjects first.',
      );
    }

    final savedPreferences = await _database.getExamPreferences(uid);
    final shuffleQuestions = savedPreferences?['shuffle_questions'] != 0;
    final shuffleOptions = savedPreferences?['shuffle_options'] == 1;
    final showExplanations = savedPreferences?['show_explanations'] != 0;
    final orderedSubjectIds = [
      JambSimulationConfig.englishSubjectId,
      ...subjectIds.where(
        (subjectId) => subjectId != JambSimulationConfig.englishSubjectId,
      ),
    ];
    final questionRows = <Map<String, Object?>>[];
    for (final subjectId in orderedSubjectIds) {
      await _ensureQuestionBankHas(
        subjectId: subjectId,
        subjectName: subjectsById[subjectId]!,
        requiredCount: JambSimulationConfig.questionCountFor(subjectId),
        difficulty: 'Mixed',
      );
      final rows = await _database.getExamQuestions(
        subjectId: subjectId,
        difficulty: 'Mixed',
        limit: JambSimulationConfig.questionCountFor(subjectId),
        shuffleQuestions: shuffleQuestions,
        shuffleOptions: shuffleOptions,
      );
      questionRows.addAll(
        rows.map((row) => {...row, 'subject_name': subjectsById[subjectId]}),
      );
    }
    final questionIds = questionRows.map((row) => row['id']).toSet();
    if (questionRows.length != JambSimulationConfig.totalQuestionCount ||
        questionIds.length != questionRows.length) {
      throw StateError(
        'The selected subject banks do not contain 180 unique questions.',
      );
    }
    final attemptId = 'jamb_local_${DateTime.now().microsecondsSinceEpoch}';
    await _database.startExamAttempt(
      attemptId: attemptId,
      userId: uid,
      subjectId: JambSimulationConfig.englishSubjectId,
      questionSnapshot: questionRows,
      requireRegistration: false,
    );
    return CbtExamSession(
      sessionId: attemptId,
      subjectId: JambSimulationConfig.englishSubjectId,
      subjectName: 'JAMB Simulation',
      startedAt: DateTime.now(),
      durationMinutes: JambSimulationConfig.durationMinutes,
      questions: questionRows
          .map(_localQuestionFromRow)
          .toList(growable: false),
      isOffline: true,
      showExplanations: showExplanations,
    );
  }

  Stream<List<NaysSubject>> watchRegisteredSubjects() {
    final uid = localUserId;
    return Stream.fromFuture(
      _database
          .getRegisteredSubjects(uid)
          .then((rows) => rows.map(_subjectFromLocal).toList(growable: false)),
    );
  }

  Future<void> registerSubject(String subjectId) async {
    await _database.registerSubject(userId: localUserId, subjectId: subjectId);
  }

  Future<void> unregisterSubject(String subjectId) async {
    await _database.unregisterSubject(
      userId: localUserId,
      subjectId: subjectId,
    );
  }

  Future<NaysCbtPreferences> fetchCbtPreferences() async {
    final uid = localUserId;
    final local = await _database.getExamPreferences(uid);
    if (local != null) {
      return NaysCbtPreferences.fromMap({
        'difficulty': local['difficulty'],
        'durationMinutes': local['duration_minutes'],
        'questionsPerExam': local['questions_per_exam'],
        'shuffleQuestions': local['shuffle_questions'] == 1,
        'shuffleAnswers': local['shuffle_options'] == 1,
        'showExplanations': local['show_explanations'] == 1,
        'negativeMarking': local['negative_marking'] == 1,
      });
    }

    const preferences = NaysCbtPreferences();
    await _savePreferencesLocally(uid, preferences);
    return preferences;
  }

  Stream<NaysCbtPreferences> watchCbtPreferences() =>
      Stream.fromFuture(fetchCbtPreferences());

  Future<void> saveCbtPreferences(NaysCbtPreferences preferences) async {
    if (preferences.durationMinutes < 15 ||
        preferences.durationMinutes > 120 ||
        preferences.questionsPerExam <
            NaysCbtPreferences.minimumQuestionsPerExam ||
        preferences.questionsPerExam >
            NaysCbtPreferences.maximumQuestionsPerExam ||
        !const [
          'Easy',
          'Medium',
          'Hard',
          'Mixed',
        ].contains(preferences.difficulty)) {
      throw ArgumentError('The selected CBT preferences are invalid.');
    }
    final uid = localUserId;
    await _savePreferencesLocally(uid, preferences);
  }

  Future<void> restoreAuthenticatedData() async {
    await _database.getRegisteredSubjects(localUserId);
    await fetchCbtPreferences();
  }

  Future<void> _savePreferencesLocally(
    String uid,
    NaysCbtPreferences preferences, {
    bool queueForSync = false,
    DateTime? updatedAt,
  }) => _database.saveExamPreferences(
    userId: uid,
    durationMinutes: preferences.durationMinutes,
    difficulty: preferences.difficulty,
    questionsPerExam: preferences.questionsPerExam,
    shuffleQuestions: preferences.shuffleQuestions,
    shuffleOptions: preferences.shuffleAnswers,
    showExplanations: preferences.showExplanations,
    negativeMarking: preferences.negativeMarking,
    queueForSync: queueForSync,
    updatedAt: updatedAt,
  );

  String _profileNameKey(String uid) => 'nays_profile_name_$uid';
  String _profilePhoneKey(String uid) => 'nays_profile_phone_$uid';

  Future<CbtExamSession> startExam({required String subjectId}) =>
      startOfflineExam(subjectId: subjectId);

  Future<CbtExamSession> startOfflineExam({required String subjectId}) async {
    final uid = localUserId;
    final registrations = await _database.getRegisteredSubjects(uid);
    if (!registrations.any((row) => row['id'] == subjectId)) {
      throw StateError('Register for this subject before starting an exam.');
    }
    final subjectRows = await _database.getSubjects(activeOnly: false);
    final subject = subjectRows.where((row) => row['id'] == subjectId);
    if (subject.isEmpty) {
      throw StateError('The selected subject is unavailable.');
    }

    final savedPreferences = await _database.getExamPreferences(uid);
    final preferences = savedPreferences == null
        ? const NaysCbtPreferences()
        : NaysCbtPreferences.fromMap({
            'difficulty': savedPreferences['difficulty'],
            'durationMinutes': savedPreferences['duration_minutes'],
            'questionsPerExam': savedPreferences['questions_per_exam'],
            'shuffleQuestions': savedPreferences['shuffle_questions'] == 1,
            'shuffleAnswers': savedPreferences['shuffle_options'] == 1,
            'showExplanations': savedPreferences['show_explanations'] == 1,
            'negativeMarking': savedPreferences['negative_marking'] == 1,
          });
    await _ensureQuestionBankHas(
      subjectId: subjectId,
      subjectName: subject.first['name']! as String,
      requiredCount: preferences.questionsPerExam,
      difficulty: preferences.difficulty,
    );
    final questionRows = await _database.getExamQuestions(
      subjectId: subjectId,
      difficulty: preferences.difficulty,
      limit: preferences.questionsPerExam,
      shuffleQuestions: preferences.shuffleQuestions,
      shuffleOptions: preferences.shuffleAnswers,
    );
    final attemptId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    await _database.startExamAttempt(
      attemptId: attemptId,
      userId: uid,
      subjectId: subjectId,
      questionSnapshot: questionRows,
    );
    final questions = questionRows
        .map((row) => _localQuestionFromRow(row))
        .toList(growable: false);
    return CbtExamSession(
      sessionId: attemptId,
      subjectId: subjectId,
      subjectName: subject.first['name'] as String,
      startedAt: DateTime.now(),
      durationMinutes: preferences.durationMinutes,
      questions: questions,
      isOffline: true,
      showExplanations: preferences.showExplanations,
    );
  }

  Future<CbtExamSession> loadPracticeSession({
    required String subjectId,
    String? difficulty,
    int? questionCount,
    String? topic,
  }) async {
    final uid = localUserId;
    final subjectRows = await _database.getSubjects(activeOnly: false);
    final subject = subjectRows.where((row) => row['id'] == subjectId);
    if (subject.isEmpty) {
      throw StateError('The selected subject is unavailable.');
    }
    final savedPreferences = await _database.getExamPreferences(uid);
    final preferences = savedPreferences == null
        ? const NaysCbtPreferences()
        : NaysCbtPreferences.fromMap({
            'difficulty': savedPreferences['difficulty'],
            'durationMinutes': savedPreferences['duration_minutes'],
            'questionsPerExam': savedPreferences['questions_per_exam'],
            'shuffleQuestions': savedPreferences['shuffle_questions'] == 1,
            'shuffleAnswers': savedPreferences['shuffle_options'] == 1,
            'showExplanations': savedPreferences['show_explanations'] == 1,
          });
    final selectedDifficulty = difficulty ?? preferences.difficulty;
    final selectedCount = questionCount ?? preferences.questionsPerExam;
    await _ensureQuestionBankHas(
      subjectId: subjectId,
      subjectName: subject.first['name']! as String,
      requiredCount: selectedCount,
      difficulty: selectedDifficulty,
      topic: topic,
    );
    final questionRows = await _database.getExamQuestions(
      subjectId: subjectId,
      difficulty: selectedDifficulty,
      topic: topic,
      limit: selectedCount,
      shuffleQuestions: preferences.shuffleQuestions,
      shuffleOptions: preferences.shuffleAnswers,
    );
    final sessionId = 'practice_${DateTime.now().microsecondsSinceEpoch}';
    await _database.startPracticeSession(
      sessionId: sessionId,
      userId: uid,
      subjectId: subjectId,
      difficulty: selectedDifficulty,
      questionSnapshot: questionRows,
    );
    return CbtExamSession(
      sessionId: sessionId,
      subjectId: subjectId,
      subjectName: subject.first['name'] as String,
      startedAt: DateTime.now(),
      durationMinutes: preferences.durationMinutes,
      questions: questionRows
          .map(_localQuestionFromRow)
          .toList(growable: false),
      isOffline: true,
      showExplanations: preferences.showExplanations,
    );
  }

  Future<int> getAvailablePracticeQuestionCount({
    required String subjectId,
    required String difficulty,
    String? topic,
  }) => _database.getEligibleQuestionCount(
    subjectId: subjectId,
    difficulty: difficulty,
    topic: topic,
  );

  Future<void> _ensureQuestionBankHas({
    required String subjectId,
    required String subjectName,
    required int requiredCount,
    required String difficulty,
    String? topic,
  }) async {
    final available = await _database.getEligibleQuestionCount(
      subjectId: subjectId,
      difficulty: difficulty,
      topic: topic,
    );
    if (subjectId == 'yungur' && available == 0) {
      throw StateError(
        'The Yungur question bank is awaiting the official source document. '
        'No examination questions are available yet.',
      );
    }
    if (available < requiredCount) {
      throw StateError(
        'Only $available local questions are available for $subjectName; '
        '$requiredCount are required.',
      );
    }
  }

  Future<List<String>> getPracticeTopics(String subjectId) =>
      _database.getQuestionTopics(subjectId);

  Future<void> savePracticeAnswer({
    required String sessionId,
    required String questionId,
    required Object selectedAnswer,
  }) => _database.savePracticeAnswer(
    sessionId: sessionId,
    questionId: questionId,
    selectedAnswer: selectedAnswer,
  );

  Future<Map<String, Object?>> completePracticeSession({
    required String sessionId,
    required int timeSpentSeconds,
  }) => _database.completePracticeSession(
    sessionId: sessionId,
    timeSpentSeconds: timeSpentSeconds,
  );

  Future<List<Map<String, Object?>>> loadPracticeHistory() =>
      _database.getPracticeHistory(localUserId);

  Future<List<Map<String, Object?>>> loadPracticeReview(String sessionId) =>
      _database.getPracticeReview(sessionId);

  CbtExamQuestion _localQuestionFromRow(Map<String, Object?> row) {
    final questionType = row['question_type'] as String;
    final rawOptions = row['options'] as List;
    final rawAnswer = row['correct_answer'];
    final correctAnswer =
        rawAnswer is String && questionType == 'multiple_select'
        ? jsonDecode(rawAnswer)
        : rawAnswer;
    return CbtExamQuestion(
      questionId: row['id'] as String,
      questionText: row['question_text'] as String,
      questionType: questionType,
      options: rawOptions
          .map((option) {
            final item = Map<String, Object?>.from(option as Map);
            return CbtExamOption(
              key: item['option_key'] as String,
              text: item['option_text'] as String,
              image: item['image_path'] as String?,
            );
          })
          .toList(growable: false),
      marks: row['marks'] as num,
      topic: row['topic'] as String,
      subtopic: row['subtopic'] as String? ?? '',
      difficulty: row['difficulty'] as String,
      subjectId: row['subject_id'] as String? ?? '',
      subjectName: row['subject_name'] as String? ?? '',
      image: row['image_path'] as String?,
      correctAnswer: correctAnswer,
      explanation: row['explanation'] as String,
    );
  }

  Future<void> saveLocalExamProgress({
    required CbtExamSession session,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) async {
    if (!session.isOffline) {
      throw ArgumentError('Local progress requires an offline exam session.');
    }
    await _database.saveExamProgress(
      attemptId: session.sessionId,
      answers: answers,
      currentQuestionIndex: currentQuestionIndex,
    );
  }

  Future<Map<String, dynamic>> submitLocalExam({
    required CbtExamSession session,
    required int durationSeconds,
  }) async {
    if (!session.isOffline) {
      throw ArgumentError('Local submission requires an offline exam session.');
    }
    final result = await _database.submitExamAttempt(
      attemptId: session.sessionId,
      durationSeconds: durationSeconds,
    );
    return {
      'status': 'completed_offline',
      'percentage': result['percentage'],
      'correctAnswers': result['correct_answers'],
      'incorrectAnswers': result['wrong_answers'],
      'unanswered': result['unanswered'],
      'questionCount': result['total_questions'],
      'score': result['score'],
      'totalMarks': result['total_marks'],
      'timeSpent': result['time_used'],
      'topicPerformance': jsonDecode(result['topic_performance']! as String),
    };
  }

  Future<Map<String, dynamic>> submitExam({
    required String sessionId,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) async {
    try {
      return await _callSubmitExam(
        sessionId: sessionId,
        answers: answers,
        offlineSubmission: false,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!supportsOfflineRecovery ||
          !const {'unavailable', 'internal', 'unknown'}.contains(error.code)) {
        rethrow;
      }
      await queueOfflineSubmission(
        sessionId: sessionId,
        answers: answers,
        currentQuestionIndex: currentQuestionIndex,
      );
      throw CbtSubmissionQueuedException();
    }
  }

  Future<Map<String, dynamic>> _callSubmitExam({
    required String sessionId,
    required Map<String, dynamic> answers,
    required bool offlineSubmission,
  }) async {
    final result = await functions.httpsCallable('submitCbtExam').call({
      'sessionId': sessionId,
      'answers': answers,
      'offlineSubmission': offlineSubmission,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> saveExamProgress({
    required CbtExamSession session,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) => _offlineStore.saveProgress(
    uid: localUserId,
    session: session,
    answers: answers,
    currentQuestionIndex: currentQuestionIndex,
  );

  Future<OfflineExamAttempt?> loadActiveExam() async {
    final uid = localUserId;
    final local = await _database.getActiveExamAttempt(uid);
    if (local != null) {
      final rawQuestions =
          jsonDecode(local['question_snapshot']! as String) as List;
      final questions = rawQuestions
          .map(
            (row) =>
                _localQuestionFromRow(Map<String, Object?>.from(row as Map)),
          )
          .toList(growable: false);
      final subjectRows = await _database.getSubjects(activeOnly: false);
      final subjectId = local['subject_id']! as String;
      final subject = subjectRows.firstWhere((row) => row['id'] == subjectId);
      final preferences = await _database.getExamPreferences(uid);
      final rawAnswers = Map<String, Object?>.from(local['answers']! as Map);
      final answers = <String, dynamic>{
        for (final entry in rawAnswers.entries)
          entry.key: _decodeStoredAnswer(
            entry.value,
            isMultipleSelect:
                questions
                    .firstWhere((question) => question.questionId == entry.key)
                    .questionType ==
                'multiple_select',
          ),
      };
      return OfflineExamAttempt(
        session: CbtExamSession(
          sessionId: local['id']! as String,
          subjectId: subjectId,
          subjectName: (local['id']! as String).startsWith('jamb_local_')
              ? 'JAMB Simulation'
              : subject['name'] as String,
          startedAt: DateTime.parse(local['started_at']! as String),
          durationMinutes: (local['id']! as String).startsWith('jamb_local_')
              ? JambSimulationConfig.durationMinutes
              : (preferences?['duration_minutes'] as int?) ?? 60,
          questions: questions,
          isOffline: true,
          showExplanations: preferences?['show_explanations'] != 0,
        ),
        answers: answers,
        currentQuestionIndex: local['current_question_index'] as int? ?? 0,
        isPendingSubmission: false,
      );
    }
    return _offlineStore.loadActiveAttempt(uid);
  }

  dynamic _decodeStoredAnswer(Object? value, {required bool isMultipleSelect}) {
    if (value is! String || !isMultipleSelect) return value;
    try {
      return jsonDecode(value);
    } on FormatException {
      return value;
    }
  }

  Future<List<OfflineExamAttempt>> loadPendingSubmissions() =>
      _offlineStore.loadPendingSubmissions(localUserId);

  Future<void> queueOfflineSubmission({
    required String sessionId,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) async {
    final attempt = await _offlineStore.loadActiveAttempt(requireUid());
    if (attempt == null || attempt.session.sessionId != sessionId) {
      throw StateError('The active offline exam could not be recovered.');
    }
    await _offlineStore.queueSubmission(
      uid: requireUid(),
      session: attempt.session,
      answers: answers,
      currentQuestionIndex: currentQuestionIndex,
    );
  }

  Future<List<Map<String, dynamic>>> syncPendingSubmissions() {
    final activeSync = _syncInFlight;
    if (activeSync != null) return activeSync;
    late final Future<List<Map<String, dynamic>>> sync;
    sync = _performPendingSync().whenComplete(() {
      if (identical(_syncInFlight, sync)) _syncInFlight = null;
    });
    _syncInFlight = sync;
    return sync;
  }

  Future<List<Map<String, dynamic>>> _performPendingSync() async {
    final uid = requireUid();
    final pending = await _offlineStore.loadPendingSubmissions(uid);
    final synchronized = <Map<String, dynamic>>[];
    for (final attempt in pending) {
      final result = await _callSubmitExam(
        sessionId: attempt.session.sessionId,
        answers: attempt.answers,
        offlineSubmission: true,
      );
      await _offlineStore.deleteAttempt(
        uid: uid,
        sessionId: attempt.session.sessionId,
      );
      synchronized.add(result);
    }
    return synchronized;
  }

  Future<int> syncPendingChanges() async {
    final pending = await _database.getPendingSyncItems(localUserId);
    for (final item in pending) {
      await _database.markSyncQueueCompleted(item['id']! as int);
    }
    return pending.length;
  }

  Future<void> retryFailedChanges() =>
      _database.retryFailedSyncItems(localUserId);

  Future<void> clearSavedExam(String sessionId) =>
      _offlineStore.deleteAttempt(uid: localUserId, sessionId: sessionId);

  bool get supportsOfflineRecovery => _offlineStore.isSupported;
  bool get hasAuthenticatedUser {
    try {
      return auth.currentUser?.uid.isNotEmpty == true;
    } on FirebaseException catch (error) {
      if (error.code == 'no-app') return false;
      rethrow;
    }
  }

  Stream<List<NaysResult>> watchResults() {
    final uid = localUserId;
    return Stream.fromFuture(
      _database
          .getExamResults(uid)
          .then(
            (rows) => rows.map(NaysResult.fromLocalMap).toList(growable: false),
          ),
    );
  }

  Future<List<NaysResult>> fetchOlderResults({
    required NaysResult after,
    int pageSize = 50,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Must be between 1 and 100.',
      );
    }
    final rows = await _database.getExamResults(localUserId);
    final results = rows
        .map(NaysResult.fromLocalMap)
        .where((result) => result.submittedAt.isBefore(after.submittedAt));
    return results.take(pageSize).toList(growable: false);
  }

  Stream<List<NaysLeaderboardEntry>> watchLeaderboard({
    String subjectId = 'overall',
  }) => firestore
      .collection(FirestoreCollections.leaderboards)
      .doc(subjectId)
      .collection('entries')
      .orderBy('averagePercentage', descending: true)
      .orderBy('totalExams', descending: true)
      .orderBy('userId')
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(NaysLeaderboardEntry.fromDocument)
            .toList(growable: false),
      );

  Future<NaysAppSettings> fetchAppSettings() async {
    return const NaysAppSettings();
  }

  Future<void> saveAppSettings(NaysAppSettings settings) => Future.error(
    UnsupportedError('App settings are managed outside the app.'),
  );

  Future<void> createUserProfile(String uid, NaysUserProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'nays_local_user_profile_$uid',
      jsonEncode({
        'fullName': profile.fullName,
        'email': profile.email,
        'phone': profile.phone,
        'profileImage': profile.profileImage,
        'role': profile.role,
        'institution': profile.institution,
        'department': profile.department,
        'level': profile.level,
        'state': profile.state,
        'district': profile.district,
        'createdAt': profile.createdAt?.toIso8601String(),
        'updatedAt': profile.updatedAt?.toIso8601String(),
      }),
    );
  }

  Future<NaysUserProfile?> fetchUserProfile(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString('nays_local_user_profile_$uid');
    if (stored == null) return null;
    final data = jsonDecode(stored) as Map<String, dynamic>;
    return NaysUserProfile(
      uid: uid,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      profileImage: data['profileImage'] as String? ?? '',
      role: data['role'] as String? ?? 'student',
      institution: data['institution'] as String? ?? '',
      department: data['department'] as String? ?? '',
      level: data['level'] as String? ?? '',
      state: data['state'] as String? ?? '',
      district: data['district'] as String? ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt'] as String? ?? ''),
    );
  }

  Future<List<NaysAnnouncement>> fetchAnnouncements() async => const [];

  NaysSubject _subjectFromLocal(Map<String, Object?> data) =>
      NaysSubject.fromData(data['id']! as String, {
        'subjectCode': data['subject_code'] as String? ?? '',
        'subjectName': data['name'] as String? ?? '',
        'description': data['description'] as String? ?? '',
        'category': data['category'] as String? ?? '',
        'educationLevel': data['education_level'] as String? ?? '',
        'isActive': data['is_active'] == 1,
        'totalQuestions': 0,
      });
}

class CbtSubmissionQueuedException implements Exception {
  const CbtSubmissionQueuedException();

  @override
  String toString() =>
      'Submission saved on this device and will sync when online.';
}

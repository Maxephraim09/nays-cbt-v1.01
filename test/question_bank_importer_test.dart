import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nays_mobile/core/database/nays_cbt_database.dart';
import 'package:nays_mobile/data/services/question_bank_importer.dart';
import 'package:nays_mobile/data/services/question_bank_seeder.dart';
import 'package:nays_mobile/services/firestore_service.dart';
import 'package:nays_mobile/services/offline_exam_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _expandedQuestionSubjectIds = [
  'accounting',
  'commerce',
  'christian_religious_studies',
  'islamic_religious_studies',
  'history',
  'hausa',
  'yoruba',
  'arabic',
  'french',
  'fine_arts',
  'music',
  'computer_studies',
  'home_economics',
  'agricultural_economics',
  'technical_drawing',
  'civic_education',
  'physical_and_health_education',
  'insurance',
  'office_practice',
  'marketing',
  'food_and_nutrition',
  'animal_husbandry',
  'igbo',
];

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  late Directory directory;
  late NaysCbtDatabase database;
  late QuestionBankImporter importer;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nays-bank-');
    database = NaysCbtDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/local.db',
    );
    importer = QuestionBankImporter(database);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<QuestionBankImportResult> importBank() => importer.import(
    manifestJson: _manifest,
    subjectsJson: _subjects,
    questionFiles: {'questions/math.json': _questionFiles},
  );

  test(
    'creates the schema and preserves encrypted exam recovery table',
    () async {
      final tables = await (await database.database).rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name']).toSet();

      expect(
        names,
        containsAll({
          'subjects',
          'questions',
          'question_options',
          'exam_preferences',
          'registered_subjects',
          'exam_attempts',
          'exam_answers',
          'exam_results',
          'practice_sessions',
          'practice_answers',
          'question_bank_metadata',
          'sync_queue',
          'offline_exam_attempts',
        }),
      );
    },
  );

  test(
    'imports a validated package, registers once, and filters questions',
    () async {
      final result = await importBank();
      expect(result.version, '1.0.0');
      expect(result.subjectCount, 1);
      expect(result.questionCount, 2);
      expect(result.checksum, hasLength(64));

      await database.registerSubject(userId: 'uid-1', subjectId: 'math');
      await database.registerSubject(userId: 'uid-1', subjectId: 'math');
      expect(await database.getRegisteredSubjects('uid-1'), hasLength(1));
      final queuedRegistration = await database.getPendingSyncItems('uid-1');
      expect(queuedRegistration, hasLength(1));
      expect(queuedRegistration.single['record_type'], 'registered_subject');
      expect(
        await database.getEligibleQuestionCount(
          subjectId: 'math',
          difficulty: 'Easy',
        ),
        1,
      );

      final selected = await database.getExamQuestions(
        subjectId: 'math',
        difficulty: 'Easy',
        limit: 1,
        random: Random(1),
      );
      expect(selected.single['id'], 'math-001');
      expect(selected.single['options'], hasLength(4));
      expect(
        await (await database.database).query('question_bank_metadata'),
        hasLength(1),
      );
    },
  );

  test('imports the packaged JSON assets idempotently', () async {
    final first = await QuestionBankSeeder(database).seedBundledBank();
    final second = await QuestionBankSeeder(database).seedBundledBank();

    expect(first.version, '2.1.0');
    expect(first.subjectCount, 34);
    expect(first.questionCount, 3300);
    expect(second.checksum, first.checksum);
    expect(await database.getSubjects(), hasLength(34));
    final db = await database.database;
    for (final subjectId in [
      'english_language',
      'mathematics',
      'biology',
      'chemistry',
      'physics',
      'agricultural_science',
      'economics',
      'government',
      'literature_in_english',
      'geography',
      'accounting',
      'commerce',
      'christian_religious_studies',
      'islamic_religious_studies',
      'history',
      'hausa',
      'yoruba',
      'arabic',
      'french',
      'fine_arts',
      'music',
      'computer_studies',
      'home_economics',
      'agricultural_economics',
      'technical_drawing',
      'civic_education',
      'physical_and_health_education',
      'insurance',
      'office_practice',
      'marketing',
      'food_and_nutrition',
      'animal_husbandry',
      'igbo',
    ]) {
      expect(
        await db.query(
          'questions',
          columns: ['id'],
          where: 'subject_id = ?',
          whereArgs: [subjectId],
        ),
        hasLength(100),
        reason: '$subjectId should be seeded with exactly 100 questions',
      );
    }
    final yungur = await db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: ['yungur'],
    );
    expect(yungur, hasLength(1));
    expect(yungur.single['is_active'], 1);
    expect(yungur.single['total_questions'], 0);
    expect(
      await db.query(
        'questions',
        where: 'subject_id = ?',
        whereArgs: ['yungur'],
      ),
      isEmpty,
    );
    expect(
      await database.getEligibleQuestionCount(
        subjectId: 'economics',
        difficulty: 'Mixed',
      ),
      100,
    );
    for (final subjectId in _expandedQuestionSubjectIds) {
      final difficultyCounts = await db.rawQuery(
        'SELECT difficulty, COUNT(*) AS count FROM questions '
        'WHERE subject_id = ? GROUP BY difficulty',
        [subjectId],
      );
      expect(
        {for (final row in difficultyCounts) row['difficulty']: row['count']},
        {'easy': 30, 'medium': 50, 'hard': 20},
        reason: '$subjectId should use the declared difficulty distribution',
      );
      final topicCount =
          (await db.rawQuery(
                'SELECT COUNT(DISTINCT topic) FROM questions WHERE subject_id = ?',
                [subjectId],
              ))
              .single
              .values
              .single as int;
      expect(
        topicCount,
        greaterThanOrEqualTo(5),
        reason: '$subjectId should cover at least five distinct topic areas',
      );
      final unreviewedLabels = await db.query(
        'questions',
        columns: ['verification_status'],
        where: 'subject_id = ? AND verification_status != ?',
        whereArgs: [subjectId, 'editorial_review_required'],
      );
      expect(
        unreviewedLabels,
        isEmpty,
        reason: '$subjectId questions must be marked for editorial review',
      );
    }
    expect(
      (await (await database.database).query(
        'question_bank_metadata',
      )).single['status'],
      'ready',
    );
  });

  test('accepts the documented object-form option schema', () async {
    final rows = (jsonDecode(_questionFiles) as List)
        .cast<Map<String, dynamic>>()
        .map((question) {
          final options = (question['options'] as List)
              .cast<Map<String, dynamic>>();
          return {
            ...question,
            'options': {
              for (final option in options) option['id']: option['text'],
            },
          };
        })
        .toList();

    await importer.import(
      manifestJson: _manifest,
      subjectsJson: _subjects,
      questionFiles: {'questions/math.json': jsonEncode(rows)},
    );

    final selected = await database.getExamQuestions(
      subjectId: 'math',
      difficulty: 'Easy',
      limit: 1,
      shuffleQuestions: false,
    );
    final options = (selected.single['options']! as List)
        .cast<Map<String, Object?>>();
    expect(options.map((option) => option['option_key']).toSet(), {
      'A',
      'B',
      'C',
      'D',
    });
  });

  test('does not re-import an unchanged verified package', () async {
    await importBank();
    final before = (await (await database.database).query(
      'question_bank_metadata',
      where: 'id = 1',
    )).single;

    await importBank();
    final after = (await (await database.database).query(
      'question_bank_metadata',
      where: 'id = 1',
    )).single;

    expect(after['imported_at'], before['imported_at']);
    final questionCount = await (await database.database).rawQuery(
      'SELECT COUNT(*) AS count FROM questions',
    );
    expect(questionCount.single['count'], 2);
    expect(
      await database.getEligibleQuestionCount(
        subjectId: 'math',
        difficulty: 'Mixed',
      ),
      2,
    );
  });

  test(
    'persists sync operations and schedules bounded retry availability',
    () async {
      await database.enqueueSync(
        userId: 'uid-1',
        recordType: 'cbt_preferences',
        recordId: 'preferences',
        operation: 'upsert',
        payload: {'difficulty': 'Mixed'},
      );
      var pending = await database.getPendingSyncItems('uid-1');
      expect(pending, hasLength(1));
      final id = pending.single['id']! as int;
      expect(pending.single['idempotency_key'], contains('cbt_preferences'));

      await database.markSyncQueueFailed(
        id,
        nextAttemptAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        error: 'temporary network error',
      );
      expect(await database.getPendingSyncItems('uid-1'), isEmpty);

      await database.markSyncQueueFailed(
        id,
        nextAttemptAt: null,
        error: 'retry limit reached',
      );
      expect(await database.getPendingSyncItems('uid-1'), isEmpty);
      await database.retryFailedSyncItems('uid-1');
      pending = await database.getPendingSyncItems('uid-1');
      expect(pending, hasLength(1));
      expect(pending.single['retry_count'], 0);
      expect(pending.single['last_error'], isNull);
    },
  );

  test(
    'retires legacy profile sync items without requiring Firestore',
    () async {
      await database.enqueueSync(
        userId: 'uid-1',
        recordType: 'profile',
        recordId: 'uid-1',
        operation: 'upsert',
        payload: {
          'fullName': 'Local account',
          'clientUpdatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      final service = FirestoreCbtService(
        auth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'uid-1'),
          signedIn: true,
        ),
        database: database,
        offlineStore: CbtOfflineExamStore(
          database: database,
          enableOfflineStorage: false,
        ),
      );

      await expectLater(service.syncPendingChanges(), completion(1));
      expect(await database.getPendingSyncItems('uid-1'), isEmpty);
    },
  );

  test('rejects invalid answer data without partially importing', () async {
    final invalid = _questionFiles.replaceAll(
      '"correct_answer": "A"',
      '"correct_answer": "Z"',
    );

    await expectLater(
      importer.import(
        manifestJson: _manifest,
        subjectsJson: _subjects,
        questionFiles: {'questions/math.json': invalid},
      ),
      throwsA(isA<QuestionBankImportException>()),
    );
    expect(await database.getSubjects(), isEmpty);
    expect(
      await (await database.database).query('question_bank_metadata'),
      isEmpty,
    );
  });

  test('rejects duplicate question text even when IDs differ', () async {
    final questions = (jsonDecode(_questionFiles) as List)
        .cast<Map<String, dynamic>>();
    final duplicate = Map<String, dynamic>.from(questions.first)
      ..['id'] = 'math-003'
      ..['question'] = '  2 + 2 = ?  ';

    await expectLater(
      importer.import(
        manifestJson: _manifest,
        subjectsJson: _subjects,
        questionFiles: {
          'questions/math.json': jsonEncode([...questions, duplicate]),
        },
      ),
      throwsA(
        isA<QuestionBankImportException>().having(
          (error) => error.issues.join('\n'),
          'issues',
          contains('duplicates normalized question text'),
        ),
      ),
    );
    expect(await database.getSubjects(), isEmpty);
  });

  test('updates stable question IDs without deleting registrations', () async {
    await importBank();
    await database.registerSubject(userId: 'uid-1', subjectId: 'math');
    final updated = _questionFiles.replaceAll(
      '"question": "2 + 2 = ?"',
      '"question": "What is 2 plus 2?"',
    );

    await importer.import(
      manifestJson: _manifest,
      subjectsJson: _subjects,
      questionFiles: {'questions/math.json': updated},
    );

    expect(await database.getRegisteredSubjects('uid-1'), hasLength(1));
    final questions = await database.getExamQuestions(
      subjectId: 'math',
      difficulty: 'Easy',
      limit: 1,
      shuffleQuestions: false,
    );
    expect(questions.single['question_text'], 'What is 2 plus 2?');
  });

  test('stores user preferences locally', () async {
    await database.saveExamPreferences(
      userId: 'uid-1',
      durationMinutes: 45,
      difficulty: 'Medium',
      questionsPerExam: 10,
      shuffleQuestions: false,
      shuffleOptions: true,
    );

    final preferences = await database.getExamPreferences('uid-1');
    expect(preferences?['duration_minutes'], 45);
    expect(preferences?['difficulty'], 'Medium');
    expect(preferences?['shuffle_questions'], 0);
    expect(preferences?['shuffle_options'], 1);
  });

  test(
    'saves answers immediately and submits an idempotent local result',
    () async {
      await importBank();
      await database.registerSubject(userId: 'uid-1', subjectId: 'math');
      final snapshot = await database.getExamQuestions(
        subjectId: 'math',
        difficulty: 'Mixed',
        limit: 2,
        shuffleQuestions: false,
      );
      await database.startExamAttempt(
        attemptId: 'attempt-1',
        userId: 'uid-1',
        subjectId: 'math',
        questionSnapshot: snapshot,
      );
      await database.saveExamAnswer(
        attemptId: 'attempt-1',
        questionId: 'math-001',
        selectedAnswer: 'A',
      );
      await database.saveExamAnswer(
        attemptId: 'attempt-1',
        questionId: 'math-002',
        selectedAnswer: 'B',
      );

      final submitted = await database.submitExamAttempt(
        attemptId: 'attempt-1',
        durationSeconds: 30,
      );
      final retry = await database.submitExamAttempt(
        attemptId: 'attempt-1',
        durationSeconds: 40,
      );
      expect(submitted['correct_answers'], 1);
      expect(submitted['wrong_answers'], 1);
      expect(submitted['unanswered'], 0);
      expect(submitted['percentage'], 50);
      expect(retry['time_used'], 30);
      expect(
        await (await database.database).query('exam_results'),
        hasLength(1),
      );
      final queuedChanges = await (await database.database).query('sync_queue');
      expect(queuedChanges, hasLength(2));
      expect(queuedChanges.map((item) => item['record_type']).toSet(), {
        'registered_subject',
        'exam_result',
      });
    },
  );

  test('starts, recovers, and submits an offline exam from SQLite', () async {
    final questions = List.generate(
      5,
      (index) => {
        'id': 'math-${(index + 1).toString().padLeft(3, '0')}',
        'subject_id': 'math',
        'topic': 'Arithmetic',
        'difficulty': 'easy',
        'question_type': 'multiple_choice',
        'question': 'What is ${index + 2} + 2?',
        'options': [
          {'id': 'A', 'text': '4'},
          {'id': 'B', 'text': '5'},
          {'id': 'C', 'text': '6'},
          {'id': 'D', 'text': '7'},
        ],
        'correct_answer': 'A',
        'explanation': 'Adding two and two gives four.',
        'marks': 1,
        'source': 'Original practice question',
        'verification_status': 'verified',
      },
    );
    await importer.import(
      manifestJson: '''
        {"version":"1.0.0","total_questions":5,"question_files":["questions/math.json"]}
      ''',
      subjectsJson: _subjects,
      questionFiles: {'questions/math.json': jsonEncode(questions)},
    );
    await database.registerSubject(userId: 'uid-1', subjectId: 'math');
    await database.saveExamPreferences(
      userId: 'uid-1',
      durationMinutes: 45,
      difficulty: 'Easy',
      questionsPerExam: 5,
      shuffleQuestions: false,
      shuffleOptions: false,
    );
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'uid-1'),
      signedIn: true,
    );
    final service = FirestoreCbtService(
      auth: auth,
      database: database,
      offlineStore: CbtOfflineExamStore(
        database: database,
        enableOfflineStorage: false,
      ),
    );

    final session = await service.startOfflineExam(subjectId: 'math');
    expect(session.isOffline, isTrue);
    expect(session.questions, hasLength(5));
    expect(session.questions.first.explanation, isNotEmpty);
    final practice = await service.loadPracticeSession(subjectId: 'math');
    expect(practice.questions, hasLength(5));
    expect(practice.questions.first.correctAnswer, 'A');
    expect(practice.questions.first.explanation, isNotEmpty);
    await service.saveLocalExamProgress(
      session: session,
      answers: {session.questions.first.questionId: 'A'},
      currentQuestionIndex: 2,
    );

    final recovered = await service.loadActiveExam();
    expect(recovered?.session.sessionId, session.sessionId);
    expect(recovered?.currentQuestionIndex, 2);
    expect(recovered?.answers[session.questions.first.questionId], 'A');

    final result = await service.submitLocalExam(
      session: session,
      durationSeconds: 30,
    );
    expect(result['correctAnswers'], 1);
    expect(result['unanswered'], 4);
    expect(result['status'], 'completed_offline');
  });

  test(
    'persists practice answers, scores, and review snapshots locally',
    () async {
      await importBank();
      final snapshot = await database.getExamQuestions(
        subjectId: 'math',
        difficulty: 'Mixed',
        limit: 2,
        shuffleQuestions: false,
      );
      await database.startPracticeSession(
        sessionId: 'practice-1',
        userId: 'local-device',
        subjectId: 'math',
        difficulty: 'Mixed',
        questionSnapshot: snapshot,
      );
      await database.savePracticeAnswer(
        sessionId: 'practice-1',
        questionId: 'math-001',
        selectedAnswer: 'A',
      );
      await database.savePracticeAnswer(
        sessionId: 'practice-1',
        questionId: 'math-002',
        selectedAnswer: 'B',
      );

      final result = await database.completePracticeSession(
        sessionId: 'practice-1',
        timeSpentSeconds: 42,
      );
      expect(result['correct_answers'], 1);
      expect(result['wrong_answers'], 1);
      expect(result['percentage'], 50);
      expect(await database.getPracticeHistory('local-device'), hasLength(1));
      final review = await database.getPracticeReview('practice-1');
      expect(review, hasLength(2));
      expect(review.first['explanation'], isNotEmpty);
      expect(
        (review.first['practice_answer'] as Map)['selected_answer'],
        isNotNull,
      );
    },
  );
}

const _manifest = '''
{
  "version": "1.0.0",
  "total_questions": 2,
  "question_files": ["questions/math.json"]
}
''';

const _subjects = '''
[
  {
    "id": "math",
    "name": "Mathematics",
    "description": "Mathematics practice",
    "is_active": true
  }
]
''';

const _questionFiles = '''
[
  {
    "id": "math-001",
    "subject_id": "math",
    "topic": "Arithmetic",
    "subtopic": "Addition",
    "difficulty": "easy",
    "question_type": "multiple_choice",
    "question": "2 + 2 = ?",
    "options": [
      {"id": "A", "text": "4"},
      {"id": "B", "text": "5"},
      {"id": "C", "text": "6"},
      {"id": "D", "text": "7"}
    ],
    "correct_answer": "A",
    "explanation": "Adding two and two gives four.",
    "marks": 1,
    "source": "Original practice question",
    "verification_status": "verified"
  },
  {
    "id": "math-002",
    "subject_id": "math",
    "topic": "Arithmetic",
    "difficulty": "medium",
    "question_type": "multiple_choice",
    "question": "3 + 3 = ?",
    "options": [
      {"id": "A", "text": "6"},
      {"id": "B", "text": "7"},
      {"id": "C", "text": "8"},
      {"id": "D", "text": "9"}
    ],
    "correct_answer": "A",
    "explanation": "Adding three and three gives six.",
    "marks": 1,
    "source": "Original practice question",
    "verification_status": "verified"
  }
]
''';

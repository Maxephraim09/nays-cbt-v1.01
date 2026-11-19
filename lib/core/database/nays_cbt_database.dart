import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class NaysCbtDatabase {
  NaysCbtDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory,
      _databasePath = databasePath;

  static final NaysCbtDatabase instance = NaysCbtDatabase();
  static const databaseName = 'nays_cbt_offline.db';
  static const schemaVersion = 11;

  DatabaseFactory? _factory;
  String? _databasePath;
  Database? _database;

  Future<void> initializeForCurrentPlatform() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    if (_database != null) {
      throw StateError('The database is already open.');
    }

    sqfliteFfiInit();
    final supportDirectory = await getApplicationSupportDirectory();
    _factory = databaseFactoryFfi;
    _databasePath = '${supportDirectory.path}/$databaseName';
  }

  Future<Database> get database async {
    final opened = _database;
    if (opened != null) return opened;
    final path = _databasePath ?? '${await getDatabasesPath()}/$databaseName';
    return _database = await (_factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createSchema(db);
          await db.execute(
            'CREATE INDEX IF NOT EXISTS sync_queue_due '
            'ON sync_queue(user_id, sync_status, next_attempt_at)',
          );
        },
        onUpgrade: _upgradeSchema,
      ),
    );
  }

  Future<List<Map<String, Object?>>> getReminderList() async {
    final db = await database;
    final rows = await db.query(
      'reminders',
      orderBy: 'time_text ASC, created_at DESC',
    );
    return rows;
  }

  Future<Map<String, Object?>?> getReminder(String reminderId) async {
    final db = await database;
    final rows = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [reminderId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertReminder(Map<String, Object?> reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      reminder,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateReminderEnabled(String reminderId, bool enabled) async {
    final db = await database;
    await db.update(
      'reminders',
      {'enabled': enabled ? 1 : 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  Future<void> clearReminderAlarm(String reminderId) async {
    final db = await database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [reminderId]);
  }

  Future<void> updateExamProgress({
    required String attemptId,
    required int currentQuestionIndex,
  }) async {
    if (currentQuestionIndex < 0) {
      throw ArgumentError.value(
        currentQuestionIndex,
        'currentQuestionIndex',
        'Must not be negative.',
      );
    }
    final changed = await (await database).update(
      'exam_attempts',
      {'current_question_index': currentQuestionIndex},
      where: "id = ? AND status = 'in_progress'",
      whereArgs: [attemptId],
    );
    if (changed != 1) {
      throw StateError('The examination attempt is not active.');
    }
  }

  Future<Map<String, Object?>?> getActiveExamAttempt(String userId) async {
    final db = await database;
    final attempts = await db.query(
      'exam_attempts',
      where: "user_id = ? AND status = 'in_progress'",
      whereArgs: [userId],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (attempts.isEmpty) return null;
    final attempt = attempts.single;
    final answers = await db.query(
      'exam_answers',
      where: 'attempt_id = ?',
      whereArgs: [attempt['id']],
    );
    return {
      ...attempt,
      'answers': {
        for (final answer in answers)
          if (answer['selected_answer'] != null)
            answer['question_id']: answer['selected_answer'],
      },
    };
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _createSchema(db);
    await _ensureColumn(
      db,
      'exam_results',
      'total_marks',
      'ALTER TABLE exam_results ADD COLUMN total_marks REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'exam_results',
      'score',
      'ALTER TABLE exam_results ADD COLUMN score REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'subjects',
      'subject_code',
      "ALTER TABLE subjects ADD COLUMN subject_code TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'subjects',
      'category',
      "ALTER TABLE subjects ADD COLUMN category TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'subjects',
      'education_level',
      "ALTER TABLE subjects ADD COLUMN education_level TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'subjects',
      'total_questions',
      'ALTER TABLE subjects ADD COLUMN total_questions INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'registered_subjects',
      'sync_status',
      "ALTER TABLE registered_subjects ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'",
    );
    await _ensureColumn(
      db,
      'exam_attempts',
      'current_question_index',
      'ALTER TABLE exam_attempts ADD COLUMN current_question_index INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'exam_results',
      'topic_performance',
      "ALTER TABLE exam_results ADD COLUMN topic_performance TEXT NOT NULL DEFAULT '{}'",
    );
    await _ensureColumn(
      db,
      'sync_queue',
      'next_attempt_at',
      'ALTER TABLE sync_queue ADD COLUMN next_attempt_at TEXT',
    );
    await _ensureColumn(
      db,
      'sync_queue',
      'last_error',
      'ALTER TABLE sync_queue ADD COLUMN last_error TEXT',
    );
    await _ensureColumn(
      db,
      'sync_queue',
      'idempotency_key',
      'ALTER TABLE sync_queue ADD COLUMN idempotency_key TEXT',
    );
    await db.execute(
      "UPDATE sync_queue SET next_attempt_at = created_at "
      "WHERE sync_status = 'failed' AND next_attempt_at IS NULL",
    );
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        time_text TEXT NOT NULL,
        repeat_type TEXT NOT NULL DEFAULT 'once',
        ringtone TEXT NOT NULL DEFAULT 'default',
        enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
        next_occurrence TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sync_queue_due '
      'ON sync_queue(user_id, sync_status, next_attempt_at)',
    );
    await db.execute(
      "UPDATE reminders SET ringtone = 'default' "
      "WHERE ringtone IN ('default_alarm', 'defualt', '')",
    );
  }

  static Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String alterStatement,
  ) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    if (!result.any((entry) => entry['name'] == column)) {
      await db.execute(alterStatement);
    }
  }

  Future<void> registerSubject({
    required String userId,
    required String subjectId,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
    }
    final db = await database;
    await db.transaction((txn) async {
      final subjects = await txn.query(
        'subjects',
        columns: ['id'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [subjectId],
        limit: 1,
      );
      if (subjects.isEmpty) {
        throw StateError('The selected subject is not available.');
      }
      await txn.insert('registered_subjects', {
        'user_id': userId,
        'subject_id': subjectId,
        'sync_status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await _enqueueSyncOn(
        txn,
        userId: userId,
        recordType: 'registered_subject',
        recordId: subjectId,
        operation: 'upsert',
        payload: {'subjectId': subjectId},
      );
    });
  }

  Future<void> cacheRegisteredSubjects({
    required String userId,
    required Set<String> subjectIds,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final pendingDeletes = await txn.query(
        'sync_queue',
        columns: ['record_id'],
        where:
            "user_id = ? AND record_type = 'registered_subject' "
            "AND operation = 'delete' AND sync_status != 'synced'",
        whereArgs: [userId],
      );
      final suppressedIds = pendingDeletes
          .map((row) => row['record_id']! as String)
          .toSet();
      final ids = subjectIds.difference(suppressedIds).toList();
      if (ids.isEmpty) {
        await txn.delete(
          'registered_subjects',
          where: "user_id = ? AND sync_status = 'synced'",
          whereArgs: [userId],
        );
      } else {
        final placeholders = List.filled(ids.length, '?').join(', ');
        await txn.delete(
          'registered_subjects',
          where:
              "user_id = ? AND sync_status = 'synced' AND subject_id NOT IN ($placeholders)",
          whereArgs: [userId, ...ids],
        );
        final now = DateTime.now().toUtc().toIso8601String();
        for (final subjectId in ids) {
          await txn.insert('registered_subjects', {
            'user_id': userId,
            'subject_id': subjectId,
            'sync_status': 'synced',
            'created_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  Future<void> markRegistrationSynced({
    required String userId,
    required String subjectId,
  }) async {
    await (await database).update(
      'registered_subjects',
      {'sync_status': 'synced'},
      where: 'user_id = ? AND subject_id = ?',
      whereArgs: [userId, subjectId],
    );
  }

  Future<void> cacheSubjects(List<Map<String, Object?>> subjects) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final subject in subjects) {
        final id = subject['id'];
        if (id is! String || id.isEmpty) continue;
        final values = {
          'name': subject['name'] as String? ?? '',
          'subject_code': subject['subject_code'] as String? ?? '',
          'category': subject['category'] as String? ?? '',
          'education_level': subject['education_level'] as String? ?? '',
          'description': subject['description'] as String? ?? '',
          'icon': subject['icon'] as String? ?? '',
          'is_active':
              subject['is_active'] == false || subject['is_active'] == 0
              ? 0
              : 1,
          'created_at':
              subject['created_at'] as String? ??
              DateTime.now().toUtc().toIso8601String(),
        };
        final existing = await txn.query(
          'subjects',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert('subjects', {'id': id, ...values});
        } else {
          await txn.update(
            'subjects',
            values,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    });
  }

  Future<void> unregisterSubject({
    required String userId,
    required String subjectId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'registered_subjects',
        where: 'user_id = ? AND subject_id = ?',
        whereArgs: [userId, subjectId],
      );
      await _enqueueSyncOn(
        txn,
        userId: userId,
        recordType: 'registered_subject',
        recordId: subjectId,
        operation: 'delete',
        payload: {'subjectId': subjectId},
      );
    });
  }

  Future<List<Map<String, Object?>>> getSubjects({
    bool activeOnly = true,
  }) async {
    final db = await database;
    return db.query(
      'subjects',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name COLLATE NOCASE',
    );
  }

  Future<List<Map<String, Object?>>> getRegisteredSubjects(
    String userId,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT s.*, r.created_at AS registered_at
      FROM registered_subjects r
      JOIN subjects s ON s.id = r.subject_id
      WHERE r.user_id = ? AND s.is_active = 1
      ORDER BY s.name COLLATE NOCASE
      ''',
      [userId],
    );
  }

  Future<void> saveExamPreferences({
    required String userId,
    required int durationMinutes,
    required String difficulty,
    required int questionsPerExam,
    required bool shuffleQuestions,
    required bool shuffleOptions,
    bool showExplanations = true,
    bool negativeMarking = false,
    bool queueForSync = true,
    DateTime? updatedAt,
  }) async {
    const difficulties = {'Easy', 'Medium', 'Hard', 'Mixed'};
    if (userId.trim().isEmpty ||
        durationMinutes < 15 ||
        durationMinutes > 120 ||
        questionsPerExam < 1 ||
        !difficulties.contains(difficulty)) {
      throw ArgumentError('The selected examination preferences are invalid.');
    }
    final db = await database;
    final updatedAtValue = (updatedAt ?? DateTime.now())
        .toUtc()
        .toIso8601String();
    final payload = <String, Object?>{
      'durationMinutes': durationMinutes,
      'difficulty': difficulty,
      'questionsPerExam': questionsPerExam,
      'shuffleQuestions': shuffleQuestions,
      'shuffleAnswers': shuffleOptions,
      'showExplanations': showExplanations,
      'negativeMarking': negativeMarking,
      'updatedAt': updatedAtValue,
    };
    await db.transaction((txn) async {
      await txn.insert('exam_preferences', {
        'user_id': userId,
        'duration_minutes': durationMinutes,
        'difficulty': difficulty,
        'questions_per_exam': questionsPerExam,
        'shuffle_questions': shuffleQuestions ? 1 : 0,
        'shuffle_options': shuffleOptions ? 1 : 0,
        'show_explanations': showExplanations ? 1 : 0,
        'negative_marking': negativeMarking ? 1 : 0,
        'updated_at': updatedAtValue,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (queueForSync) {
        await _enqueueSyncOn(
          txn,
          userId: userId,
          recordType: 'cbt_preferences',
          recordId: 'preferences',
          operation: 'upsert',
          payload: payload,
        );
      }
    });
  }

  Future<Map<String, Object?>?> getExamPreferences(String userId) async {
    final rows = await (await database).query(
      'exam_preferences',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> enqueueSync({
    required String userId,
    required String recordType,
    required String recordId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    await _enqueueSyncOn(
      await database,
      userId: userId,
      recordType: recordType,
      recordId: recordId,
      operation: operation,
      payload: payload,
    );
  }

  Future<List<Map<String, Object?>>> getPendingSyncItems(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return (await database).query(
      'sync_queue',
      where:
          "user_id = ? AND ((sync_status = 'pending' AND "
          '(next_attempt_at IS NULL OR next_attempt_at <= ?)) OR '
          "(sync_status = 'failed' AND next_attempt_at IS NOT NULL "
          'AND next_attempt_at <= ?))',
      whereArgs: [userId, now, now],
      orderBy: 'created_at',
    );
  }

  Future<void> markSyncQueueCompleted(int id) async {
    await (await database).update(
      'sync_queue',
      {'sync_status': 'synced', 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSyncQueueRecordCompleted({
    required String userId,
    required String recordType,
    required String recordId,
  }) async {
    await (await database).update(
      'sync_queue',
      {'sync_status': 'synced', 'next_attempt_at': null, 'last_error': null},
      where:
          'user_id = ? AND record_type = ? AND record_id = ? '
          "AND sync_status != 'synced'",
      whereArgs: [userId, recordType, recordId],
    );
  }

  Future<void> markSyncQueueFailed(
    int id, {
    required DateTime? nextAttemptAt,
    required String error,
  }) async {
    await (await database).rawUpdate(
      '''
      UPDATE sync_queue
      SET sync_status = 'failed',
          retry_count = retry_count + 1,
          next_attempt_at = ?,
          last_error = ?
      WHERE id = ?
      ''',
      [nextAttemptAt?.toUtc().toIso8601String(), error, id],
    );
  }

  Future<void> retryFailedSyncItems(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (await database).update(
      'sync_queue',
      {
        'sync_status': 'pending',
        'retry_count': 0,
        'next_attempt_at': now,
        'last_error': null,
      },
      where:
          "user_id = ? AND sync_status = 'failed' AND next_attempt_at IS NULL",
      whereArgs: [userId],
    );
  }

  Future<void> _enqueueSyncOn(
    DatabaseExecutor executor, {
    required String userId,
    required String recordType,
    required String recordId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await executor.insert('sync_queue', {
      'user_id': userId,
      'record_type': recordType,
      'record_id': recordId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'sync_status': 'pending',
      'retry_count': 0,
      'created_at': now,
      'next_attempt_at': now,
      'last_error': null,
      'idempotency_key': '$userId:$recordType:$recordId:$operation',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getExamResults(String userId) async =>
      (await database).rawQuery(
        '''
        SELECT r.*, a.started_at, s.name AS subject_name
        FROM exam_results r
        JOIN exam_attempts a ON a.id = r.attempt_id
        JOIN subjects s ON s.id = r.subject_id
        WHERE r.user_id = ?
        ORDER BY r.created_at DESC
        ''',
        [userId],
      );

  Future<void> startPracticeSession({
    required String sessionId,
    required String userId,
    required String subjectId,
    required String difficulty,
    required List<Map<String, Object?>> questionSnapshot,
  }) async {
    if (questionSnapshot.isEmpty) {
      throw ArgumentError.value(
        questionSnapshot,
        'questionSnapshot',
        'Must not be empty.',
      );
    }
    await (await database).insert('practice_sessions', {
      'id': sessionId,
      'user_id': userId,
      'subject_id': subjectId,
      'difficulty': difficulty.toLowerCase(),
      'total_questions': questionSnapshot.length,
      'time_spent': 0,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'in_progress',
      'question_snapshot': jsonEncode(questionSnapshot),
    });
  }

  Future<void> savePracticeAnswer({
    required String sessionId,
    required String questionId,
    required Object selectedAnswer,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final sessions = await txn.query(
        'practice_sessions',
        columns: ['question_snapshot', 'status'],
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessions.isEmpty || sessions.single['status'] != 'in_progress') {
        throw StateError('The practice session is not active.');
      }
      final snapshot =
          jsonDecode(sessions.single['question_snapshot']! as String) as List;
      final matches = snapshot.whereType<Map>().where(
        (question) => question['id'] == questionId,
      );
      if (matches.length != 1) {
        throw StateError('The question is not part of this practice session.');
      }
      final question = Map<String, dynamic>.from(matches.single);
      final correctAnswer = question['correct_answer'];
      final isCorrect = _answerIsCorrect(question, selectedAnswer);
      await txn.insert('practice_answers', {
        'session_id': sessionId,
        'question_id': questionId,
        'selected_answer': selectedAnswer is List
            ? jsonEncode(selectedAnswer)
            : selectedAnswer.toString(),
        'correct_answer': correctAnswer is List
            ? jsonEncode(correctAnswer)
            : correctAnswer.toString(),
        'is_correct': isCorrect ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Map<String, Object?>> completePracticeSession({
    required String sessionId,
    required int timeSpentSeconds,
  }) async {
    if (timeSpentSeconds < 0) {
      throw ArgumentError.value(
        timeSpentSeconds,
        'timeSpentSeconds',
        'Must not be negative.',
      );
    }
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'practice_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Practice session does not exist.');
      final session = rows.single;
      if (session['status'] == 'completed') return session;

      final answers = await txn.query(
        'practice_answers',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      final correctAnswers = answers.where(
        (answer) => answer['is_correct'] == 1,
      );
      final correctCount = correctAnswers.length;
      final wrongCount = answers.length - correctCount;
      final snapshot =
          jsonDecode(session['question_snapshot']! as String) as List;
      final marksById = {
        for (final row in snapshot.whereType<Map>())
          row['id'] as String: (row['marks'] as num).toDouble(),
      };
      final score = correctAnswers.fold<double>(
        0,
        (total, answer) => total + (marksById[answer['question_id']] ?? 0),
      );
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'practice_sessions',
        {
          'correct_answers': correctCount,
          'wrong_answers': wrongCount,
          'score': score,
          'percentage': snapshot.isEmpty
              ? 0
              : correctCount / snapshot.length * 100,
          'time_spent': timeSpentSeconds,
          'completed_at': now,
          'status': 'completed',
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      return (await txn.query(
        'practice_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      )).single;
    });
  }

  Future<List<Map<String, Object?>>> getPracticeHistory(String userId) async =>
      (await database).rawQuery(
        '''
        SELECT p.*, s.name AS subject_name
        FROM practice_sessions p
        JOIN subjects s ON s.id = p.subject_id
        WHERE p.user_id = ? AND p.status = 'completed'
        ORDER BY p.completed_at DESC
        ''',
        [userId],
      );

  Future<List<Map<String, Object?>>> getPracticeReview(String sessionId) async {
    final db = await database;
    final sessions = await db.query(
      'practice_sessions',
      columns: ['question_snapshot'],
      where: 'id = ? AND status = ?',
      whereArgs: [sessionId, 'completed'],
      limit: 1,
    );
    if (sessions.isEmpty) {
      throw StateError('Completed practice session not found.');
    }
    final snapshot =
        jsonDecode(sessions.single['question_snapshot']! as String) as List;
    final answers = await db.query(
      'practice_answers',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    final answersByQuestion = {
      for (final answer in answers) answer['question_id']: answer,
    };
    return [
      for (final rawQuestion in snapshot.whereType<Map>())
        {
          ...Map<String, Object?>.from(rawQuestion),
          'practice_answer': answersByQuestion[rawQuestion['id']],
        },
    ];
  }

  Future<int> getEligibleQuestionCount({
    required String subjectId,
    required String difficulty,
    String? topic,
  }) async {
    final db = await database;
    final where = <String>['subject_id = ?', 'is_active = 1'];
    final args = <Object?>[subjectId];
    if (difficulty.toLowerCase() != 'mixed') {
      where.add('LOWER(difficulty) = ?');
      args.add(difficulty.toLowerCase());
    }
    if (topic != null && topic.isNotEmpty) {
      where.add('topic = ?');
      args.add(topic);
    }
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM questions WHERE ${where.join(' AND ')}',
      args,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<List<String>> getQuestionTopics(String subjectId) async {
    final rows = await (await database).rawQuery(
      'SELECT DISTINCT topic FROM questions '
      'WHERE subject_id = ? AND is_active = 1 ORDER BY topic COLLATE NOCASE',
      [subjectId],
    );
    return rows
        .map((row) => row['topic'] as String)
        .where((topic) => topic.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> startExamAttempt({
    required String attemptId,
    required String userId,
    required String subjectId,
    required List<Map<String, Object?>> questionSnapshot,
    bool requireRegistration = true,
  }) async {
    if (attemptId.trim().isEmpty ||
        userId.trim().isEmpty ||
        questionSnapshot.isEmpty) {
      throw ArgumentError('An attempt requires an ID, user, and questions.');
    }
    final db = await database;
    await db.transaction((txn) async {
      if (requireRegistration) {
        final registration = await txn.query(
          'registered_subjects',
          columns: ['id'],
          where: 'user_id = ? AND subject_id = ?',
          whereArgs: [userId, subjectId],
          limit: 1,
        );
        if (registration.isEmpty) {
          throw StateError(
            'Register for this subject before starting an exam.',
          );
        }
      }
      await txn.insert('exam_attempts', {
        'id': attemptId,
        'user_id': userId,
        'subject_id': subjectId,
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'duration_seconds': 0,
        'current_question_index': 0,
        'total_questions': questionSnapshot.length,
        'status': 'in_progress',
        'question_snapshot': jsonEncode(questionSnapshot),
      });
    });
  }

  Future<void> saveExamAnswer({
    required String attemptId,
    required String questionId,
    required Object? selectedAnswer,
    int timeSpentSeconds = 0,
    bool markedForReview = false,
  }) async {
    if (timeSpentSeconds < 0) {
      throw ArgumentError.value(
        timeSpentSeconds,
        'timeSpentSeconds',
        'Must not be negative.',
      );
    }

    final db = await database;
    await db.transaction((txn) async {
      final attempts = await txn.query(
        'exam_attempts',
        columns: ['status', 'question_snapshot'],
        where: 'id = ?',
        whereArgs: [attemptId],
        limit: 1,
      );
      if (attempts.isEmpty || attempts.single['status'] != 'in_progress') {
        throw StateError('The examination attempt is not active.');
      }
      final questions =
          (jsonDecode(attempts.single['question_snapshot']! as String) as List)
              .map((question) => Map<String, dynamic>.from(question as Map));
      Map<String, dynamic>? question;
      for (final item in questions) {
        if (item['id'] == questionId || item['questionId'] == questionId) {
          question = item;
          break;
        }
      }
      if (question == null) {
        throw StateError('This question is not part of the examination.');
      }
      await _writeExamAnswer(
        txn,
        attemptId: attemptId,
        questionId: questionId,
        question: question,
        selectedAnswer: selectedAnswer,
        timeSpentSeconds: timeSpentSeconds,
        markedForReview: markedForReview,
      );
    });
  }

  Future<void> saveExamProgress({
    required String attemptId,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final attempts = await txn.query(
        'exam_attempts',
        columns: ['status', 'question_snapshot'],
        where: 'id = ?',
        whereArgs: [attemptId],
        limit: 1,
      );
      if (attempts.isEmpty || attempts.single['status'] != 'in_progress') {
        throw StateError('The examination attempt is not active.');
      }

      final questions =
          (jsonDecode(attempts.single['question_snapshot']! as String) as List)
              .map((question) => Map<String, dynamic>.from(question as Map))
              .toList(growable: false);
      if (currentQuestionIndex < 0 ||
          currentQuestionIndex >= questions.length) {
        throw RangeError.range(
          currentQuestionIndex,
          0,
          questions.length - 1,
          'currentQuestionIndex',
        );
      }

      for (final question in questions) {
        final questionId =
            (question['id'] ?? question['questionId']) as String?;
        if (questionId == null || questionId.isEmpty) {
          throw const FormatException(
            'The examination contains a question without an ID.',
          );
        }
        await _writeExamAnswer(
          txn,
          attemptId: attemptId,
          questionId: questionId,
          question: question,
          selectedAnswer: answers[questionId],
        );
      }

      final changed = await txn.update(
        'exam_attempts',
        {'current_question_index': currentQuestionIndex},
        where: "id = ? AND status = 'in_progress'",
        whereArgs: [attemptId],
      );
      if (changed != 1) {
        throw StateError('The examination attempt is not active.');
      }
    });
  }

  Future<void> _writeExamAnswer(
    DatabaseExecutor txn, {
    required String attemptId,
    required String questionId,
    required Map<String, dynamic> question,
    required Object? selectedAnswer,
    int timeSpentSeconds = 0,
    bool markedForReview = false,
  }) async {
    final normalizedAnswer = _normalizeExamAnswer(selectedAnswer);
    final correctAnswer =
        question['correct_answer'] ?? question['correctAnswer'];
    final correctAnswerJson = correctAnswer is String
        ? correctAnswer
        : jsonEncode(correctAnswer);
    final selectedAnswerJson = normalizedAnswer == null
        ? null
        : normalizedAnswer is String
        ? normalizedAnswer
        : jsonEncode(normalizedAnswer);
    await txn.insert('exam_answers', {
      'attempt_id': attemptId,
      'question_id': questionId,
      'selected_answer': selectedAnswerJson,
      'correct_answer': correctAnswerJson,
      'is_correct': normalizedAnswer == null
          ? null
          : _answerIsCorrect(question, normalizedAnswer)
          ? 1
          : 0,
      'time_spent_seconds': timeSpentSeconds,
      'marked_for_review': markedForReview ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Object? _normalizeExamAnswer(Object? answer) {
    if (answer is String && answer.trim().isEmpty) return null;
    if (answer is Iterable && answer.isEmpty) return null;
    if (answer is Map && answer.isEmpty) return null;
    return answer;
  }

  Future<Map<String, Object?>> submitExamAttempt({
    required String attemptId,
    required int durationSeconds,
  }) async {
    if (durationSeconds < 0) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'Must not be negative.',
      );
    }
    final db = await database;
    return db.transaction((txn) async {
      final attempts = await txn.query(
        'exam_attempts',
        where: 'id = ?',
        whereArgs: [attemptId],
        limit: 1,
      );
      if (attempts.isEmpty) throw StateError('Exam attempt was not found.');
      final attempt = attempts.single;
      final savedResult = await txn.query(
        'exam_results',
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
        limit: 1,
      );
      if (savedResult.isNotEmpty) return savedResult.single;
      if (attempt['status'] != 'in_progress') {
        throw StateError('The examination attempt cannot be submitted.');
      }

      final answers = await txn.query(
        'exam_answers',
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
      );
      final answered = answers
          .where((answer) => answer['selected_answer'] != null)
          .toList();
      final correct = answered.where((answer) => answer['is_correct'] == 1);
      final correctCount = correct.length;
      final wrongCount = answered.length - correctCount;
      final snapshot =
          (jsonDecode(attempt['question_snapshot']! as String) as List)
              .map((question) => Map<String, dynamic>.from(question as Map))
              .toList(growable: false);
      final totalMarks = snapshot.fold<double>(
        0,
        (sum, question) => sum + (question['marks'] as num? ?? 1).toDouble(),
      );
      final score = snapshot
          .where((question) {
            final questionId = question['id'];
            return answered.any(
              (answer) =>
                  answer['question_id'] == questionId &&
                  answer['is_correct'] == 1,
            );
          })
          .fold<double>(
            0,
            (sum, question) =>
                sum + (question['marks'] as num? ?? 1).toDouble(),
          );
      final unansweredCount = snapshot.length - answered.length;
      final topicStats = <String, Map<String, int>>{};
      for (final question in snapshot) {
        final topic = (question['topic'] as String? ?? '').trim();
        final key = topic.isEmpty ? 'Other' : topic;
        final stats = topicStats.putIfAbsent(
          key,
          () => {'total': 0, 'correct': 0},
        );
        stats['total'] = stats['total']! + 1;
        final questionAnswers = answers.where(
          (answer) => answer['question_id'] == question['id'],
        );
        if (questionAnswers.isNotEmpty &&
            questionAnswers.first['is_correct'] == 1) {
          stats['correct'] = stats['correct']! + 1;
        }
      }
      final topicPerformance = {
        for (final entry in topicStats.entries)
          entry.key: {
            'totalQuestions': entry.value['total'],
            'correctAnswers': entry.value['correct'],
            'percentage': entry.value['total'] == 0
                ? 0
                : entry.value['correct']! / entry.value['total']! * 100,
          },
      };
      final now = DateTime.now().toUtc();
      final startedAt = DateTime.parse(attempt['started_at']! as String);
      final result = <String, Object?>{
        'attempt_id': attemptId,
        'user_id': attempt['user_id'],
        'subject_id': attempt['subject_id'],
        'total_questions': snapshot.length,
        'correct_answers': correctCount,
        'wrong_answers': wrongCount,
        'unanswered': unansweredCount,
        'total_marks': totalMarks,
        'score': score,
        'percentage': totalMarks == 0 ? 0 : score / totalMarks * 100,
        'topic_performance': jsonEncode(topicPerformance),
        'time_used': durationSeconds,
        'created_at': now.toIso8601String(),
      };
      await txn.update(
        'exam_attempts',
        {
          'completed_at': now.toIso8601String(),
          'duration_seconds': durationSeconds,
          'correct_answers': correctCount,
          'wrong_answers': wrongCount,
          'unanswered': unansweredCount,
          'score': score,
          'status': 'completed',
        },
        where: 'id = ?',
        whereArgs: [attemptId],
      );
      await txn.insert('exam_results', result);
      await txn.insert('sync_queue', {
        'user_id': attempt['user_id'],
        'record_type': 'exam_result',
        'record_id': attemptId,
        'operation': 'upsert',
        'payload': jsonEncode({
          ...result,
          'started_at': startedAt.toIso8601String(),
        }),
        'sync_status': 'pending',
        'retry_count': 0,
        'created_at': now.toIso8601String(),
        'next_attempt_at': now.toIso8601String(),
        'idempotency_key':
            '${attempt['user_id']}:exam_result:$attemptId:upsert',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return result;
    });
  }

  bool _answerIsCorrect(Map<String, dynamic> question, Object? answer) {
    final expected = question['correct_answer'];
    if (question['question_type'] == 'multiple_select') {
      List<String> sortedValues(Object? value) {
        final items = value is List
            ? value
            : jsonDecode(value as String) as List;
        final values = items.map((item) => item.toString()).toList()..sort();
        return values;
      }

      final expectedValues = sortedValues(expected);
      final actualValues = sortedValues(answer);
      return jsonEncode(expectedValues) == jsonEncode(actualValues);
    }
    if (expected is String && answer is String) return expected == answer;
    return expected == answer;
  }

  Future<List<Map<String, Object?>>> getExamQuestions({
    required String subjectId,
    required String difficulty,
    required int limit,
    String? topic,
    bool shuffleQuestions = true,
    bool shuffleOptions = false,
    Random? random,
  }) async {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }
    final db = await database;
    final where = <String>['subject_id = ?', 'is_active = 1'];
    final args = <Object?>[subjectId];
    if (difficulty.toLowerCase() != 'mixed') {
      where.add('LOWER(difficulty) = ?');
      args.add(difficulty.toLowerCase());
    }
    if (topic != null && topic.isNotEmpty) {
      where.add('topic = ?');
      args.add(topic);
    }
    final rows = await db.query(
      'questions',
      where: where.join(' AND '),
      whereArgs: args,
    );
    if (rows.length < limit) {
      throw StateError(
        'Only ${rows.length} eligible questions are available; $limit requested.',
      );
    }
    final selected = rows.toList();
    final rng = random ?? Random.secure();
    if (shuffleQuestions) selected.shuffle(rng);
    final result = <Map<String, Object?>>[];
    for (final row in selected.take(limit)) {
      final options = await db.query(
        'question_options',
        where: 'question_id = ?',
        whereArgs: [row['id']],
        orderBy: 'option_key',
      );
      final orderedOptions = options.toList();
      if (shuffleOptions) orderedOptions.shuffle(rng);
      result.add({...row, 'options': orderedOptions});
    }
    return result;
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    const statements = [
      '''
      CREATE TABLE IF NOT EXISTS subjects (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        subject_code TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        education_level TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        icon TEXT NOT NULL DEFAULT '',
        total_questions INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS questions (
        id TEXT PRIMARY KEY NOT NULL,
        subject_id TEXT NOT NULL,
        topic TEXT NOT NULL,
        subtopic TEXT NOT NULL DEFAULT '',
        year INTEGER,
        difficulty TEXT NOT NULL,
        question_type TEXT NOT NULL,
        question_text TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        explanation TEXT NOT NULL,
        marks REAL NOT NULL CHECK (marks > 0),
        image_path TEXT,
        source TEXT NOT NULL,
        verification_status TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS question_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL,
        option_key TEXT NOT NULL,
        option_text TEXT NOT NULL,
        image_path TEXT,
        UNIQUE (question_id, option_key),
        FOREIGN KEY (question_id) REFERENCES questions(id) ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS exam_preferences (
        user_id TEXT PRIMARY KEY NOT NULL,
        duration_minutes INTEGER NOT NULL DEFAULT 60,
        difficulty TEXT NOT NULL DEFAULT 'Mixed',
        questions_per_exam INTEGER NOT NULL DEFAULT 20,
        shuffle_questions INTEGER NOT NULL DEFAULT 1,
        shuffle_options INTEGER NOT NULL DEFAULT 1,
        show_explanations INTEGER NOT NULL DEFAULT 1,
        negative_marking INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS registered_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (sync_status IN ('pending', 'synced')),
        created_at TEXT NOT NULL,
        UNIQUE (user_id, subject_id),
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS exam_attempts (
        id TEXT PRIMARY KEY NOT NULL,
        user_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        current_question_index INTEGER NOT NULL DEFAULT 0,
        total_questions INTEGER NOT NULL,
        correct_answers INTEGER NOT NULL DEFAULT 0,
        wrong_answers INTEGER NOT NULL DEFAULT 0,
        unanswered INTEGER NOT NULL DEFAULT 0,
        score REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL CHECK (status IN ('in_progress', 'completed', 'pending_sync')),
        question_snapshot TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS exam_answers (
        attempt_id TEXT NOT NULL,
        question_id TEXT NOT NULL,
        selected_answer TEXT,
        correct_answer TEXT NOT NULL,
        is_correct INTEGER CHECK (is_correct IS NULL OR is_correct IN (0, 1)),
        time_spent_seconds INTEGER NOT NULL DEFAULT 0,
        marked_for_review INTEGER NOT NULL DEFAULT 0 CHECK (marked_for_review IN (0, 1)),
        PRIMARY KEY (attempt_id, question_id),
        FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id) ON DELETE CASCADE,
        FOREIGN KEY (question_id) REFERENCES questions(id) ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS exam_results (
        attempt_id TEXT PRIMARY KEY NOT NULL,
        user_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        total_questions INTEGER NOT NULL,
        correct_answers INTEGER NOT NULL,
        wrong_answers INTEGER NOT NULL,
        unanswered INTEGER NOT NULL,
        total_marks REAL NOT NULL DEFAULT 0,
        score REAL NOT NULL DEFAULT 0,
        topic_performance TEXT NOT NULL DEFAULT '{}',
        percentage REAL NOT NULL,
        time_used INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS practice_sessions (
        id TEXT PRIMARY KEY NOT NULL,
        user_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        total_questions INTEGER NOT NULL,
        correct_answers INTEGER NOT NULL DEFAULT 0,
        wrong_answers INTEGER NOT NULL DEFAULT 0,
        score REAL NOT NULL DEFAULT 0,
        percentage REAL NOT NULL DEFAULT 0,
        time_spent INTEGER NOT NULL DEFAULT 0,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        status TEXT NOT NULL CHECK (status IN ('in_progress', 'completed')),
        question_snapshot TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS practice_answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        question_id TEXT NOT NULL,
        selected_answer TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        is_correct INTEGER NOT NULL CHECK (is_correct IN (0, 1)),
        UNIQUE (session_id, question_id),
        FOREIGN KEY (session_id) REFERENCES practice_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (question_id) REFERENCES questions(id) ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS question_bank_metadata (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        version TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        total_questions INTEGER NOT NULL,
        checksum TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('ready', 'importing'))
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        time_text TEXT NOT NULL,
        repeat_type TEXT NOT NULL DEFAULT 'once',
        ringtone TEXT NOT NULL DEFAULT 'default',
        enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
        next_occurrence TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        record_type TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (sync_status IN ('pending', 'syncing', 'failed', 'synced')),
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT,
        last_error TEXT,
        idempotency_key TEXT,
        created_at TEXT NOT NULL,
        UNIQUE (user_id, record_type, record_id, operation)
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS offline_exam_attempts (
        uid TEXT NOT NULL,
        session_id TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('active', 'pending')),
        nonce TEXT NOT NULL,
        cipher_text TEXT NOT NULL,
        mac TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (uid, session_id)
      )
      ''',
      'CREATE INDEX IF NOT EXISTS questions_subject_difficulty '
          'ON questions(subject_id, difficulty, is_active)',
      'CREATE INDEX IF NOT EXISTS registered_subjects_user '
          'ON registered_subjects(user_id)',
      'CREATE INDEX IF NOT EXISTS exam_attempts_user_started '
          'ON exam_attempts(user_id, started_at)',
      'CREATE INDEX IF NOT EXISTS exam_answers_attempt '
          'ON exam_answers(attempt_id)',
      'CREATE INDEX IF NOT EXISTS practice_sessions_user_completed '
          'ON practice_sessions(user_id, completed_at)',
      'CREATE INDEX IF NOT EXISTS practice_answers_session '
          'ON practice_answers(session_id)',
      'CREATE INDEX IF NOT EXISTS sync_queue_status '
          'ON sync_queue(user_id, sync_status, created_at)',
      'CREATE INDEX IF NOT EXISTS sync_queue_due '
          'ON sync_queue(user_id, sync_status, next_attempt_at)',
      'CREATE INDEX IF NOT EXISTS offline_attempts_status '
          'ON offline_exam_attempts(uid, status)',
    ];
    for (final statement in statements) {
      await db.execute(statement);
    }
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nays_mobile/core/database/nays_cbt_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'saves an idempotent result with blank answers left unanswered',
    () async {
      final directory = await Directory.systemTemp.createTemp('nays-submit-');
      final database = NaysCbtDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/exam.db',
      );

      try {
        final db = await database.database;
        await db.insert('subjects', {
          'id': 'mathematics',
          'name': 'Mathematics',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        const questionSnapshot = [
          {
            'id': 'q1',
            'question_type': 'multiple_choice',
            'correct_answer': 'A',
            'marks': 2,
            'topic': 'Algebra',
          },
          {
            'id': 'q2',
            'question_type': 'multiple_choice',
            'correct_answer': 'C',
            'marks': 3,
            'topic': 'Algebra',
          },
          {
            'id': 'q3',
            'question_type': 'short_answer',
            'correct_answer': 'answer',
            'marks': 1,
            'topic': 'Geometry',
          },
          {
            'id': 'q4',
            'question_type': 'multiple_select',
            'correct_answer': '["A","B"]',
            'marks': 4,
            'topic': 'Geometry',
          },
        ];
        final timestamp = DateTime.now().toUtc().toIso8601String();
        for (final question in questionSnapshot) {
          await db.insert('questions', {
            'id': question['id'],
            'subject_id': 'mathematics',
            'topic': question['topic'],
            'difficulty': 'Mixed',
            'question_type': question['question_type'],
            'question_text': 'Test question',
            'correct_answer': question['correct_answer'],
            'explanation': '',
            'marks': question['marks'],
            'source': 'test',
            'verification_status': 'verified',
            'created_at': timestamp,
            'updated_at': timestamp,
          });
        }
        await database.startExamAttempt(
          attemptId: 'attempt-1',
          userId: 'user-1',
          subjectId: 'mathematics',
          requireRegistration: false,
          questionSnapshot: questionSnapshot,
        );

        await database.saveExamProgress(
          attemptId: 'attempt-1',
          answers: const {'q1': 'A', 'q2': 'B', 'q3': '  ', 'q4': <String>[]},
          currentQuestionIndex: 2,
        );
        final activeAttempt = await database.getActiveExamAttempt('user-1');
        expect(activeAttempt?['current_question_index'], 2);
        expect(activeAttempt?['answers'], {'q1': 'A', 'q2': 'B'});

        final firstSubmission = await database.submitExamAttempt(
          attemptId: 'attempt-1',
          durationSeconds: 73,
        );
        final secondSubmission = await database.submitExamAttempt(
          attemptId: 'attempt-1',
          durationSeconds: 90,
        );
        expect(firstSubmission['attempt_id'], 'attempt-1');
        expect(firstSubmission['correct_answers'], 1);
        expect(firstSubmission['wrong_answers'], 1);
        expect(firstSubmission['unanswered'], 2);
        expect(firstSubmission['total_questions'], 4);
        expect(firstSubmission['total_marks'], 10);
        expect(firstSubmission['score'], 2);
        expect(firstSubmission['percentage'], 20);
        expect(firstSubmission['time_used'], 73);
        expect(secondSubmission['created_at'], firstSubmission['created_at']);
        expect(secondSubmission['time_used'], 73);

        final results = await database.getExamResults('user-1');
        expect(results, hasLength(1));
        expect(results.single['started_at'], isNotNull);
        final completedAttempt = await db.query(
          'exam_attempts',
          where: 'id = ?',
          whereArgs: ['attempt-1'],
        );
        expect(completedAttempt.single['completed_at'], isNotNull);
        final queuedResults = await db.query(
          'sync_queue',
          where: "record_type = 'exam_result' AND record_id = ?",
          whereArgs: ['attempt-1'],
        );
        expect(queuedResults, hasLength(1));
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

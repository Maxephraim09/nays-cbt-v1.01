import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nays_mobile/services/firestore_models.dart';
import 'package:nays_mobile/services/offline_exam_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MemoryKeyStore implements CbtOfflineKeyStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('encrypts, restores, and queues exam progress', () async {
    final directory = await Directory.systemTemp.createTemp('nays-offline-');
    final keyStore = _MemoryKeyStore();
    final store = CbtOfflineExamStore(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/offline.db',
      keyStore: keyStore,
      enableOfflineStorage: true,
    );
    final session = CbtExamSession(
      sessionId: 'session-1',
      subjectId: 'math',
      subjectName: 'Mathematics',
      startedAt: DateTime.utc(2026, 1, 1),
      durationMinutes: 45,
      questions: [
        CbtExamQuestion(
          questionId: 'question-1',
          questionText: 'Question private text',
          questionType: 'multiple_choice',
          options: [CbtExamOption(key: 'A', text: 'Option A')],
          marks: 1,
        ),
      ],
    );

    try {
      await store.saveProgress(
        uid: 'user-1',
        session: session,
        answers: const {'question-1': 'A'},
        currentQuestionIndex: 0,
      );
      final restored = await store.loadActiveAttempt('user-1');
      expect(restored?.session.sessionId, 'session-1');
      expect(restored?.answers, {'question-1': 'A'});
      expect(
        restored?.session.questions.single.questionText,
        'Question private text',
      );
      expect(restored?.isPendingSubmission, isFalse);

      await store.queueSubmission(
        uid: 'user-1',
        session: session,
        answers: const {'question-1': 'A'},
        currentQuestionIndex: 0,
      );
      expect(await store.loadActiveAttempt('user-1'), isNull);
      final pending = await store.loadPendingSubmissions('user-1');
      expect(pending, hasLength(1));
      expect(pending.single.isPendingSubmission, isTrue);
      expect(pending.single.answers, {'question-1': 'A'});
      expect(keyStore.values, hasLength(1));
    } finally {
      await store.close();
      await directory.delete(recursive: true);
    }
  });
}

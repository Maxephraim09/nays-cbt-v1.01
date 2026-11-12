import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nays_mobile/core/database/nays_cbt_database.dart';
import 'package:nays_mobile/data/services/question_bank_seeder.dart';
import 'package:nays_mobile/services/firestore_service.dart';
import 'package:nays_mobile/services/jamb_simulation_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  test(
    'saves JAMB subjects and starts a unique 180-question local session',
    () async {
      final directory = await Directory.systemTemp.createTemp('nays-jamb-');
      final database = NaysCbtDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/jamb.db',
      );
      SharedPreferences.setMockInitialValues({});
      final service = FirestoreCbtService(
        database: database,
        localUserId: 'jamb-test-user',
      );
      const subjectIds = [
        'english_language',
        'mathematics',
        'biology',
        'chemistry',
      ];

      try {
        await QuestionBankSeeder(database).seedBundledBank();
        await service.saveJambSubjectIds(subjectIds);
        expect(await service.loadJambSubjectIds(), subjectIds);

        final session = await service.startJambExam(subjectIds: subjectIds);
        expect(session.durationMinutes, JambSimulationConfig.durationMinutes);
        expect(
          session.questions,
          hasLength(JambSimulationConfig.totalQuestionCount),
        );
        expect(
          session.questions.map((question) => question.questionId).toSet(),
          hasLength(JambSimulationConfig.totalQuestionCount),
        );
        expect(
          session.questions
              .take(JambSimulationConfig.englishQuestionCount)
              .every((question) => question.subjectId == 'english_language'),
          isTrue,
        );
        final counts = <String, int>{};
        for (final question in session.questions) {
          counts.update(
            question.subjectName,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        expect(counts, {
          'English Language': 60,
          'Mathematics': 40,
          'Biology': 40,
          'Chemistry': 40,
        });

        final restored = await service.loadActiveExam();
        expect(restored?.session.subjectName, 'JAMB Simulation');
        expect(restored?.session.durationMinutes, 120);
        expect(restored?.session.questions, hasLength(180));

        final emptyBankMessage = contains(
          'awaiting the official source document',
        );
        await service.registerSubject('yungur');
        await expectLater(
          service.startOfflineExam(subjectId: 'yungur'),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              emptyBankMessage,
            ),
          ),
        );
        await expectLater(
          service.loadPracticeSession(subjectId: 'yungur'),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              emptyBankMessage,
            ),
          ),
        );
        await expectLater(
          service.startJambExam(
            subjectIds: const [
              'english_language',
              'mathematics',
              'biology',
              'yungur',
            ],
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              emptyBankMessage,
            ),
          ),
        );
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

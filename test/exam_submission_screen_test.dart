import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nays_mobile/app_state.dart';
import 'package:nays_mobile/screens/cbt_screens.dart';
import 'package:nays_mobile/services/firestore_models.dart';
import 'package:nays_mobile/services/firestore_service.dart';
import 'package:nays_mobile/theme/app_theme.dart';

void main() {
  testWidgets(
    'shows the submit action and cancellation preserves the exam screen',
    (tester) async {
      final controller = DemoAppController()..setAnswer('question-1', 'A');
      final now = DateTime.now();
      final session = CbtExamSession(
        sessionId: 'screen-session',
        subjectId: 'mathematics',
        subjectName: 'Mathematics',
        startedAt: now,
        durationMinutes: 60,
        isOffline: true,
        questions: [
          const CbtExamQuestion(
            questionId: 'question-1',
            questionText: 'First question',
            questionType: 'multiple_choice',
            options: [],
            marks: 1,
          ),
          const CbtExamQuestion(
            questionId: 'question-2',
            questionText: 'Second question',
            questionType: 'multiple_choice',
            options: [],
            marks: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ExamScreen(
            controller: controller,
            service: FirestoreCbtService(localUserId: 'widget-user'),
            session: session,
          ),
        ),
      );

      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      final submitButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Submit'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(submitButton.style?.foregroundColor?.resolve({}), Colors.white);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('answered 1 questions and left 1 unanswered'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Once submitted, you cannot modify your answers.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit Exam'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('First question'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Submit Exam'), findsNothing);
      controller.dispose();
    },
  );
}

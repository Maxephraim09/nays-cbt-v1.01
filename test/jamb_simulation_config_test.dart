import 'package:flutter_test/flutter_test.dart';
import 'package:nays_mobile/services/jamb_simulation_config.dart';

void main() {
  const available = {'english_language', 'mathematics', 'biology', 'chemistry'};

  test('uses the fixed JAMB question distribution and duration', () {
    expect(JambSimulationConfig.questionCountFor('english_language'), 60);
    expect(JambSimulationConfig.questionCountFor('mathematics'), 40);
    expect(JambSimulationConfig.questionCountFor('biology'), 40);
    expect(JambSimulationConfig.questionCountFor('chemistry'), 40);
    expect(JambSimulationConfig.totalQuestionCount, 180);
    expect(JambSimulationConfig.durationMinutes, 120);
  });

  test('requires English and exactly three distinct available subjects', () {
    expect(
      JambSimulationConfig.isConfigured(
        available,
        availableSubjectIds: available,
      ),
      isTrue,
    );
    expect(
      JambSimulationConfig.isConfigured({
        'mathematics',
        'biology',
        'chemistry',
      }, availableSubjectIds: available),
      isFalse,
    );
    expect(
      JambSimulationConfig.isConfigured([
        'english_language',
        'mathematics',
        'mathematics',
        'chemistry',
      ], availableSubjectIds: available),
      isFalse,
    );
    expect(
      JambSimulationConfig.isConfigured({
        ...available,
        'economics',
      }, availableSubjectIds: available),
      isFalse,
    );
  });

  test('prevents duplicate and excess additional subject selections', () {
    expect(JambSimulationConfig.canAddSubject(['mathematics']), isTrue);
    expect(
      JambSimulationConfig.canAddSubject(['mathematics', 'biology']),
      isTrue,
    );
    expect(
      JambSimulationConfig.canAddSubject([
        'mathematics',
        'biology',
        'chemistry',
      ]),
      isFalse,
    );
    expect(
      JambSimulationConfig.canAddSubject(['mathematics', 'mathematics']),
      isFalse,
    );
    expect(
      JambSimulationConfig.normalizeAdditionalSubjects([
        'english_language',
        'mathematics',
        'mathematics',
        'biology',
      ]),
      ['mathematics', 'biology'],
    );
  });

  test('validates the PIN locally and rejects incorrect values', () {
    expect(JambSimulationConfig.isValidPin('NAYSCBT1234'), isTrue);
    expect(JambSimulationConfig.isValidPin('NAYSCBT123'), isFalse);
    expect(JambSimulationConfig.isValidPin(''), isFalse);
  });
}

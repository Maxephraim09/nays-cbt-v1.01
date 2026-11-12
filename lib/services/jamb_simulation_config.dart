class JambSimulationConfig {
  const JambSimulationConfig._();

  static const englishSubjectId = 'english_language';
  static const durationMinutes = 120;
  static const totalQuestionCount = 180;
  static const englishQuestionCount = 60;
  static const additionalSubjectQuestionCount = 40;
  static const additionalSubjectCount = 3;
  static const totalSubjectCount = additionalSubjectCount + 1;

  static const examPin = 'NAYSCBT1234';

  static int questionCountFor(String subjectId) => subjectId == englishSubjectId
      ? englishQuestionCount
      : additionalSubjectQuestionCount;

  static bool canAddSubject(Iterable<String> additionalSubjectIds) =>
      additionalSubjectIds.toSet().length == additionalSubjectIds.length &&
      additionalSubjectIds.length < additionalSubjectCount;

  static bool isConfigured(
    Iterable<String> selectedSubjectIds, {
    required Iterable<String> availableSubjectIds,
  }) {
    final selected = selectedSubjectIds.toList(growable: false);
    final available = availableSubjectIds.toSet();
    return selected.length == totalSubjectCount &&
        selected.toSet().length == totalSubjectCount &&
        selected.contains(englishSubjectId) &&
        selected.every(available.contains);
  }

  static List<String> normalizeAdditionalSubjects(Iterable<String> subjectIds) {
    final unique = <String>[];
    for (final subjectId in subjectIds) {
      if (subjectId == englishSubjectId || unique.contains(subjectId)) continue;
      unique.add(subjectId);
    }
    return unique;
  }

  static bool isValidPin(String enteredPin) => enteredPin.trim() == examPin;
}

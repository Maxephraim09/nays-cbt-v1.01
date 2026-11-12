import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoAppController extends ChangeNotifier {
  final List<String> subjects = [];
  final Map<String, String> registeredSubjectNamesById = {};
  final Map<String, dynamic> answers = {};
  String difficulty = 'Mixed';
  int durationMinutes = 60;
  int questionsPerExam = 20;
  bool shuffleQuestions = true;
  bool shuffleAnswers = true;
  bool showExplanations = true;
  bool negativeMarking = false;
  bool notificationsEnabled = true;
  ThemeMode themeMode = ThemeMode.light;

  Future<bool> hasCompletedOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    themeMode = preferences.getBool('dark_theme') == true
        ? ThemeMode.dark
        : ThemeMode.light;
    notificationsEnabled = preferences.getBool('notifications') ?? true;
    notifyListeners();
    return preferences.getBool('onboarding_complete') ?? false;
  }

  Future<void> completeOnboarding() async =>
      (await SharedPreferences.getInstance()).setBool(
        'onboarding_complete',
        true,
      );

  void setRegisteredSubjects(Map<String, String> subjectNamesById) {
    registeredSubjectNamesById
      ..clear()
      ..addAll(subjectNamesById);
    subjects
      ..clear()
      ..addAll(subjectNamesById.values);
    notifyListeners();
  }

  void updateSettings({
    String? nextDifficulty,
    int? nextDuration,
    int? nextQuestionCount,
    bool? nextShuffle,
    bool? nextShuffleAnswers,
    bool? nextShowExplanations,
    bool? nextNegativeMarking,
  }) {
    difficulty = nextDifficulty ?? difficulty;
    durationMinutes = nextDuration ?? durationMinutes;
    questionsPerExam = nextQuestionCount ?? questionsPerExam;
    shuffleQuestions = nextShuffle ?? shuffleQuestions;
    shuffleAnswers = nextShuffleAnswers ?? shuffleAnswers;
    showExplanations = nextShowExplanations ?? showExplanations;
    negativeMarking = nextNegativeMarking ?? negativeMarking;
    notifyListeners();
  }

  void setAnswer(String questionId, dynamic answer) {
    answers[questionId] = answer;
    notifyListeners();
  }

  void clearAnswers() {
    answers.clear();
    notifyListeners();
  }

  void restoreAnswers(Map<String, dynamic> savedAnswers) {
    answers
      ..clear()
      ..addAll(savedAnswers);
    notifyListeners();
  }

  Future<void> setDarkTheme(bool enabled) async {
    themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    await (await SharedPreferences.getInstance()).setBool(
      'dark_theme',
      enabled,
    );
    notifyListeners();
  }

  Future<void> setNotifications(bool enabled) async {
    notificationsEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool(
      'notifications',
      enabled,
    );
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/database/nays_cbt_database.dart';
import 'data/services/question_bank_seeder.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = NaysCbtDatabase.instance;
  await database.initializeForCurrentPlatform();
  await database.database;
  final questionBank = await QuestionBankSeeder(database).seedBundledBank();
  debugPrint(
    'Question bank ${questionBank.version}: '
    '${questionBank.questionCount} questions imported.',
  );
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const NaysApp());
  } catch (_) {
    runApp(const FirebaseStartupFailureApp());
  }
}

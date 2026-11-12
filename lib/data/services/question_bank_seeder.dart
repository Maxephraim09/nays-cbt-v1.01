import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/database/nays_cbt_database.dart';
import 'question_bank_importer.dart';

class QuestionBankSeeder {
  QuestionBankSeeder(this.database, {AssetBundle? bundle, this.onProgress})
    : _bundle = bundle ?? rootBundle;

  static const assetRoot = 'assets/database/question_bank';

  final NaysCbtDatabase database;
  final AssetBundle _bundle;
  final void Function(int loadedFiles, int totalFiles)? onProgress;

  Future<QuestionBankImportResult> seedBundledBank() async {
    final manifestPath = '$assetRoot/manifest.json';
    final manifestJson = await _bundle.loadString(manifestPath);

    final decodedManifest = jsonDecode(manifestJson);
    if (decodedManifest is! Map || decodedManifest['question_files'] is! List) {
      throw const FormatException(
        'Question-bank manifest must declare question_files.',
      );
    }
    final questionFilePaths = (decodedManifest['question_files'] as List)
        .map((path) {
          if (path is! String ||
              path.isEmpty ||
              path.startsWith('/') ||
              path.contains('\\') ||
              path.split('/').contains('..')) {
            throw const FormatException(
              'Question-bank manifest contains an invalid question file path.',
            );
          }
          return path;
        })
        .toList(growable: false);
    final questionFiles = <String, String>{};
    onProgress?.call(0, questionFilePaths.length);
    for (var index = 0; index < questionFilePaths.length; index++) {
      final path = questionFilePaths[index];
      questionFiles[path] = await _bundle.loadString('$assetRoot/$path');
      onProgress?.call(index + 1, questionFilePaths.length);
    }
    final subjectsJson = await _bundle.loadString('$assetRoot/subjects.json');
    return QuestionBankImporter(database).import(
      manifestJson: manifestJson,
      subjectsJson: subjectsJson,
      questionFiles: questionFiles,
    );
  }
}

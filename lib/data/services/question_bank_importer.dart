import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/nays_cbt_database.dart';

class QuestionBankImportException implements Exception {
  const QuestionBankImportException(this.issues);

  final List<String> issues;

  @override
  String toString() =>
      'Question-bank import rejected:\n${issues.map((issue) => '- $issue').join('\n')}';
}

class QuestionBankImportResult {
  const QuestionBankImportResult({
    required this.version,
    required this.subjectCount,
    required this.questionCount,
    required this.checksum,
  });

  final String version;
  final int subjectCount;
  final int questionCount;
  final String checksum;
}

class QuestionBankImporter {
  QuestionBankImporter(this.database);

  final NaysCbtDatabase database;
  static final Sha256 _sha256 = Sha256();

  Future<QuestionBankImportResult> import({
    required String manifestJson,
    required String subjectsJson,
    required Map<String, String> questionFiles,
  }) async {
    final issues = <String>[];
    final manifest = _decodeObject(manifestJson, 'manifest', issues);
    final subjectData = _decodeList(subjectsJson, 'subjects', issues);
    final version = manifest?['version'];
    final expectedCount = manifest?['total_questions'];
    final declaredFiles = manifest?['question_files'];
    if (version is! String || version.trim().isEmpty) {
      issues.add('manifest.version must be a non-empty string.');
    }
    if (expectedCount is! int || expectedCount < 0) {
      issues.add('manifest.total_questions must be a non-negative integer.');
    }
    if (declaredFiles is! List ||
        declaredFiles.any((path) => path is! String)) {
      issues.add('manifest.question_files must be a list of file paths.');
    } else {
      final declared = declaredFiles.cast<String>().toSet();
      if (declared.length != declaredFiles.length) {
        issues.add('manifest.question_files contains duplicate paths.');
      }
      if (declared.difference(questionFiles.keys.toSet()).isNotEmpty ||
          questionFiles.keys.toSet().difference(declared).isNotEmpty) {
        issues.add(
          'Loaded question files must exactly match manifest.question_files.',
        );
      }
    }

    final subjects = <String, Map<String, Object?>>{};
    for (var index = 0; index < subjectData.length; index++) {
      final raw = subjectData[index];
      if (raw is! Map) {
        issues.add('subjects[$index] must be an object.');
        continue;
      }
      final subject = Map<String, dynamic>.from(raw);
      final id = subject['id'];
      final name = subject['name'];
      if (id is! String || id.trim().isEmpty) {
        issues.add('subjects[$index].id must be a non-empty string.');
        continue;
      }
      if (name is! String || name.trim().isEmpty) {
        issues.add('subjects[$index].name must be a non-empty string.');
        continue;
      }
      if (subjects.containsKey(id)) {
        issues.add('Duplicate subject id "$id".');
        continue;
      }
      subjects[id] = {
        'id': id,
        'name': name.trim(),
        'subject_code': _stringOrDefault(subject['subject_code'], ''),
        'category': _stringOrDefault(subject['category'], ''),
        'education_level': _stringOrDefault(subject['education_level'], ''),
        'description': _stringOrDefault(subject['description'], ''),
        'icon': _stringOrDefault(subject['icon'], ''),
        'total_questions': 0,
        'is_active': subject['is_active'] == false ? 0 : 1,
        'created_at': _stringOrDefault(
          subject['created_at'],
          DateTime.now().toUtc().toIso8601String(),
        ),
      };
    }
    if (subjects.isEmpty) issues.add('The question bank has no valid subjects.');

    final questions = <Map<String, Object?>>[];
    final questionIds = <String>{};
    final questionTexts = <String>{};
    var fileQuestionCount = 0;
    for (final entry in questionFiles.entries) {
      final rows = _decodeList(entry.value, entry.key, issues);
      for (var index = 0; index < rows.length; index++) {
        fileQuestionCount++;
        final location = '${entry.key}[$index]';
        final raw = rows[index];
        if (raw is! Map) {
          issues.add('$location must be an object.');
          continue;
        }
        final question = Map<String, dynamic>.from(raw);
        final parsed = _parseQuestion(
          question,
          location,
          subjects.keys.toSet(),
          issues,
        );
        if (parsed == null) continue;
        final id = parsed['id']! as String;
        if (!questionIds.add(id)) {
          issues.add('$location duplicates question id "$id".');
          continue;
        }
        final duplicateKey = _normalizeQuestionText(
          parsed['question_text']! as String,
        );
        if (!questionTexts.add(duplicateKey)) {
          issues.add('$location duplicates normalized question text.');
          continue;
        }
        questions.add(parsed);
      }
    }
    if (expectedCount is int && expectedCount != fileQuestionCount) {
      issues.add(
        'manifest.total_questions is $expectedCount, but $fileQuestionCount questions were provided.',
      );
    }
    if (issues.isNotEmpty) throw QuestionBankImportException(issues);

    final canonicalContent = [
      manifestJson,
      subjectsJson,
      for (final path in questionFiles.keys.toList()..sort())
        '$path\n${questionFiles[path]}',
    ].join('\n');
    final digest = await _sha256.hash(utf8.encode(canonicalContent));
    final checksum = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final importedAt = DateTime.now().toUtc().toIso8601String();

    final db = await database.database;
    final previousImport = await db.query(
      'question_bank_metadata',
      where: 'id = 1',
      limit: 1,
    );
    if (previousImport.isNotEmpty &&
        previousImport.single['version'] == version &&
        previousImport.single['checksum'] == checksum &&
        previousImport.single['status'] == 'ready') {
      return QuestionBankImportResult(
        version: version as String,
        subjectCount: subjects.length,
        questionCount: questions.length,
        checksum: checksum,
      );
    }

    await db.transaction((txn) async {
      for (final subject in subjects.values) {
        final id = subject['id'];
        final existing = await txn.query(
          'subjects',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert('subjects', subject);
        } else {
          final values = Map<String, Object?>.from(subject)..remove('id');
          await txn.update(
            'subjects',
            values,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      final existingQuestionIds = <String>{};
      const idChunkSize = 500;
      for (var offset = 0; offset < questions.length; offset += idChunkSize) {
        final chunk = questions.skip(offset).take(idChunkSize).toList();
        final placeholders = List.filled(chunk.length, '?').join(', ');
        final rows = await txn.query(
          'questions',
          columns: ['id'],
          where: 'id IN ($placeholders)',
          whereArgs: chunk.map((question) => question['id']).toList(),
        );
        existingQuestionIds.addAll(rows.map((row) => row['id']! as String));
      }

      final questionBatch = txn.batch();
      for (final question in questions) {
        final options = question.remove('options')! as List<Map<String, Object?>>;
        final id = question['id'];
        if (existingQuestionIds.contains(id)) {
          final values = Map<String, Object?>.from(question)..remove('id');
          questionBatch.update(
            'questions',
            values,
            where: 'id = ?',
            whereArgs: [id],
          );
          questionBatch.delete(
            'question_options',
            where: 'question_id = ?',
            whereArgs: [id],
          );
        } else {
          questionBatch.insert('questions', question);
        }
        for (final option in options) {
          questionBatch.insert('question_options', {
            ...option,
            'question_id': id,
          });
        }
      }
      await questionBatch.commit(noResult: true);
      for (final subjectId in subjects.keys) {
        final count = Sqflite.firstIntValue(
          await txn.rawQuery(
            'SELECT COUNT(*) FROM questions WHERE subject_id = ? AND is_active = 1',
            [subjectId],
          ),
        );
        await txn.update(
          'subjects',
          {'total_questions': count ?? 0},
          where: 'id = ?',
          whereArgs: [subjectId],
        );
      }
      final count = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT COUNT(*) FROM questions WHERE is_active = 1'),
      );
      await txn.insert(
        'question_bank_metadata',
        {
          'id': 1,
          'version': version as String,
          'imported_at': importedAt,
          'total_questions': count ?? 0,
          'checksum': checksum,
          'status': 'ready',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return QuestionBankImportResult(
      version: version as String,
      subjectCount: subjects.length,
      questionCount: questions.length,
      checksum: checksum,
    );
  }

  Map<String, Object?>? _parseQuestion(
    Map<String, dynamic> question,
    String location,
    Set<String> subjectIds,
    List<String> issues,
  ) {
    final id = question['id'];
    final subjectId = question['subject_id'];
    final questionText = question['question'] ?? question['question_text'];
    final difficulty = question['difficulty'];
    final questionType = question['question_type'];
    final topic = question['topic'];
    final correctAnswer = question['correct_answer'];
    final explanation = question['explanation'] ?? question['reasoning'];
    final source = question['source'];
    final verificationStatus = question['verification_status'];
    final marks = question['marks'];
    final optionsValue = question['options'];
    var valid = true;

    void requireString(dynamic value, String field) {
      if (value is! String || value.trim().isEmpty) {
        issues.add('$location.$field must be a non-empty string.');
        valid = false;
      }
    }

    requireString(id, 'id');
    requireString(subjectId, 'subject_id');
    requireString(topic, 'topic');
    requireString(difficulty, 'difficulty');
    requireString(questionType, 'question_type');
    requireString(questionText, 'question');
    requireString(explanation, 'explanation');
    requireString(source, 'source');
    requireString(verificationStatus, 'verification_status');
    if (subjectId is String && !subjectIds.contains(subjectId)) {
      issues.add('$location references unknown subject "$subjectId".');
      valid = false;
    }
    if (difficulty is String &&
        !const {'easy', 'medium', 'hard'}.contains(difficulty.toLowerCase())) {
      issues.add('$location.difficulty must be Easy, Medium, or Hard.');
      valid = false;
    }
    if (marks is! num || marks <= 0) {
      issues.add('$location.marks must be a positive number.');
      valid = false;
    }
    final year = question['year'];
    if (year != null && year is! int) {
      issues.add('$location.year must be an integer or null.');
      valid = false;
    }

    final normalizedOptions = optionsValue is Map
        ? optionsValue.entries
              .map(
                (entry) => <String, dynamic>{
                  'id': entry.key,
                  'text': entry.value,
                },
              )
              .toList()
        : optionsValue;
    final options = <Map<String, Object?>>[];
    final optionKeys = <String>{};
    if (normalizedOptions is! List || normalizedOptions.length != 4) {
      issues.add('$location.options must contain exactly four options.');
      valid = false;
    } else {
      for (var index = 0; index < normalizedOptions.length; index++) {
        final rawOption = normalizedOptions[index];
        if (rawOption is! Map) {
          issues.add('$location.options[$index] must be an object.');
          valid = false;
          continue;
        }
        final option = Map<String, dynamic>.from(rawOption);
        final key = option['id'] ?? option['key'];
        final text = option['text'];
        if (key is! String || key.trim().isEmpty) {
          issues.add('$location.options[$index].id must be a non-empty string.');
          valid = false;
          continue;
        }
        if (text is! String || text.trim().isEmpty) {
          issues.add('$location.options[$index].text must be a non-empty string.');
          valid = false;
          continue;
        }
        if (!optionKeys.add(key)) {
          issues.add('$location contains duplicate option id "$key".');
          valid = false;
          continue;
        }
        options.add({
          'option_key': key,
          'option_text': text.trim(),
          'image_path': option['image'] is String ? option['image'] : null,
        });
      }
    }
    if (optionKeys.length != 4 ||
        !optionKeys.containsAll(const {'A', 'B', 'C', 'D'})) {
      issues.add('$location.options must use the unique IDs A, B, C, and D.');
      valid = false;
    }
    if (questionType == 'multiple_select') {
      if (correctAnswer is! List ||
          correctAnswer.isEmpty ||
          correctAnswer.any(
            (answer) => answer is! String || !optionKeys.contains(answer),
          ) ||
          correctAnswer.toSet().length != correctAnswer.length) {
        issues.add(
          '$location.correct_answer must contain unique valid option ids.',
        );
        valid = false;
      }
    } else if (correctAnswer is! String ||
        !const {'A', 'B', 'C', 'D'}.contains(correctAnswer)) {
      issues.add('$location.correct_answer must be one of A, B, C, or D.');
      valid = false;
    } else if (questionType is String &&
        {'multiple_choice', 'true_false'}.contains(questionType) &&
        !optionKeys.contains(correctAnswer)) {
      issues.add('$location.correct_answer does not match an option id.');
      valid = false;
    }
    if (!valid) return null;

    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': id as String,
      'subject_id': subjectId as String,
      'topic': (topic as String).trim(),
      'subtopic': _stringOrDefault(question['subtopic'], ''),
      'year': year as int?,
      'difficulty': (difficulty as String).trim().toLowerCase(),
      'question_type': (questionType as String).trim(),
      'question_text': (questionText as String).trim(),
      'correct_answer': correctAnswer is List
          ? jsonEncode(correctAnswer)
          : correctAnswer as String,
      'explanation': (explanation as String).trim(),
      'marks': (marks as num).toDouble(),
      'image_path': question['image'] is String ? question['image'] : null,
      'source': (source as String).trim(),
      'verification_status': (verificationStatus as String).trim(),
      'is_active': question['is_active'] == false ? 0 : 1,
      'created_at': _stringOrDefault(question['created_at'], now),
      'updated_at': now,
      'options': options,
    };
  }

  Map<String, dynamic>? _decodeObject(
    String source,
    String label,
    List<String> issues,
  ) {
    try {
      final value = jsonDecode(source);
      if (value is Map<String, dynamic>) return value;
      issues.add('$label must be a JSON object.');
    } on FormatException catch (error) {
      issues.add('$label is invalid JSON: ${error.message}');
    }
    return null;
  }

  List<dynamic> _decodeList(
    String source,
    String label,
    List<String> issues,
  ) {
    try {
      final value = jsonDecode(source);
      if (value is List) return value;
      issues.add('$label must be a JSON list.');
    } on FormatException catch (error) {
      issues.add('$label is invalid JSON: ${error.message}');
    }
    return const [];
  }

  String _stringOrDefault(dynamic value, String fallback) =>
      value is String ? value : fallback;

  String _normalizeQuestionText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

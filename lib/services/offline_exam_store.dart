import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/nays_cbt_database.dart';
import 'firestore_models.dart';

abstract interface class CbtOfflineKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FlutterCbtOfflineKeyStore implements CbtOfflineKeyStore {
  FlutterCbtOfflineKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class OfflineExamAttempt {
  const OfflineExamAttempt({
    required this.session,
    required this.answers,
    required this.currentQuestionIndex,
    required this.isPendingSubmission,
  });

  final CbtExamSession session;
  final Map<String, dynamic> answers;
  final int currentQuestionIndex;
  final bool isPendingSubmission;
}

class CbtOfflineExamStore {
  CbtOfflineExamStore({
    CbtOfflineKeyStore? keyStore,
    DatabaseFactory? factory,
    String? databasePath,
    NaysCbtDatabase? database,
    bool? enableOfflineStorage,
  }) : _keyStore = keyStore ?? FlutterCbtOfflineKeyStore(),
       _database =
           database ??
           (factory == null && databasePath == null
               ? NaysCbtDatabase.instance
               : NaysCbtDatabase(factory: factory, databasePath: databasePath)),
       _enableOfflineStorage = enableOfflineStorage;

  static const _keyPrefix = 'nays_cbt_offline_key_';
  static final _algorithm = AesGcm.with256bits();

  final CbtOfflineKeyStore _keyStore;
  final NaysCbtDatabase _database;
  final bool? _enableOfflineStorage;
  final Map<String, SecretKey> _keys = {};

  bool get isSupported =>
      _enableOfflineStorage ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  Future<void> saveProgress({
    required String uid,
    required CbtExamSession session,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) async {
    if (!isSupported) return;
    await _writeAttempt(
      uid: uid,
      session: session,
      answers: answers,
      currentQuestionIndex: currentQuestionIndex,
      status: 'active',
    );
  }

  Future<void> queueSubmission({
    required String uid,
    required CbtExamSession session,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Offline CBT submissions require the mobile app.');
    }
    await _writeAttempt(
      uid: uid,
      session: session,
      answers: answers,
      currentQuestionIndex: currentQuestionIndex,
      status: 'pending',
    );
  }

  Future<OfflineExamAttempt?> loadActiveAttempt(String uid) async {
    if (!isSupported) return null;
    final rows = await (await _db).query(
      'offline_exam_attempts',
      where: 'uid = ? AND status = ?',
      whereArgs: [uid, 'active'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeAttempt(rows.single, isPendingSubmission: false);
  }

  Future<List<OfflineExamAttempt>> loadPendingSubmissions(String uid) async {
    if (!isSupported) return const [];
    final rows = await (await _db).query(
      'offline_exam_attempts',
      where: 'uid = ? AND status = ?',
      whereArgs: [uid, 'pending'],
      orderBy: 'updated_at',
    );
    return Future.wait(
      rows.map((row) => _decodeAttempt(row, isPendingSubmission: true)),
    );
  }

  Future<void> deleteAttempt({
    required String uid,
    required String sessionId,
  }) async {
    if (!isSupported) return;
    await (await _db).delete(
      'offline_exam_attempts',
      where: 'uid = ? AND session_id = ?',
      whereArgs: [uid, sessionId],
    );
  }

  Future<void> close() async {
    await _database.close();
  }

  Future<void> _writeAttempt({
    required String uid,
    required CbtExamSession session,
    required Map<String, dynamic> answers,
    required int currentQuestionIndex,
    required String status,
  }) async {
    if (uid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'Must not be empty.');
    }
    if (currentQuestionIndex < 0 ||
        currentQuestionIndex >= session.questions.length) {
      throw RangeError.range(
        currentQuestionIndex,
        0,
        session.questions.length - 1,
        'currentQuestionIndex',
      );
    }
    final payload = utf8.encode(
      jsonEncode({
        'session': session.toMap(),
        'answers': answers,
        'currentQuestionIndex': currentQuestionIndex,
      }),
    );
    final key = await _keyForUser(uid);
    final box = await _algorithm.encrypt(
      payload,
      secretKey: key,
      nonce: _algorithm.newNonce(),
    );
    await (await _db).insert('offline_exam_attempts', {
      'uid': uid,
      'session_id': session.sessionId,
      'status': status,
      'nonce': base64Encode(box.nonce),
      'cipher_text': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<OfflineExamAttempt> _decodeAttempt(
    Map<String, Object?> row, {
    required bool isPendingSubmission,
  }) async {
    final uid = row['uid']! as String;
    final secretBox = SecretBox(
      base64Decode(row['cipher_text']! as String),
      nonce: base64Decode(row['nonce']! as String),
      mac: Mac(base64Decode(row['mac']! as String)),
    );
    final bytes = await _algorithm.decrypt(
      secretBox,
      secretKey: await _keyForUser(uid),
    );
    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return OfflineExamAttempt(
      session: CbtExamSession.fromMap(
        Map<String, dynamic>.from(payload['session'] as Map),
      ),
      answers: Map<String, dynamic>.from(payload['answers'] as Map),
      currentQuestionIndex: payload['currentQuestionIndex'] as int,
      isPendingSubmission: isPendingSubmission,
    );
  }

  Future<SecretKey> _keyForUser(String uid) async {
    final cached = _keys[uid];
    if (cached != null) return cached;
    final storageKey = '$_keyPrefix${base64Url.encode(utf8.encode(uid))}';
    final stored = await _keyStore.read(storageKey);
    final keyBytes = stored == null
        ? List<int>.generate(32, (_) => Random.secure().nextInt(256))
        : base64Decode(stored);
    if (keyBytes.length != 32) {
      throw StateError('The encrypted CBT storage key is invalid.');
    }
    if (stored == null) {
      await _keyStore.write(storageKey, base64Encode(keyBytes));
    }
    return _keys[uid] = SecretKey(keyBytes);
  }

  Future<Database> get _db async {
    return _database.database;
  }
}

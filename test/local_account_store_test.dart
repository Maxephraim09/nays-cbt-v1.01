import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nays_mobile/auth_service.dart';
import 'package:nays_mobile/services/local_account_store.dart';
import 'package:nays_mobile/services/offline_exam_store.dart';

class _MemorySecureStore implements CbtOfflineKeyStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test(
    'creates and authenticates a device-local account without Firebase',
    () async {
      final secureStore = _MemorySecureStore();
      final localAccounts = LocalAccountStore(secureStore: secureStore);
      final auth = MockFirebaseAuth();
      final service = FirebaseAuthService(
        auth: auth,
        localAccounts: localAccounts,
      );

      final account = await service.createEmailAccount(
        displayName: 'Offline learner',
        email: 'learner@example.test',
        phoneNumber: '08000000000',
        password: 'strong-password',
      );

      expect(auth.currentUser, isNull);
      expect((await service.currentLocalAccount())?.uid, account.uid);
      expect(account.email, 'learner@example.test');
      expect(account.pendingPassword, isNull);
      expect(
        secureStore.values.values.join(),
        isNot(contains('strong-password')),
      );

      await expectLater(
        service.signInWithEmail('learner@example.test', 'wrong-password'),
        throwsA(isA<AuthFailure>()),
      );
      await service.signOut();
      expect(await service.currentLocalAccount(), isNull);
      await service.signInWithEmail('LEARNER@example.test', 'strong-password');

      expect(auth.currentUser, isNull);
      expect((await service.currentLocalAccount())?.uid, account.uid);

      await localAccounts.markFirebaseAccountCreated(
        account.uid,
        emailVerified: false,
      );
      auth.mockUser = MockUser(
        uid: 'firebase-learner',
        email: account.email,
        displayName: account.displayName,
      );
      await service.signOut();
      await service.signInWithEmail(account.email, 'strong-password');

      expect(auth.currentUser?.email, account.email);
      expect(await service.currentLocalAccount(), isNull);
    },
  );

  test(
    'keeps only the password verifier after cloud account creation',
    () async {
      final store = LocalAccountStore(secureStore: _MemorySecureStore());
      final account = await store.create(
        displayName: 'Offline learner',
        email: 'learner@example.test',
        phoneNumber: '',
        password: 'strong-password',
      );

      await store.markFirebaseAccountCreated(account.uid, emailVerified: false);
      final restored = await store.findByEmail(account.email);

      expect(restored?.pendingPassword, isNull);
      expect(restored?.firebaseAccountCreated, isTrue);
      expect(restored?.emailVerified, isFalse);
      expect(await store.verifyPassword(restored!, 'strong-password'), isTrue);
    },
  );

  test(
    'removes legacy plaintext passwords when restoring local accounts',
    () async {
      const uid = 'local-legacy';
      const password = 'legacy-plaintext-password';
      final secureStore = _MemorySecureStore()
        ..values['nays_local_active_account'] = uid
        ..values['nays_local_account_$uid'] =
            '{"uid":"$uid","email":"learner@example.test",'
            '"displayName":"Offline learner","phoneNumber":"",'
            '"passwordSalt":"","passwordHash":"","pendingPassword":"$password",'
            '"firebaseAccountCreated":false,"emailVerified":false}';
      final store = LocalAccountStore(secureStore: secureStore);

      final restored = await store.activeAccount();

      expect(restored?.pendingPassword, isNull);
      expect(
        secureStore.values['nays_local_account_$uid'],
        isNot(contains(password)),
      );
    },
  );
}

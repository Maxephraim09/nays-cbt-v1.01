# NAYS CBT architecture audit and offline-first migration plan

## Current architecture

- Flutter entry point: `lib/main.dart` initializes Firebase using
  `lib/firebase_options.dart`; startup failure is surfaced by a dedicated app.
- Authentication: `lib/auth_service.dart` wraps Firebase Authentication,
  including email flows and configured social sign-in.
- State and navigation: `lib/app_state.dart`, `lib/app.dart`, and screens under
  `lib/screens/` manage the existing app and branded navigation.
- CBT data access: `lib/services/firestore_service.dart` is the primary
  repository/service. It reads active subjects, registrations, preferences,
  results, and leaderboard data from Firestore and calls the exam functions.
- Firestore models: `lib/services/firestore_models.dart` maps Firestore
  subject, question snapshot, session, preferences, result, and leaderboard
  data.
- Exam UI: `lib/screens/cbt_screens.dart` handles registered-subject access,
  preferences, exam preparation, session navigation, countdown and answer
  interaction. `lib/screens/info_screens.dart` renders history and results;
  `lib/screens/leaderboard_screen.dart` renders leaderboard entries.
- Offline recovery: `lib/services/offline_exam_store.dart` stores encrypted
  snapshots and pending submissions for server-created mobile exam sessions.
  It is not a local question bank and cannot start an exam without a callable
  backend session.
- Server functions: `functions/src/index.ts` defines `startCbtExam` and
  `submitCbtExam` in `us-central1`. It selects Firestore questions, keeps
  answer keys server-side, grades submissions, persists results and updates
  leaderboard aggregates.
- Content: `seed_data/exam_bank.tsv` is an original practice-question source;
  `scripts/build_exam_bank.py` produces Firebase/Laravel seed artifacts. There
  is currently no bundled JSON question-bank asset in `assets/`.
- SQLite dependencies are already declared, but current SQLite usage is only
  the encrypted offline exam-session cache. There is no shared application
  database, question importer, or local subject/preferences/result repository.

## Firestore-dependent exam surfaces

`FirestoreCbtService` and its callers in `cbt_screens.dart`,
`info_screens.dart`, `leaderboard_screen.dart`, `home_dashboard.dart`, and
`main_shell.dart` depend on Firestore for catalogue, subject registration,
preferences, history, and leaderboard data. Exam question selection and
answer-key storage are exclusively in `functions/src/index.ts`; clients do
not directly read the `questions` or `exam_sessions` collections under the
current Firestore rules.

Firestore collections in use include `users`, `subjects`, each user's
`registeredSubjects` and `cbt_settings/preferences`, `questions`,
`exam_sessions`, `results`, `leaderboards`, and `leaderboard_events`.
Authentication and cloud profile, result, and leaderboard functionality
should be retained during a local-data migration.

## Start-exam failure diagnosis

The local source exports `startCbtExam` and `submitCbtExam`; both it and the
mobile client target `us-central1`, and Firebase project configuration names
`nays-cbt`. The checked-in `firebase-debug.log` contains a Functions API
response with an empty function list for `nays-cbt`. A current CLI list/deploy
could not be verified because Firebase CLI credentials are expired. Therefore,
the observed `firebase_functions/not-found` is consistent with the callable
not being deployed, not with a missing function implementation or region
mismatch. Deploy and verify using [firebase_deployment.md](./firebase_deployment.md).
The callable is required by the existing server-graded online exam flow.

## Data-loss and compatibility risks

- Existing Firestore registrations and preferences must be imported or
  preserved when switching their read/write authority; silently replacing
  them with empty local tables would make learners lose visible settings.
- Firebase UIDs must remain the owner keys for local preferences, registrations,
  attempts, and results; anonymous/local records need an explicit migration
  policy before account association.
- Existing exam results and server-owned grading must remain immutable.
  Locally graded/offline results must not be trusted for leaderboard ranking
  without backend verification.
- Active server exam sessions and the encrypted recovery store use a different
  persistence format from the requested local attempt schema. Preserve
  recovery compatibility and active question snapshots during migration.
- The TSV-derived practice data currently provides a short generic explanation
  for each question. It is not an authoritative collection of verified
  JAMB/WAEC past questions; do not relabel or fabricate such sources.
- SQLite migration must preserve stable question IDs and tolerate future
  schema versions. Cross-platform support needs validation because the
  existing durable encrypted recovery is limited to Android/iOS.

## Recommended implementation sequence

1. Establish SQLite schema, versioned migrations, repository APIs and
   in-memory/FFI tests without changing current screens.
2. Define and validate a unified JSON question-bank package; import it
   transactionally and verify counts/checksums before marking it installed.
3. Add local subject and preference persistence with a one-time migration path
   from Firestore, keeping Firebase Authentication and cloud backup.
4. Integrate registered-subject and preference screens with SQLite while
   preserving existing visual design and cloud sync.
5. Add local practice and offline attempt flows with immediate answer
   persistence, snapshots, recovery, explanations, scoring, and durable local
   result history.
6. Keep online callable grading and leaderboard trust boundaries; queue
   eligible offline results for explicit server verification rather than
   trusting client-computed scores.
7. Add versioned question-bank update and sync queues, then validate
   end-to-end migration and upgrade scenarios before changing default behavior.

## Current validation baseline

- `flutter analyze`: passed after the callable error-message change.
- `flutter test`: passed, including the missing-callable regression test and
  offline recovery tests.
- `functions/npm test`: Functions TypeScript build and six tests passed.
- `npm test` from the mobile app root is not configured; run it from
  `functions/`.
- Firebase live deployment could not be performed because CLI credentials are
  expired.

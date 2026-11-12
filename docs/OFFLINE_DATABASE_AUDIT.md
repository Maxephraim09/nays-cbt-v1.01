# NAYS CBT offline database audit and migration plan

## Audit findings and current behavior

- Flutter starts Firebase in `lib/main.dart`; Firebase Authentication is owned by `lib/auth_service.dart` and remains the account authority.
- `lib/services/firestore_service.dart` owns user profiles, active subjects, registered subjects, CBT preferences, callable exam operations, cloud results, leaderboard data, app settings, and announcements.
- Firestore question reads are denied by `firestore/firestore.rules`. `functions/src/index.ts` uses the Admin SDK for question selection, checks subject registration, creates a server session, and grades submissions in a transaction. This is the existing trusted path for leaderboard-eligible results.
- `lib/screens/cbt_screens.dart` now supports local subject selection, offline practice, local examination simulations, answer review, and local result/history display. When a usable local bank is unavailable, the existing callable exam path remains as a compatibility fallback. Server-graded sessions expose review answers only after submission and retain trusted leaderboard processing.
- `lib/services/offline_exam_store.dart` already encrypts active attempts and queued submissions with AES-GCM; its per-user keys are held in secure storage. It was stored in its own SQLite schema. This table is retained and upgraded in place by the central schema so saved attempts are not discarded.
- CBT preferences and subject registration are stored locally for the active Firebase UID and queued for eligible Firestore synchronization. Cloud subject catalog and Firestore remain in place for cloud backup/compatibility; old cloud registrations/preferences are not bulk-copied into SQLite yet.
- `seed_data/subjects.json` describes Primary/JSS/SSS subjects. `seed_data/exam_questions.json` contains 457 SSS questions over nine subjects, built from `seed_data/exam_bank.tsv` by `scripts/build_exam_bank.py`. The builder rotates labels for difficulty and emits a template explanation rather than a detailed derivation. Other seed files include generated template content. These files are not bundled Flutter assets. They are not imported as a production question bank because their quality does not satisfy the detailed-explanation requirement.
- Baseline validation before changes: `flutter test` passed (24 tests); `flutter analyze` passed with no issues. Current validation is recorded below.

## Data-loss and compatibility risks

- The existing offline database is encrypted and contains attempts keyed by Firebase UID and session ID. Its filename and table are preserved; the current schema is version 6 and upgrades the legacy database without dropping that recovery table.
- Existing remote registrations, preferences, attempts, and results are not migrated or deleted by the new local database. A cloud-to-local migration/sync policy is still required before replacing cloud-driven screens.
- Local question IDs must remain stable. Updates upsert by ID and replace options transactionally; removed questions are retained so answer history and snapshots remain referentially valid.
- Local exam outcomes must not be written directly to leaderboard collections. Continue using the callable server validation path for leaderboard-eligible attempts.

## Implemented foundation

- A shared SQLite schema now contains subjects, questions/options, student preferences and registrations, examination attempts/answers/results, question-bank metadata, a retryable sync queue, active examination snapshots/progress, topic performance, and the existing encrypted offline-attempt table.
- The database enables foreign keys, adds lookup indexes and uniqueness constraints, and upgrades legacy schema version 1 without dropping the existing recovery table.
- The JSON importer validates package manifest, subject references, unique question IDs/options, correct-answer references, explanation/source/status fields, and expected counts before writing. It calculates a SHA-256 package checksum and applies subject/question/option/metadata changes in one transaction. Invalid packages fail before any database mutation.
- The app opens the shared database at startup. A bundled-bank seeder reads the manifest and subject/question files under `assets/database/question_bank/`, reports file progress to a callback, and invokes the importer. An identical verified version/checksum is not re-imported. No question-bank assets are currently bundled or declared in `pubspec.yaml`, so this startup hook is intentionally a no-op until a reviewed package is supplied.
- Offline attempts save question snapshots and answers locally, support recovery, and submit results transactionally/idempotently. Practice and post-submit review can show the corresponding stored explanations; active simulations do not reveal answers.
- Pending preference, registration, and offline-result records can be synchronized to Firestore. Unverified offline results are stored in the user's private `offlineResults` subcollection and cannot write to leaderboard collections. Sync is currently triggered from CBT screen lifecycle flows rather than a continuously monitored connectivity worker.
- Tests cover schema/import, stable-ID updates, difficulty retrieval, unique registrations, local preferences, invalid answer rejection, offline attempt recovery/submission, and existing authentication/navigation/UI behavior.

## JSON package format

Place package files under `assets/database/question_bank/`:

```text
manifest.json
subjects.json
questions/mathematics.json
questions/english.json
```

`manifest.json` contains a non-empty `version`, integer `total_questions`, and `question_files` array of paths. `subjects.json` is a list of `{id, name, description?, icon?, is_active?}` records. Each question file is a list of records with `id`, `subject_id`, `topic`, `difficulty`, `question_type`, `question` (or `question_text`), `options` (`id`/`key` and `text`), `correct_answer`, `explanation`, positive `marks`, `source`, and `verification_status`. A single-answer multiple-choice item must identify exactly one existing option. Optional fields include `subtopic`, `year`, image references, and `created_at`.

The importer is reusable and does not silently manufacture missing question content. The startup seeder is implemented, but production asset packaging and actual initial seeding remain gated on a reviewed question package. Optional image references and formatted mathematical text can be stored in JSON; image asset inclusion and rendering still need validation with real approved content.

## Remaining work and migration plan

1. Provide reviewed JSON content with detailed explanations and stable IDs; verify correct answers and explicit original/verified provenance. Do not use the generated TSV bank as production content.
2. Package approved JSON assets and image files, declare them in `pubspec.yaml`, and run a clean-install first-launch seed/count verification.
3. Decide and implement a non-destructive cloud-to-local restoration policy for a student's pre-existing preferences/registrations, then verify registration synchronization and conflicts on multiple devices.
4. Add continuous connectivity-triggered synchronization with bounded retry/backoff and explicit user-visible sync failures/status; currently sync is called from CBT lifecycle flows.
5. Add authenticated version-check/download delivery for future question-bank updates. Current imports support transactional upserts/checksums but there is no remote package download/update client.
6. Add integration/UI coverage for practice feedback, timer expiry/automatic submission, interrupted-screen recovery, offline-to-online synchronization, duplicate result retries, and a complete acceptance run against real approved content.
7. Review offline duration and grading policy against the backend's bounded offline-submission grace period. Offline results remain marked unverified and ineligible for leaderboard scoring.

## Validation and readiness

- `flutter test`: passed (32 tests).
- `flutter analyze`: passed with no issues.
- `functions` `npm test`: passed; TypeScript build and 6 exam-logic tests.
- `functions` `npm run test:rules`: passed; 6 Firestore rules tests in the emulator, including owner-only offline backups and leaderboard ineligibility.
- `flutter clean` and `flutter pub get` were not run: no Flutter dependency manifest changes were needed.
- No complete offline acceptance workflow has been run because there is no reviewed question package to install. No production question content was fabricated.

## Production readiness

The local database/importer, local practice and exam paths, cloud backup queue, and validation foundation are implemented and tested. The end-to-end migration is **not production-ready**: the packaged app has no reviewed question-bank assets, remote question-bank updates and legacy cloud-data restoration are not implemented, sync is lifecycle-triggered rather than connectivity-driven, and the full offline acceptance workflow has not been tested with production content. Firebase Authentication, cloud profiles/results, and trusted server validation for leaderboard results are preserved.

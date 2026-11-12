# Firebase deployment guidance

## Prerequisites

1. Install Firebase CLI.
2. Authenticate with `firebase login --reauth`.
3. Ensure the Firebase project is configured with the mobile app package name.
4. Confirm the Android package and signing configuration match `android/app/google-services.json`.

## Commands

```bash
Push-Location functions
npm test
Pop-Location
firebase login --reauth
firebase deploy --project nays-cbt --only functions
firebase functions:list --project nays-cbt
```

The Functions predeploy hook builds the TypeScript source before deployment.
The Functions deployment publishes `startCbtExam` and `submitCbtExam`.
Both callable functions and the Flutter client use `us-central1`. After
deployment, confirm that `firebase functions:list` includes both function
names. A `firebase_functions/not-found` error when starting an exam means the
callable endpoint is not deployed to the configured project and region; it
cannot be repaired by changing the mobile UI or retrying the same call.
`startCbtExam` requires a signed-in learner registered for an active subject;
no CBT PIN is required. It selects questions from Firestore and keeps answer
keys private in the server-only exam session. `submitCbtExam` grades answers,
saves results, and updates leaderboard aggregates.

## Seed the curriculum data

```bash
cd nays_mobile
python scripts/seed_firestore.py --dry-run --project-id nays-cbt
python scripts/seed_firestore.py --project-id nays-cbt --service-account "C:/path/to/nays-cbt-service-account.json"
```

The upload command requires a valid Firebase Admin service account JSON. You can also set the environment variable `FIREBASE_SERVICE_ACCOUNT` instead of passing `--service-account`.

To seed only the curriculum subject catalogue, which does not require the question file:

```bash
python scripts/seed_firestore.py --subjects-only --project-id nays-cbt --service-account "C:/path/to/nays-cbt-service-account.json"
```

By default, existing deterministic seed documents are skipped. Pass `--update-existing` only when intentionally refreshing them. Question data is validated before upload; placeholder question content is rejected.

## Important note

The mobile app and Functions are configured for the `nays-cbt` Firebase
project. A live Firebase Functions deployment is required before exam starts
and submissions can use the cloud backend. Firebase Functions deployment
requires the Blaze plan. If `firebase functions:list` shows no deployed
functions, reauthenticate, verify project billing and permissions, then run
the deployment command above.

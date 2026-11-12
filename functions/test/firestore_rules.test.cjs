const fs = require("node:fs");
const path = require("node:path");
const { after, before, test } = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc } = require("firebase/firestore");

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || "demo-nays-cbt",
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, "..", "..", "firestore", "firestore.rules"),
        "utf8",
      ),
    },
  });

  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await Promise.all([
      setDoc(doc(firestore, "subjects/biology"), { isActive: true }),
      setDoc(doc(firestore, "questions/question-1"), { answer: "A" }),
      setDoc(doc(firestore, "leaderboards/overall/entries/alice"), {
        userId: "alice",
      }),
    ]);
  });
});

after(async () => {
  await testEnvironment?.cleanup();
});

test("users can read and write only their own safe profile fields", async () => {
  const alice = testEnvironment.authenticatedContext("alice").firestore();
  const bob = testEnvironment.authenticatedContext("bob").firestore();
  const profile = doc(alice, "users/alice");

  await assertSucceeds(
    setDoc(profile, {
      fullName: "Alice",
      email: "alice@example.test",
      role: "student",
    }),
  );
  await assertSucceeds(
    setDoc(profile, { fullName: "Alice Example" }, { merge: true }),
  );
  await assertFails(getDoc(doc(bob, "users/alice")));
  await assertFails(
    setDoc(doc(bob, "users/alice"), { fullName: "Impersonated" }),
  );
  await assertFails(
    setDoc(profile, { role: "admin" }, { merge: true }),
  );
  await assertFails(
    setDoc(profile, { pin: "1234" }, { merge: true }),
  );
  await assertFails(
    setDoc(doc(alice, "users/with-pin"), {
      fullName: "Alice",
      pinHash: "secret",
    }),
  );
});

test("only leaderboard documents are publicly readable to signed-in users", async () => {
  const alice = testEnvironment.authenticatedContext("alice").firestore();
  const anonymous = testEnvironment.unauthenticatedContext().firestore();

  await assertSucceeds(
    getDoc(doc(alice, "leaderboards/overall/entries/alice")),
  );
  await assertFails(
    setDoc(doc(alice, "leaderboards/overall/entries/alice"), {
      userId: "alice",
      averagePercentage: 100,
    }),
  );
  await assertFails(
    getDoc(doc(anonymous, "leaderboards/overall/entries/alice")),
  );
});

test("question banks, exam data, and user sync collections are not client-accessible", async () => {
  const alice = testEnvironment.authenticatedContext("alice").firestore();
  const forbiddenPaths = [
    "subjects/biology",
    "questions/question-1",
    "examinations/exam-1",
    "exam_sessions/session-1",
    "examination_attempts/attempt-1",
    "results/result-1",
    "app_settings/app_settings",
    "topics/algebra",
    "announcements/notice-1",
    "users/alice/registeredSubjects/biology",
    "users/alice/cbt_settings/preferences",
    "users/alice/offlineResults/attempt-1",
    "cbt_pin_credentials/alice",
    "cbt_pin_rate_limits/alice",
  ];

  for (const path of forbiddenPaths) {
    await assertFails(getDoc(doc(alice, path)));
    await assertFails(setDoc(doc(alice, path), { value: "client-write" }));
  }
});

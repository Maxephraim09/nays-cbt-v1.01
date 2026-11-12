import { randomUUID } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import {
  DocumentData,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  gradeAnswers,
  MAX_QUESTIONS_PER_EXAM,
  MIN_QUESTIONS_PER_EXAM,
  pick,
  shuffled,
  submissionStatus,
  toOptions,
} from "./exam_logic";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const sessions = db.collection("exam_sessions");
const results = db.collection("results");
const callableRegion = "us-central1";

function requireUid(auth: { uid: string } | undefined): string {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in to continue.");
  return auth.uid;
}

function requireText(value: unknown, label: string): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > 200) {
    throw new HttpsError("invalid-argument", `${label} is required.`);
  }
  return value.trim();
}

interface PublicQuestion {
  questionId: string;
  questionText: string;
  questionType: string;
  options: Array<{ key: string; text: string }>;
  marks: number;
  topic: string;
  difficulty: string;
  image: string | null;
}

export const startCbtExam = onCall({ region: callableRegion }, async (request) => {
  const uid = requireUid(request.auth);
  const token = request.auth?.token;
  const profile: DocumentData = {
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (typeof token?.name === "string") profile.fullName = token.name;
  if (typeof token?.email === "string") profile.email = token.email;
  if (typeof token?.phone_number === "string") profile.phone = token.phone_number;
  if (typeof token?.picture === "string") profile.profileImage = token.picture;
  await db.collection("users").doc(uid).set(profile, { merge: true });
  const subjectId = requireText(request.data.subjectId, "Subject");
  const registration = await db
    .collection("users")
    .doc(uid)
    .collection("registeredSubjects")
    .doc(subjectId)
    .get();
  if (!registration.exists) {
    throw new HttpsError("permission-denied", "You are not registered for this subject.");
  }
  const subjectSnapshot = await db.collection("subjects").doc(subjectId).get();
  const subject = subjectSnapshot.data();
  if (!subjectSnapshot.exists || subject?.isActive !== true) {
    throw new HttpsError("failed-precondition", "This subject is not available.");
  }

  const settingsSnapshot = await db
    .collection("users")
    .doc(uid)
    .collection("cbt_settings")
    .doc("preferences")
    .get();
  const settings = settingsSnapshot.data() ?? {};
  const requestedCount = Number(settings.questionsPerExam ?? 20);
  if (
    !Number.isInteger(requestedCount) ||
    requestedCount < MIN_QUESTIONS_PER_EXAM ||
    requestedCount > MAX_QUESTIONS_PER_EXAM
  ) {
    throw new HttpsError(
      "invalid-argument",
      `Question count must be between ${MIN_QUESTIONS_PER_EXAM} and ${MAX_QUESTIONS_PER_EXAM}.`,
    );
  }
  const questionSnapshot = await db
    .collection("questions")
    .where("subjectId", "==", subjectId)
    .where("isActive", "==", true)
    .where("status", "==", "published")
    .get();
  let eligible = questionSnapshot.docs
    .map((document) => ({ id: document.id, data: document.data() }))
    .filter(({ data }) =>
      ["multiple_choice", "multiple_select", "true_false"].includes(
        String(data.questionType ?? "multiple_choice"),
      ) || ["fill_blank", "short_answer"].includes(String(data.questionType)),
    );
  const difficulty = String(settings.difficulty ?? "Mixed").toLowerCase();
  if (!["easy", "medium", "hard", "mixed"].includes(difficulty)) {
    throw new HttpsError("failed-precondition", "Your saved difficulty setting is invalid.");
  }
  if (difficulty !== "mixed") {
    const preferred = eligible.filter(
      ({ data }) => String(data.difficulty ?? "").toLowerCase() === difficulty,
    );
    if (preferred.length > 0) eligible = preferred;
  }
  if (eligible.length === 0) {
    throw new HttpsError("failed-precondition", "No approved exam questions are available.");
  }

  const selected = pick(eligible, requestedCount);
  if (settings.shuffleQuestions === false) {
    selected.sort((left, right) => left.id.localeCompare(right.id));
  }
  const shuffleOptions = settings.shuffleAnswers !== false;
  const questionDetails: Array<{
    questionId: string;
    correctAnswers: string[];
    acceptedAnswers: string[];
    questionType: string;
    marks: number;
    caseSensitive: boolean;
  }> = [];
  const publicQuestions: PublicQuestion[] = selected.map(({ id, data }) => {
    const questionType = String(data.questionType ?? "multiple_choice");
    const options = toOptions(data.options);
    const optionKeys = options.map((option) => option.key);
    const marks = Number(data.marks ?? 1);
    const questionText = String(data.questionText ?? "").trim();
    const optionQuestion = [
      "multiple_choice",
      "multiple_select",
      "true_false",
    ].includes(questionType);
    if (!Number.isFinite(marks) || marks <= 0 || questionText.length === 0) {
      throw new HttpsError("failed-precondition", `Question ${id} has invalid data.`);
    }
    if (
      optionQuestion &&
      (options.length < 2 || new Set(optionKeys).size !== optionKeys.length)
    ) {
      throw new HttpsError("failed-precondition", `Question ${id} has invalid answer options.`);
    }
    const orderedOptions = shuffleOptions ? shuffled(options) : options;
    const correctAnswers = Array.isArray(data.correctAnswers)
      ? data.correctAnswers.map(String)
      : [];
    const acceptedAnswers = Array.isArray(data.acceptedAnswers)
      ? data.acceptedAnswers
        .filter((answer): answer is string => typeof answer === "string")
        .map((answer) => answer.trim())
        .filter(Boolean)
      : [];
    if (optionQuestion) {
      if (
        correctAnswers.length === 0 ||
        new Set(correctAnswers).size !== correctAnswers.length ||
        correctAnswers.some((answer: string) => !optionKeys.includes(answer))
      ) {
        throw new HttpsError("failed-precondition", `Question ${id} has an invalid answer key.`);
      }
    } else if (acceptedAnswers.length === 0) {
      throw new HttpsError("failed-precondition", `Question ${id} has no accepted answers.`);
    }
    questionDetails.push({
      questionId: id,
      correctAnswers,
      acceptedAnswers,
      questionType,
      marks: Number(data.marks ?? 1),
      caseSensitive: data.caseSensitive === true,
    });
    return {
      questionId: id,
      questionText,
      questionType,
      options: orderedOptions,
      marks,
      topic: String(data.topic ?? ""),
      difficulty: String(data.difficulty ?? ""),
      image: typeof data.image === "string" ? data.image : null,
    };
  });

  const sessionId = randomUUID();
  const startedAt = Timestamp.now();
  const durationMinutes = Number(settings.durationMinutes ?? 60);
  if (!Number.isInteger(durationMinutes) || durationMinutes < 15 || durationMinutes > 120) {
    throw new HttpsError("failed-precondition", "Your saved examination duration is invalid.");
  }
  await sessions.doc(sessionId).create({
    userId: uid,
    subjectId,
    subjectName: String(subject.subjectName ?? subject.name ?? "Subject"),
    status: "in_progress",
    startedAt,
    expiresAt: Timestamp.fromMillis(startedAt.toMillis() + durationMinutes * 60_000),
    questionDetails,
    createdAt: FieldValue.serverTimestamp(),
  });
  return {
    sessionId,
    subjectId,
    subjectName: String(subject.subjectName ?? subject.name ?? "Subject"),
    startedAt: startedAt.toMillis(),
    durationMinutes,
    showExplanations: settings.showExplanations !== false,
    questions: publicQuestions,
  };
});

export const submitCbtExam = onCall({ region: callableRegion }, async (request) => {
  const uid = requireUid(request.auth);
  const sessionId = requireText(request.data.sessionId, "Exam session");
  const answers = request.data.answers;
  if (typeof answers !== "object" || answers === null || Array.isArray(answers)) {
    throw new HttpsError("invalid-argument", "Answers must be an object keyed by question ID.");
  }
  const answerMap = answers as Record<string, unknown>;
  const offlineSubmission = request.data.offlineSubmission === true;
  const sessionRef = sessions.doc(sessionId);
  const resultRef = results.doc(sessionId);

  return db.runTransaction(async (transaction) => {
    const sessionSnapshot = await transaction.get(sessionRef);
    const resultSnapshot = await transaction.get(resultRef);
    if (!sessionSnapshot.exists) {
      throw new HttpsError("not-found", "Exam session was not found.");
    }
    const session = sessionSnapshot.data()!;
    if (session.userId !== uid) {
      throw new HttpsError("permission-denied", "This exam session belongs to another user.");
    }
    if (session.status !== "in_progress") {
      if (!resultSnapshot.exists) {
        throw new HttpsError("already-exists", "This exam has already been submitted.");
      }
      const savedResult = resultSnapshot.data()!;
      return {
        ...savedResult,
        startedAt: (savedResult.startedAt as Timestamp).toMillis(),
        submittedAt: (savedResult.submittedAt as Timestamp).toMillis(),
      };
    }
    const now = Date.now();
    const status = submissionStatus(
      now,
      (session.expiresAt as Timestamp).toMillis(),
      offlineSubmission,
    );
    if (status === null) {
      throw new HttpsError("deadline-exceeded", "The exam session has expired.");
    }
    const details = session.questionDetails as Array<{
      questionId: string;
      correctAnswers: string[];
      acceptedAnswers: string[];
      questionType: string;
      marks: number;
      caseSensitive: boolean;
    }>;
    const questionIds = new Set(details.map((question) => question.questionId));
    if (Object.keys(answerMap).some((questionId) => !questionIds.has(questionId))) {
      throw new HttpsError("invalid-argument", "Answers contain a question outside this exam.");
    }
    const grade = gradeAnswers(details, answerMap);
    const reviewSnapshots = await transaction.getAll(
      ...details.map((question) =>
        db.collection("questions").doc(question.questionId),
      ),
    );
    const questionReview = reviewSnapshots.map((questionSnapshot) => {
      const question = questionSnapshot.data() ?? {};
      const questionDetails = details.find(
        (detail) => detail.questionId === questionSnapshot.id,
      );
      const correctAnswers = questionDetails?.correctAnswers ?? [];
      const acceptedAnswers = questionDetails?.acceptedAnswers ?? [];
      return {
        questionId: questionSnapshot.id,
        correctAnswer:
          correctAnswers.length === 1
            ? correctAnswers[0]
            : correctAnswers.length > 1
              ? correctAnswers
              : acceptedAnswers,
        explanation: String(question.explanation ?? ""),
      };
    });
    const submittedAt = Timestamp.fromMillis(now);
    const result = {
      userId: uid,
      sessionId,
      subjectId: session.subjectId,
      subjectName: session.subjectName,
      questionIds: details.map((question) => question.questionId),
      ...grade,
      questionCount: details.length,
      questionReview,
      answers: answerMap,
      startedAt: session.startedAt,
      submittedAt,
      timeSpent: Math.min(
        Number(session.durationMinutes) * 60,
        Math.max(0, Math.floor(
          (submittedAt.toMillis() - (session.startedAt as Timestamp).toMillis()) / 1000,
        )),
      ),
      status,
    };
    transaction.create(resultRef, result);
    transaction.update(sessionRef, {
      status: "submitted",
      submittedAt,
      resultId: resultRef.id,
    });
    return {
      ...result,
      startedAt: (session.startedAt as Timestamp).toMillis(),
      submittedAt: submittedAt.toMillis(),
    };
  });
});

async function addResultToLeaderboard(
  resultId: string,
  result: DocumentData,
): Promise<void> {
  const userId = String(result.userId ?? "");
  const subjectId = String(result.subjectId ?? "");
  if (!userId || !subjectId) {
    logger.error("Skipping leaderboard update for result with missing identity.", {
      resultId,
    });
    return;
  }
  const profileSnapshot = await db.collection("users").doc(userId).get();
  const profile = profileSnapshot.data() ?? {};
  const displayName =
    String(profile.fullName ?? "") ||
    [profile.firstName, profile.lastName].filter(Boolean).join(" ") ||
    "NAYS learner";
  const avatarUrl = String(profile.profileImage ?? profile.photoURL ?? "");
  const eventRef = db.collection("leaderboard_events").doc(resultId);
  const boardRefs = [
    db.collection("leaderboards").doc("overall").collection("entries").doc(userId),
    db.collection("leaderboards").doc(subjectId).collection("entries").doc(userId),
  ];
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(eventRef)).exists) return;
    const currentEntries = await Promise.all(boardRefs.map((ref) => transaction.get(ref)));
    const percentage = Number(result.percentage ?? 0);
    for (let index = 0; index < boardRefs.length; index += 1) {
      const previous = currentEntries[index].data() ?? {};
      const totalExams = Number(previous.totalExams ?? 0) + 1;
      const percentageSum = Number(previous.percentageSum ?? 0) + percentage;
      transaction.set(
        boardRefs[index],
        {
          userId,
          displayName,
          avatarUrl,
          totalExams,
          percentageSum,
          averagePercentage: percentageSum / totalExams,
          latestSubmittedAt: result.submittedAt,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    transaction.create(eventRef, {
      resultId,
      processedAt: FieldValue.serverTimestamp(),
    });
  });
}

export const updateLeaderboardForResult = onDocumentCreated(
  "results/{resultId}",
  async (event) => {
    const result = event.data?.data() as DocumentData | undefined;
    if (result?.status === "completed") {
      await addResultToLeaderboard(event.params.resultId, result);
    }
  },
);

export const updateLeaderboardForVerifiedOfflineResult = onDocumentUpdated(
  "results/{resultId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data() as DocumentData | undefined;
    if (
      before?.status === "pending_verification" &&
      after?.status === "completed"
    ) {
      await addResultToLeaderboard(event.params.resultId, after);
    }
  },
);

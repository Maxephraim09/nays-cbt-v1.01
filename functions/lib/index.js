"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.updateLeaderboardForVerifiedOfflineResult = exports.updateLeaderboardForResult = exports.submitCbtExam = exports.startCbtExam = void 0;
const node_crypto_1 = require("node:crypto");
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const firebase_functions_1 = require("firebase-functions");
const firestore_2 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const exam_logic_1 = require("./exam_logic");
if ((0, app_1.getApps)().length === 0)
    (0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
const sessions = db.collection("exam_sessions");
const results = db.collection("results");
const callableRegion = "us-central1";
function requireUid(auth) {
    if (!auth?.uid)
        throw new https_1.HttpsError("unauthenticated", "Sign in to continue.");
    return auth.uid;
}
function requireText(value, label) {
    if (typeof value !== "string" || value.trim().length === 0 || value.length > 200) {
        throw new https_1.HttpsError("invalid-argument", `${label} is required.`);
    }
    return value.trim();
}
exports.startCbtExam = (0, https_1.onCall)({ region: callableRegion }, async (request) => {
    const uid = requireUid(request.auth);
    const token = request.auth?.token;
    const profile = {
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
    if (typeof token?.name === "string")
        profile.fullName = token.name;
    if (typeof token?.email === "string")
        profile.email = token.email;
    if (typeof token?.phone_number === "string")
        profile.phone = token.phone_number;
    if (typeof token?.picture === "string")
        profile.profileImage = token.picture;
    await db.collection("users").doc(uid).set(profile, { merge: true });
    const subjectId = requireText(request.data.subjectId, "Subject");
    const registration = await db
        .collection("users")
        .doc(uid)
        .collection("registeredSubjects")
        .doc(subjectId)
        .get();
    if (!registration.exists) {
        throw new https_1.HttpsError("permission-denied", "You are not registered for this subject.");
    }
    const subjectSnapshot = await db.collection("subjects").doc(subjectId).get();
    const subject = subjectSnapshot.data();
    if (!subjectSnapshot.exists || subject?.isActive !== true) {
        throw new https_1.HttpsError("failed-precondition", "This subject is not available.");
    }
    const settingsSnapshot = await db
        .collection("users")
        .doc(uid)
        .collection("cbt_settings")
        .doc("preferences")
        .get();
    const settings = settingsSnapshot.data() ?? {};
    const requestedCount = Number(settings.questionsPerExam ?? 20);
    if (!Number.isInteger(requestedCount) ||
        requestedCount < exam_logic_1.MIN_QUESTIONS_PER_EXAM ||
        requestedCount > exam_logic_1.MAX_QUESTIONS_PER_EXAM) {
        throw new https_1.HttpsError("invalid-argument", `Question count must be between ${exam_logic_1.MIN_QUESTIONS_PER_EXAM} and ${exam_logic_1.MAX_QUESTIONS_PER_EXAM}.`);
    }
    const questionSnapshot = await db
        .collection("questions")
        .where("subjectId", "==", subjectId)
        .where("isActive", "==", true)
        .where("status", "==", "published")
        .get();
    let eligible = questionSnapshot.docs
        .map((document) => ({ id: document.id, data: document.data() }))
        .filter(({ data }) => ["multiple_choice", "multiple_select", "true_false"].includes(String(data.questionType ?? "multiple_choice")) || ["fill_blank", "short_answer"].includes(String(data.questionType)));
    const difficulty = String(settings.difficulty ?? "Mixed").toLowerCase();
    if (!["easy", "medium", "hard", "mixed"].includes(difficulty)) {
        throw new https_1.HttpsError("failed-precondition", "Your saved difficulty setting is invalid.");
    }
    if (difficulty !== "mixed") {
        const preferred = eligible.filter(({ data }) => String(data.difficulty ?? "").toLowerCase() === difficulty);
        if (preferred.length > 0)
            eligible = preferred;
    }
    if (eligible.length === 0) {
        throw new https_1.HttpsError("failed-precondition", "No approved exam questions are available.");
    }
    const selected = (0, exam_logic_1.pick)(eligible, requestedCount);
    if (settings.shuffleQuestions === false) {
        selected.sort((left, right) => left.id.localeCompare(right.id));
    }
    const shuffleOptions = settings.shuffleAnswers !== false;
    const questionDetails = [];
    const publicQuestions = selected.map(({ id, data }) => {
        const questionType = String(data.questionType ?? "multiple_choice");
        const options = (0, exam_logic_1.toOptions)(data.options);
        const optionKeys = options.map((option) => option.key);
        const marks = Number(data.marks ?? 1);
        const questionText = String(data.questionText ?? "").trim();
        const optionQuestion = [
            "multiple_choice",
            "multiple_select",
            "true_false",
        ].includes(questionType);
        if (!Number.isFinite(marks) || marks <= 0 || questionText.length === 0) {
            throw new https_1.HttpsError("failed-precondition", `Question ${id} has invalid data.`);
        }
        if (optionQuestion &&
            (options.length < 2 || new Set(optionKeys).size !== optionKeys.length)) {
            throw new https_1.HttpsError("failed-precondition", `Question ${id} has invalid answer options.`);
        }
        const orderedOptions = shuffleOptions ? (0, exam_logic_1.shuffled)(options) : options;
        const correctAnswers = Array.isArray(data.correctAnswers)
            ? data.correctAnswers.map(String)
            : [];
        const acceptedAnswers = Array.isArray(data.acceptedAnswers)
            ? data.acceptedAnswers
                .filter((answer) => typeof answer === "string")
                .map((answer) => answer.trim())
                .filter(Boolean)
            : [];
        if (optionQuestion) {
            if (correctAnswers.length === 0 ||
                new Set(correctAnswers).size !== correctAnswers.length ||
                correctAnswers.some((answer) => !optionKeys.includes(answer))) {
                throw new https_1.HttpsError("failed-precondition", `Question ${id} has an invalid answer key.`);
            }
        }
        else if (acceptedAnswers.length === 0) {
            throw new https_1.HttpsError("failed-precondition", `Question ${id} has no accepted answers.`);
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
    const sessionId = (0, node_crypto_1.randomUUID)();
    const startedAt = firestore_1.Timestamp.now();
    const durationMinutes = Number(settings.durationMinutes ?? 60);
    if (!Number.isInteger(durationMinutes) || durationMinutes < 15 || durationMinutes > 120) {
        throw new https_1.HttpsError("failed-precondition", "Your saved examination duration is invalid.");
    }
    await sessions.doc(sessionId).create({
        userId: uid,
        subjectId,
        subjectName: String(subject.subjectName ?? subject.name ?? "Subject"),
        status: "in_progress",
        startedAt,
        expiresAt: firestore_1.Timestamp.fromMillis(startedAt.toMillis() + durationMinutes * 60_000),
        questionDetails,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
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
exports.submitCbtExam = (0, https_1.onCall)({ region: callableRegion }, async (request) => {
    const uid = requireUid(request.auth);
    const sessionId = requireText(request.data.sessionId, "Exam session");
    const answers = request.data.answers;
    if (typeof answers !== "object" || answers === null || Array.isArray(answers)) {
        throw new https_1.HttpsError("invalid-argument", "Answers must be an object keyed by question ID.");
    }
    const answerMap = answers;
    const offlineSubmission = request.data.offlineSubmission === true;
    const sessionRef = sessions.doc(sessionId);
    const resultRef = results.doc(sessionId);
    return db.runTransaction(async (transaction) => {
        const sessionSnapshot = await transaction.get(sessionRef);
        const resultSnapshot = await transaction.get(resultRef);
        if (!sessionSnapshot.exists) {
            throw new https_1.HttpsError("not-found", "Exam session was not found.");
        }
        const session = sessionSnapshot.data();
        if (session.userId !== uid) {
            throw new https_1.HttpsError("permission-denied", "This exam session belongs to another user.");
        }
        if (session.status !== "in_progress") {
            if (!resultSnapshot.exists) {
                throw new https_1.HttpsError("already-exists", "This exam has already been submitted.");
            }
            const savedResult = resultSnapshot.data();
            return {
                ...savedResult,
                startedAt: savedResult.startedAt.toMillis(),
                submittedAt: savedResult.submittedAt.toMillis(),
            };
        }
        const now = Date.now();
        const status = (0, exam_logic_1.submissionStatus)(now, session.expiresAt.toMillis(), offlineSubmission);
        if (status === null) {
            throw new https_1.HttpsError("deadline-exceeded", "The exam session has expired.");
        }
        const details = session.questionDetails;
        const questionIds = new Set(details.map((question) => question.questionId));
        if (Object.keys(answerMap).some((questionId) => !questionIds.has(questionId))) {
            throw new https_1.HttpsError("invalid-argument", "Answers contain a question outside this exam.");
        }
        const grade = (0, exam_logic_1.gradeAnswers)(details, answerMap);
        const reviewSnapshots = await transaction.getAll(...details.map((question) => db.collection("questions").doc(question.questionId)));
        const questionReview = reviewSnapshots.map((questionSnapshot) => {
            const question = questionSnapshot.data() ?? {};
            const questionDetails = details.find((detail) => detail.questionId === questionSnapshot.id);
            const correctAnswers = questionDetails?.correctAnswers ?? [];
            const acceptedAnswers = questionDetails?.acceptedAnswers ?? [];
            return {
                questionId: questionSnapshot.id,
                correctAnswer: correctAnswers.length === 1
                    ? correctAnswers[0]
                    : correctAnswers.length > 1
                        ? correctAnswers
                        : acceptedAnswers,
                explanation: String(question.explanation ?? ""),
            };
        });
        const submittedAt = firestore_1.Timestamp.fromMillis(now);
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
            timeSpent: Math.min(Number(session.durationMinutes) * 60, Math.max(0, Math.floor((submittedAt.toMillis() - session.startedAt.toMillis()) / 1000))),
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
            startedAt: session.startedAt.toMillis(),
            submittedAt: submittedAt.toMillis(),
        };
    });
});
async function addResultToLeaderboard(resultId, result) {
    const userId = String(result.userId ?? "");
    const subjectId = String(result.subjectId ?? "");
    if (!userId || !subjectId) {
        firebase_functions_1.logger.error("Skipping leaderboard update for result with missing identity.", {
            resultId,
        });
        return;
    }
    const profileSnapshot = await db.collection("users").doc(userId).get();
    const profile = profileSnapshot.data() ?? {};
    const displayName = String(profile.fullName ?? "") ||
        [profile.firstName, profile.lastName].filter(Boolean).join(" ") ||
        "NAYS learner";
    const avatarUrl = String(profile.profileImage ?? profile.photoURL ?? "");
    const eventRef = db.collection("leaderboard_events").doc(resultId);
    const boardRefs = [
        db.collection("leaderboards").doc("overall").collection("entries").doc(userId),
        db.collection("leaderboards").doc(subjectId).collection("entries").doc(userId),
    ];
    await db.runTransaction(async (transaction) => {
        if ((await transaction.get(eventRef)).exists)
            return;
        const currentEntries = await Promise.all(boardRefs.map((ref) => transaction.get(ref)));
        const percentage = Number(result.percentage ?? 0);
        for (let index = 0; index < boardRefs.length; index += 1) {
            const previous = currentEntries[index].data() ?? {};
            const totalExams = Number(previous.totalExams ?? 0) + 1;
            const percentageSum = Number(previous.percentageSum ?? 0) + percentage;
            transaction.set(boardRefs[index], {
                userId,
                displayName,
                avatarUrl,
                totalExams,
                percentageSum,
                averagePercentage: percentageSum / totalExams,
                latestSubmittedAt: result.submittedAt,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        transaction.create(eventRef, {
            resultId,
            processedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    });
}
exports.updateLeaderboardForResult = (0, firestore_2.onDocumentCreated)("results/{resultId}", async (event) => {
    const result = event.data?.data();
    if (result?.status === "completed") {
        await addResultToLeaderboard(event.params.resultId, result);
    }
});
exports.updateLeaderboardForVerifiedOfflineResult = (0, firestore_2.onDocumentUpdated)("results/{resultId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (before?.status === "pending_verification" &&
        after?.status === "completed") {
        await addResultToLeaderboard(event.params.resultId, after);
    }
});
//# sourceMappingURL=index.js.map
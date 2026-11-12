"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MAX_QUESTIONS_PER_EXAM = exports.MIN_QUESTIONS_PER_EXAM = exports.OFFLINE_SUBMISSION_GRACE_MS = void 0;
exports.submissionStatus = submissionStatus;
exports.shuffled = shuffled;
exports.toOptions = toOptions;
exports.pick = pick;
exports.answerIsCorrect = answerIsCorrect;
exports.gradeAnswers = gradeAnswers;
const node_crypto_1 = require("node:crypto");
exports.OFFLINE_SUBMISSION_GRACE_MS = 24 * 60 * 60 * 1000;
exports.MIN_QUESTIONS_PER_EXAM = 5;
exports.MAX_QUESTIONS_PER_EXAM = 30;
function submissionStatus(now, expiresAt, offlineSubmission) {
    if (now <= expiresAt) {
        return offlineSubmission ? "pending_verification" : "completed";
    }
    if (!offlineSubmission || now - expiresAt > exports.OFFLINE_SUBMISSION_GRACE_MS) {
        return null;
    }
    return "pending_verification";
}
function shuffled(items) {
    const values = [...items];
    for (let index = values.length - 1; index > 0; index -= 1) {
        const target = (0, node_crypto_1.randomInt)(index + 1);
        [values[index], values[target]] = [values[target], values[index]];
    }
    return values;
}
function toOptions(value) {
    if (!Array.isArray(value))
        return [];
    return value
        .filter((option) => typeof option === "object" &&
        option !== null &&
        typeof option.key === "string" &&
        typeof option.text === "string")
        .map(({ key, text }) => ({ key, text }));
}
function pick(items, count) {
    const pool = [...items];
    const selected = [];
    const size = Math.min(count, pool.length);
    for (let index = 0; index < size; index += 1) {
        const target = (0, node_crypto_1.randomInt)(pool.length);
        selected.push(pool[target]);
        pool.splice(target, 1);
    }
    return selected;
}
function answerIsCorrect(question, answer, caseSensitive) {
    if (question.questionType === "multiple_select") {
        if (!Array.isArray(answer))
            return false;
        return [...answer].map(String).sort().join("\u0000") ===
            [...question.correctAnswers].sort().join("\u0000");
    }
    if (question.questionType === "multiple_choice" ||
        question.questionType === "true_false") {
        return typeof answer === "string" &&
            question.correctAnswers.length === 1 &&
            answer === question.correctAnswers[0];
    }
    if (typeof answer !== "string")
        return false;
    const candidate = caseSensitive ? answer.trim() : answer.trim().toLowerCase();
    return question.acceptedAnswers.some((accepted) => candidate === (caseSensitive ? accepted.trim() : accepted.trim().toLowerCase()));
}
function gradeAnswers(questions, answers) {
    let score = 0;
    let correctAnswers = 0;
    const isAnswered = (answer) => {
        if (answer === null || answer === undefined)
            return false;
        if (typeof answer === "string")
            return answer.trim().length > 0;
        if (Array.isArray(answer))
            return answer.length > 0;
        return true;
    };
    const answeredQuestionCount = questions.filter((question) => isAnswered(answers[question.questionId])).length;
    const totalMarks = questions.reduce((sum, question) => sum + question.marks, 0);
    for (const question of questions) {
        if (Object.hasOwn(answers, question.questionId) &&
            answerIsCorrect(question, answers[question.questionId], question.caseSensitive)) {
            correctAnswers += 1;
            score += question.marks;
        }
    }
    return {
        score,
        totalMarks,
        percentage: totalMarks === 0 ? 0 : (score / totalMarks) * 100,
        correctAnswers,
        incorrectAnswers: answeredQuestionCount - correctAnswers,
        unanswered: questions.length - answeredQuestionCount,
    };
}
//# sourceMappingURL=exam_logic.js.map
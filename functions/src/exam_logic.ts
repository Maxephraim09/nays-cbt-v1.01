import { randomInt } from "node:crypto";

export const OFFLINE_SUBMISSION_GRACE_MS = 24 * 60 * 60 * 1000;
export const MIN_QUESTIONS_PER_EXAM = 5;
export const MAX_QUESTIONS_PER_EXAM = 30;

export interface AnswerKey {
  questionId: string;
  correctAnswers: string[];
  acceptedAnswers: string[];
  questionType: string;
  marks: number;
  caseSensitive: boolean;
}

export function submissionStatus(
  now: number,
  expiresAt: number,
  offlineSubmission: boolean,
): "completed" | "pending_verification" | null {
  if (now <= expiresAt) {
    return offlineSubmission ? "pending_verification" : "completed";
  }
  if (!offlineSubmission || now - expiresAt > OFFLINE_SUBMISSION_GRACE_MS) {
    return null;
  }
  return "pending_verification";
}

export function shuffled<T>(items: T[]): T[] {
  const values = [...items];
  for (let index = values.length - 1; index > 0; index -= 1) {
    const target = randomInt(index + 1);
    [values[index], values[target]] = [values[target], values[index]];
  }
  return values;
}

export function toOptions(value: unknown): Array<{ key: string; text: string }> {
  if (!Array.isArray(value)) return [];
  return value
    .filter(
      (option): option is { key: string; text: string } =>
        typeof option === "object" &&
        option !== null &&
        typeof (option as { key?: unknown }).key === "string" &&
        typeof (option as { text?: unknown }).text === "string",
    )
    .map(({ key, text }) => ({ key, text }));
}

export function pick<T>(items: T[], count: number): T[] {
  const pool = [...items];
  const selected: T[] = [];
  const size = Math.min(count, pool.length);
  for (let index = 0; index < size; index += 1) {
    const target = randomInt(pool.length);
    selected.push(pool[target]);
    pool.splice(target, 1);
  }
  return selected;
}

export function answerIsCorrect(
  question: Pick<AnswerKey, "correctAnswers" | "acceptedAnswers" | "questionType">,
  answer: unknown,
  caseSensitive: boolean,
): boolean {
  if (question.questionType === "multiple_select") {
    if (!Array.isArray(answer)) return false;
    return [...answer].map(String).sort().join("\u0000") ===
      [...question.correctAnswers].sort().join("\u0000");
  }
  if (
    question.questionType === "multiple_choice" ||
    question.questionType === "true_false"
  ) {
    return typeof answer === "string" &&
      question.correctAnswers.length === 1 &&
      answer === question.correctAnswers[0];
  }
  if (typeof answer !== "string") return false;
  const candidate = caseSensitive ? answer.trim() : answer.trim().toLowerCase();
  return question.acceptedAnswers.some((accepted) =>
    candidate === (caseSensitive ? accepted.trim() : accepted.trim().toLowerCase()),
  );
}

export function gradeAnswers(
  questions: AnswerKey[],
  answers: Record<string, unknown>,
): {
  score: number;
  totalMarks: number;
  percentage: number;
  correctAnswers: number;
  incorrectAnswers: number;
  unanswered: number;
} {
  let score = 0;
  let correctAnswers = 0;
  const isAnswered = (answer: unknown): boolean => {
    if (answer === null || answer === undefined) return false;
    if (typeof answer === "string") return answer.trim().length > 0;
    if (Array.isArray(answer)) return answer.length > 0;
    return true;
  };
  const answeredQuestionCount = questions.filter((question) =>
    isAnswered(answers[question.questionId]),
  ).length;
  const totalMarks = questions.reduce((sum, question) => sum + question.marks, 0);
  for (const question of questions) {
    if (
      Object.hasOwn(answers, question.questionId) &&
      answerIsCorrect(question, answers[question.questionId], question.caseSensitive)
    ) {
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

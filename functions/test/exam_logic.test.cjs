const assert = require("node:assert/strict");
const { test } = require("node:test");
const {
  answerIsCorrect,
  gradeAnswers,
  MAX_QUESTIONS_PER_EXAM,
  MIN_QUESTIONS_PER_EXAM,
  OFFLINE_SUBMISSION_GRACE_MS,
  pick,
  shuffled,
  submissionStatus,
  toOptions,
} =
  require("../lib/exam_logic.js");

test("question selection is unique and never exceeds the available bank", () => {
  const selected = pick(["q1", "q2", "q3"], 20);
  assert.equal(selected.length, 3);
  assert.equal(new Set(selected).size, 3);
});

test("exam question count limits match the client settings range", () => {
  assert.equal(MIN_QUESTIONS_PER_EXAM, 5);
  assert.equal(MAX_QUESTIONS_PER_EXAM, 30);
});

test("option shuffling preserves all options", () => {
  assert.deepEqual(shuffled(["A", "B", "C"]).sort(), ["A", "B", "C"]);
});

test("question options reject malformed entries", () => {
  assert.deepEqual(
    toOptions([{ key: "A", text: "Alpha" }, { key: 1, text: "Invalid" }, null]),
    [{ key: "A", text: "Alpha" }],
  );
});

test("answer grading respects answer types and counts unanswered questions", () => {
  const questions = [
    {
      questionId: "choice",
      correctAnswers: ["A"],
      acceptedAnswers: [],
      questionType: "multiple_choice",
      marks: 2,
      caseSensitive: false,
    },
    {
      questionId: "select",
      correctAnswers: ["B", "C"],
      acceptedAnswers: [],
      questionType: "multiple_select",
      marks: 1,
      caseSensitive: false,
    },
    {
      questionId: "text",
      correctAnswers: [],
      acceptedAnswers: ["Photosynthesis"],
      questionType: "short_answer",
      marks: 1,
      caseSensitive: false,
    },
  ];

  assert.equal(answerIsCorrect(questions[1], ["C", "B"], false), true);
  assert.equal(answerIsCorrect(questions[2], " photosynthesis ", false), true);
  assert.equal(answerIsCorrect(questions[2], "photosynthesis", true), false);
  assert.deepEqual(gradeAnswers(questions, {
    choice: "A",
    select: ["B", "C"],
  }), {
    score: 3,
    totalMarks: 4,
    percentage: 75,
    correctAnswers: 2,
    incorrectAnswers: 0,
    unanswered: 1,
  });

});

test("blank strings and empty selections remain unanswered", () => {
  const questions = [
    {
      questionId: "choice",
      correctAnswers: ["A"],
      acceptedAnswers: [],
      questionType: "multiple_choice",
      marks: 1,
      caseSensitive: false,
    },
    {
      questionId: "select",
      correctAnswers: ["B", "C"],
      acceptedAnswers: [],
      questionType: "multiple_select",
      marks: 1,
      caseSensitive: false,
    },
    {
      questionId: "text",
      correctAnswers: [],
      acceptedAnswers: ["Photosynthesis"],
      questionType: "short_answer",
      marks: 1,
      caseSensitive: false,
    },
  ];

  assert.deepEqual(gradeAnswers(questions, {
    choice: "  ",
    select: [],
    text: "not correct",
  }), {
    score: 0,
    totalMarks: 3,
    percentage: 0,
    correctAnswers: 0,
    incorrectAnswers: 1,
    unanswered: 2,
  });
});

test("offline submissions are pending, bounded to a 24-hour grace period, and online sessions still expire", () => {
  const expiresAt = 10_000;
  assert.equal(submissionStatus(expiresAt, expiresAt, false), "completed");
  assert.equal(submissionStatus(expiresAt, expiresAt, true), "pending_verification");
  assert.equal(submissionStatus(expiresAt + 1, expiresAt, false), null);
  assert.equal(
    submissionStatus(expiresAt + OFFLINE_SUBMISSION_GRACE_MS, expiresAt, true),
    "pending_verification",
  );
  assert.equal(
    submissionStatus(expiresAt + OFFLINE_SUBMISSION_GRACE_MS + 1, expiresAt, true),
    null,
  );
});

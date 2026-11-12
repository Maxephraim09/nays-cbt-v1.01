const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const questionDir = path.join(root, 'assets/database/question_bank/questions');
const sourcePath = path.join(root, 'seed_data/exam_bank.tsv');
const additionsPath = path.join(root, 'seed_data/mobile_question_additions.tsv');
const reportPath = path.join(root, 'seed_data/question_bank_validation_report.json');

const subjects = [
  ['english_language', 'English Language', 'ENG', 'Arts'],
  ['mathematics', 'Mathematics', 'MTH', 'Science'],
  ['biology', 'Biology', 'BIO', 'Science'],
  ['chemistry', 'Chemistry', 'CHE', 'Science'],
  ['physics', 'Physics', 'PHY', 'Science'],
  ['agricultural_science', 'Agricultural Science', 'AGR', 'Science'],
  ['economics', 'Economics', 'ECO', 'Commercial'],
  ['government', 'Government', 'GOV', 'Arts'],
  ['literature_in_english', 'Literature in English', 'LIT', 'Arts'],
  ['geography', 'Geography', 'GEO', 'Science'],
];
const idByName = new Map(subjects.map(([id, name]) => [name, id]));
const labels = new Map(subjects.map(([id, name]) => [id, name]));
const originalBankSubjects = new Set(['chemistry', 'economics', 'geography', 'mathematics']);
const questionFiles = new Map();
const acceptedCounts = Object.fromEntries(subjects.map(([id]) => [id, 0]));
const rejected = [];
const editorialReview = [];

function readTsv(file) {
  return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/).filter(Boolean)
    .map((line, index) => ({ columns: line.split('\t'), line: index + 1 }));
}

function normalizeText(text) {
  return text.normalize('NFKC').toLocaleLowerCase('en')
    .replace(/[^\p{L}\p{N}]+/gu, ' ').trim().replace(/\s+/g, ' ');
}

function normalizeOption(text) {
  return text.normalize('NFKC').trim().replace(/\s+/g, ' ');
}

function hasDuplicateQuestionText(question) {
  const normalized = normalizeText(question);
  return [...questionFiles.values()].some((items) =>
    items.some((item) => normalizeText(item.question) === normalized));
}

function difficulty(value) {
  const result = value?.trim();
  return ['Easy', 'Medium', 'Hard'].includes(result) ? result : null;
}

for (const [subjectName, subjectId] of idByName) {
  const existingPath = path.join(questionDir, `${subjectId}.json`);
  if (originalBankSubjects.has(subjectId) && fs.existsSync(existingPath)) {
    const existing = JSON.parse(fs.readFileSync(existingPath, 'utf8')).map((item) => ({
      ...item,
      explanation: item.explanation ?? item.reasoning,
    }));
    questionFiles.set(subjectId, existing);
    acceptedCounts[subjectId] = existing.length;
  } else {
    questionFiles.set(subjectId, []);
  }
}

const sources = readTsv(sourcePath);
const sourceCountNeeded = {
  english_language: 55,
  biology: 50,
  physics: 55,
  government: 60,
  literature_in_english: 50,
};
const sourceAdded = Object.fromEntries(Object.keys(sourceCountNeeded).map((id) => [id, 0]));

for (const row of sources) {
  const [name, topic, question, answer, ...distractors] = row.columns;
  const subjectId = idByName.get(name);
  if (!subjectId || !sourceCountNeeded[subjectId] || sourceAdded[subjectId] >= sourceCountNeeded[subjectId]) {
    continue;
  }
  if (row.columns.length !== 7 || ![topic, question, answer, ...distractors].every((v) => v?.trim())) {
    rejected.push({ source: 'exam_bank.tsv', line: row.line, reason: 'invalid legacy TSV fields' });
    continue;
  }
  if (hasDuplicateQuestionText(question)) {
    rejected.push({ source: 'exam_bank.tsv', line: row.line, reason: 'duplicate normalized question text' });
    continue;
  }

  const [a, b, c, d] = [answer, ...distractors];
  const topicText = topic.trim();
  const item = {
    id: `${subjects.find(([id]) => id === subjectId)[2]}_SRC_${String(sourceAdded[subjectId] + 1).padStart(3, '0')}`,
    subject_id: subjectId,
    topic: topicText,
    subtopic: topicText,
    year: null,
    difficulty: 'Medium',
    question_type: 'multiple_choice',
    question: question.trim(),
    options: { A: a.trim(), B: b.trim(), C: c.trim(), D: d.trim() },
    correct_answer: 'A',
    explanation: `The expected answer is "${a.trim()}". It is the answer identified by the source record for the ${topicText} concept tested in this question.`,
    marks: 1,
    source: 'Legacy exam_bank.tsv; answer and explanation require editorial confirmation',
    verification_status: 'editorial_review_required',
  };
  questionFiles.get(subjectId).push(item);
  acceptedCounts[subjectId]++;
  sourceAdded[subjectId]++;
  editorialReview.push(item.id);
}

const additionRows = readTsv(additionsPath);
const targetAdditional = {
  english_language: 48,
  biology: 50,
  physics: 50,
  government: 50,
  literature_in_english: 50,
  agricultural_science: 100,
};
const additionsAccepted = Object.fromEntries(Object.keys(targetAdditional).map((id) => [id, 0]));

for (const row of additionRows) {
  const [name, topic, question, a, b, c, d, explanation, subtopic, level] = row.columns;
  const subjectId = idByName.get(name);
  if (!subjectId || !targetAdditional[subjectId]) continue;
  const remaining = targetAdditional[subjectId] - additionsAccepted[subjectId];
  if (remaining <= 0) {
    rejected.push({ source: 'mobile_question_additions.tsv', line: row.line, reason: 'subject target already met' });
    continue;
  }
  const parsedDifficulty = difficulty(level);
  if (row.columns.length !== 10 || ![topic, question, a, b, c, d, explanation, subtopic].every((v) => v?.trim()) ||
      !parsedDifficulty || new Set([a, b, c, d].map((v) => normalizeOption(v))).size !== 4) {
    rejected.push({ source: 'mobile_question_additions.tsv', line: row.line, reason: 'invalid question fields, difficulty, or options' });
    console.error(`Rejected additions row ${row.line}: invalid fields, difficulty, or duplicate options.`);
    continue;
  }
  if (hasDuplicateQuestionText(question)) {
    rejected.push({ source: 'mobile_question_additions.tsv', line: row.line, reason: 'duplicate normalized question text' });
    continue;
  }

  const prefix = subjects.find(([id]) => id === subjectId)[2];
  const item = {
    id: `${prefix}_ADD_${String(additionsAccepted[subjectId] + 1).padStart(3, '0')}`,
    subject_id: subjectId,
    topic: topic.trim(),
    subtopic: subtopic.trim(),
    year: null,
    difficulty: parsedDifficulty,
    question_type: 'multiple_choice',
    question: question.trim(),
    options: { A: a.trim(), B: b.trim(), C: c.trim(), D: d.trim() },
    correct_answer: 'A',
    explanation: explanation.trim(),
    marks: 1,
    source: 'Original practice; generated content requires qualified editorial review',
    verification_status: 'editorial_review_required',
  };
  questionFiles.get(subjectId).push(item);
  acceptedCounts[subjectId]++;
  additionsAccepted[subjectId]++;
  editorialReview.push(item.id);
}

for (const [subjectId, expected] of Object.entries({
  english_language: 100,
  mathematics: 100,
  biology: 100,
  chemistry: 100,
  physics: 100,
  agricultural_science: 100,
  economics: 100,
  government: 100,
  literature_in_english: 100,
  geography: 100,
})) {
  const items = questionFiles.get(subjectId);
  if (!items || items.length !== expected) {
    throw new Error(`${labels.get(subjectId)}: expected ${expected} questions, found ${items?.length ?? 0}`);
  }
}

const seenIds = new Set();
const seenTexts = new Map();
for (const [subjectId, items] of questionFiles) {
  for (const item of items) {
    if (seenIds.has(item.id)) throw new Error(`Duplicate question ID: ${item.id}`);
    seenIds.add(item.id);
    const normalized = normalizeText(item.question);
    if (seenTexts.has(normalized)) {
      throw new Error(`Duplicate question text: ${seenTexts.get(normalized)} and ${item.id}`);
    }
    seenTexts.set(normalized, item.id);
    if (item.subject_id !== subjectId || !['Easy', 'Medium', 'Hard'].includes(item.difficulty) ||
        !['A', 'B', 'C', 'D'].includes(item.correct_answer) || !item.explanation.trim() ||
        Object.keys(item.options).sort().join(',') !== 'A,B,C,D' ||
        Object.values(item.options).some((value) => !value?.trim()) ||
        new Set(Object.values(item.options).map(normalizeOption)).size !== 4 ||
        !item.id || !item.topic?.trim() || !item.subtopic?.trim() ||
        item.verification_status !== 'editorial_review_required') {
      throw new Error(`Invalid question fields: ${item.id}; options=${JSON.stringify(item.options)}`);
    }
  }
}

for (const [subjectId, items] of questionFiles) {
  fs.writeFileSync(path.join(questionDir, `${subjectId}.json`), `${JSON.stringify(items, null, 2)}\n`);
}

const subjectJson = subjects.map(([id, name, code, category]) => ({
  id,
  name,
  subject_code: code,
  category,
  education_level: 'SSS',
  description: `Original ${name} practice questions for Nigerian secondary-school learners.`,
  is_active: true,
}));
fs.writeFileSync(path.join(root, 'assets/database/question_bank/subjects.json'), `${JSON.stringify(subjectJson, null, 2)}\n`);

const files = subjects.map(([id]) => `questions/${id}.json`);
fs.writeFileSync(path.join(root, 'assets/database/question_bank/manifest.json'), `${JSON.stringify({
  version: '2.0.0',
  total_questions: 1000,
  question_files: files,
}, null, 2)}\n`);

const report = {
  generated_at: new Date().toISOString(),
  subjects: Object.fromEntries(subjects.map(([id, name]) => [name, {
    accepted: acceptedCounts[id],
    required: 100,
    editorial_review_required: questionFiles.get(id).filter((q) => q.verification_status === 'editorial_review_required').length,
  }])),
  accepted: seenIds.size,
  rejected: rejected.length,
  rejected_records: rejected,
  duplicate_ids: 0,
  duplicate_normalized_question_text: 0,
  editorial_review_required: [...questionFiles.values()]
    .reduce((count, items) => count + items.filter((q) =>
      q.verification_status === 'editorial_review_required').length, 0),
  editorially_reviewed: 0,
};
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(`Built ${seenIds.size} questions across ${questionFiles.size} subjects.`);
console.log(`Rejected source rows: ${rejected.length}; editorial review required: ${editorialReview.length}.`);

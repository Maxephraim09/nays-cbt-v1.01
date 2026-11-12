const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const bankRoot = path.join(root, 'assets/database/question_bank');
const reportPath = path.join(root, 'seed_data/question_bank_validation_report.json');
const expectedSubjects = [
  'english_language',
  'mathematics',
  'biology',
  'chemistry',
  'physics',
  'agricultural_science',
  'economics',
  'government',
  'literature_in_english',
  'geography',
];
const errors = [];
const report = {
  subjects: {},
  accepted: 0,
  rejected: 0,
  duplicate_ids: 0,
  duplicate_normalized_question_text: 0,
  editorial_review_required: 0,
  editorially_reviewed: 0,
  validation_errors: errors,
};

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    errors.push(`${path.relative(root, file)}: ${error.message}`);
    return null;
  }
}

function normalizeText(text) {
  return text.normalize('NFKC').toLocaleLowerCase('en')
    .replace(/[^\p{L}\p{N}]+/gu, ' ').trim().replace(/\s+/g, ' ');
}

const manifest = readJson(path.join(bankRoot, 'manifest.json'));
const subjects = readJson(path.join(bankRoot, 'subjects.json'));
if (!manifest || manifest.version !== '2.0.0' || manifest.total_questions !== 1000 ||
    !Array.isArray(manifest.question_files)) {
  errors.push('Manifest must declare version 2.0.0, 1000 questions, and a question_files array.');
}
if (!Array.isArray(subjects) || subjects.length !== 10 ||
    new Set(subjects.map((subject) => subject?.id)).size !== 10 ||
    expectedSubjects.some((id) => !subjects.some((subject) => subject?.id === id))) {
  errors.push('subjects.json must contain exactly the ten required unique subject IDs.');
}

const expectedFiles = expectedSubjects.map((id) => `questions/${id}.json`);
if (!manifest || manifest.question_files.length !== expectedFiles.length ||
    expectedFiles.some((file) => !manifest.question_files.includes(file))) {
  errors.push('Manifest question_files must reference exactly the ten packaged subject files.');
}

const ids = new Set();
const texts = new Set();
for (const subjectId of expectedSubjects) {
  const file = path.join(bankRoot, 'questions', `${subjectId}.json`);
  const questions = readJson(file);
  if (!Array.isArray(questions)) {
    report.subjects[subjectId] = { accepted: 0, rejected: 0, required: 100 };
    continue;
  }
  let accepted = 0;
  let rejected = 0;
  for (const [index, question] of questions.entries()) {
    const errorsForQuestion = [];
    if (!question || typeof question !== 'object' || Array.isArray(question)) {
      errorsForQuestion.push('question must be an object');
    } else {
      const optionKeys = question.options && typeof question.options === 'object'
        ? Object.keys(question.options).sort()
        : [];
      if (!question.id || typeof question.id !== 'string') errorsForQuestion.push('missing question ID');
      if (question.subject_id !== subjectId) errorsForQuestion.push('invalid subject reference');
      if (!question.question?.trim()) errorsForQuestion.push('empty question text');
      if (!question.topic?.trim() || !question.subtopic?.trim()) errorsForQuestion.push('missing topic classification');
      if (!['Easy', 'Medium', 'Hard'].includes(question.difficulty)) errorsForQuestion.push('invalid difficulty');
      if (optionKeys.join(',') !== 'A,B,C,D' ||
          Object.values(question.options ?? {}).some((option) => typeof option !== 'string' || !option.trim())) {
        errorsForQuestion.push('exactly four non-empty A-D options are required');
      }
      if (!['A', 'B', 'C', 'D'].includes(question.correct_answer)) errorsForQuestion.push('invalid correct-answer reference');
      if (!question.explanation?.trim()) errorsForQuestion.push('missing explanation');
      if (question.verification_status !== 'editorial_review_required') {
        errorsForQuestion.push('unreviewed bank records must remain editorial_review_required');
      }
      if (question.id && ids.has(question.id)) {
        report.duplicate_ids++;
        errorsForQuestion.push(`duplicate ID ${question.id}`);
      }
      if (question.id) ids.add(question.id);
      if (question.question?.trim()) {
        const normalized = normalizeText(question.question);
        if (texts.has(normalized)) {
          report.duplicate_normalized_question_text++;
          errorsForQuestion.push('duplicate normalized question text');
        }
        texts.add(normalized);
      }
      if (question.verification_status === 'editorial_review_required') report.editorial_review_required++;
      if (question.verification_status === 'verified') report.editorially_reviewed++;
    }

    if (errorsForQuestion.length) {
      rejected++;
      errors.push(`${subjectId}[${index}]: ${errorsForQuestion.join('; ')}`);
    } else {
      accepted++;
    }
  }
  if (questions.length !== 100) {
    errors.push(`${subjectId}: expected 100 questions, found ${questions.length}`);
  }
  report.subjects[subjectId] = { accepted, rejected, required: 100, packaged: questions.length };
}

report.accepted = Object.values(report.subjects).reduce((sum, item) => sum + item.accepted, 0);
report.rejected = Object.values(report.subjects).reduce((sum, item) => sum + item.rejected, 0);
report.total_packaged = Object.values(report.subjects).reduce((sum, item) => sum + item.packaged, 0);
if (report.total_packaged !== 1000 || report.accepted !== 1000 || report.rejected !== 0 ||
    report.editorial_review_required !== 1000 || report.editorially_reviewed !== 0) {
  errors.push('Bank totals or editorial-review status do not match acceptance requirements.');
}
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);

if (errors.length) {
  console.error(`Question bank validation failed with ${errors.length} issue(s). Report: ${reportPath}`);
  process.exitCode = 1;
} else {
  console.log('Question bank validation passed: 10 subjects, 1,000 questions, 0 rejected, 1,000 require editorial review.');
}

#!/usr/bin/env python3
"""Generate and optionally upload a Nigerian CBT seed dataset to Firestore.

This script is intentionally structured as a safe administrative process for a
Firebase project with proper service-account access. It creates a deterministic
curriculum dataset for the app and can dry-run locally without interacting
with production data.
"""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
from typing import Any

PRIMARY_SUBJECTS = [
    "Mathematics",
    "English Language",
    "Basic Science",
    "Basic Technology",
    "Social Studies",
    "Civic Education",
    "Computer Studies / ICT",
    "Agricultural Science",
    "Home Economics",
    "Physical and Health Education",
    "Christian Religious Studies",
    "Islamic Religious Studies",
    "Security Education",
    "Cultural and Creative Arts",
    "Nigerian History",
    "French Language",
]

JSS_SUBJECTS = [
    "Mathematics",
    "English Studies",
    "Basic Science",
    "Basic Technology",
    "Business Studies",
    "Computer Studies",
    "Civic Education",
    "Social Studies",
    "Agricultural Science",
    "Home Economics",
    "Physical and Health Education",
    "Basic Financial Education",
    "Christian Religious Studies",
    "Islamic Studies",
    "Nigerian Languages",
    "French",
    "Security Education",
    "Cultural and Creative Arts",
]

SSS_SUBJECTS = [
    "Mathematics",
    "English Language",
    "Biology",
    "Chemistry",
    "Physics",
    "Further Mathematics",
    "Agricultural Science",
    "Economics",
    "Government",
    "Commerce",
    "Accounting",
    "Geography",
    "Literature in English",
    "Civic Education",
    "Computer Studies",
    "Data Processing",
    "Technical Drawing",
    "Food and Nutrition",
    "Christian Religious Studies",
    "Islamic Studies",
    "History",
    "Financial Accounting",
    "Insurance",
    "Marketing",
    "Animal Husbandry",
    "Fisheries",
    "Yoruba",
    "Hausa",
    "Igbo",
    "French Language",
]

EXAM_BANK_SUBJECTS = (
    "Mathematics",
    "English Language",
    "Biology",
    "Physics",
    "Chemistry",
    "Government",
    "Geography",
    "Economics",
    "Literature in English",
)

TOPICS = {
    "Mathematics": ["Number and Numeration", "Algebra", "Geometry", "Measurement", "Statistics"],
    "English Language": ["Grammar", "Comprehension", "Vocabulary", "Spelling", "Writing"],
    "Basic Science": ["Living Things", "Matter", "Energy", "Earth Science", "Health"],
    "Basic Technology": ["Tools and Machines", "Drawing", "Materials", "Safety", "Electrical Systems"],
    "Social Studies": ["Culture", "Leadership", "Environment", "Citizenship", "Governance"],
    "Civic Education": ["Rights", "Duties", "Democracy", "Law", "National Identity"],
    "Computer Studies / ICT": ["Hardware", "Software", "Internet", "Safety", "Programming Logic"],
    "Agricultural Science": ["Crop Production", "Animal Husbandry", "Soil", "Farm Tools", "Agribusiness"],
    "Home Economics": ["Nutrition", "Family Life", "Household Management", "Textiles", "Cooking"],
    "Physical and Health Education": ["Fitness", "Nutrition", "Safety", "Games", "Hygiene"],
    "Christian Religious Studies": ["Faith", "Morality", "Service", "Prayer", "History"],
    "Islamic Religious Studies": ["Faith", "Akhlaq", "Islamic History", "Prayer", "Ethics"],
    "Security Education": ["Safety", "Emergency Response", "Cyber Safety", "Road Safety", "Community Security"],
    "Cultural and Creative Arts": ["Art", "Music", "Drama", "Craft", "Culture"],
    "Nigerian History": ["Colonial Rule", "Independence", "Culture", "Leadership", "National Development"],
    "French Language": ["Vocabulary", "Grammar", "Conversation", "Culture", "Comprehension"],
    "English Studies": ["Grammar", "Comprehension", "Vocabulary", "Speech", "Writing"],
    "Business Studies": ["Office Skills", "Commerce", "Trade", "Finance", "Enterprise"],
    "Computer Studies": ["Hardware", "Software", "ICT safety", "Keyboarding", "Applications"],
    "Basic Financial Education": ["Savings", "Budgeting", "Banking", "Money", "Needs and Wants"],
    "Islamic Studies": ["Belief", "Prayer", "Ethics", "History", "Society"],
    "Nigerian Languages": ["Grammar", "Speech", "Culture", "Vocabulary", "Communication"],
    "Biology": ["Cells", "Genetics", "Ecology", "Human body", "Plant structure"],
    "Chemistry": ["Atomic structure", "Bonding", "Acids and bases", "Matter", "Stoichiometry"],
    "Physics": ["Motion", "Electricity", "Light", "Forces", "Energy"],
    "Further Mathematics": ["Sequence", "Trigonometry", "Calculus", "Probability", "Matrices"],
    "Economics": ["Demand", "Supply", "Production", "Trade", "Budget"],
    "Government": ["Constitution", "Politics", "Citizenship", "Leadership", "Public policy"],
    "Commerce": ["Trade", "Business law", "Marketing", "Finance", "Operations"],
    "Accounting": ["Bookkeeping", "Ledger", "Cash flow", "Trial balance", "Accounts"],
    "Geography": ["Map reading", "Climate", "Rocks", "Population", "Natural resources"],
    "Literature in English": ["Poetry", "Drama", "Prose", "Figure of speech", "Themes"],
    "Data Processing": ["Data capture", "Storage", "Software tools", "Spreadsheet", "Data handling"],
    "Technical Drawing": ["Orthographic projection", "Geometry", "Sketching", "Dimensioning", "Blueprints"],
    "Food and Nutrition": ["Diet", "Hygiene", "Meal planning", "Food safety", "Vitamins"],
    "History": ["Ancient civilisation", "Colonial era", "Independence", "Migration", "Leadership"],
    "Financial Accounting": ["Ledger", "Income statement", "Balance sheet", "Cash flow", "Journal"],
    "Insurance": ["Risk", "Policy", "Premium", "Claims", "Insurance law"],
    "Marketing": ["Branding", "Promotion", "Consumer behavior", "Pricing", "Sales"],
    "Animal Husbandry": ["Breeding", "Feeds", "Housing", "Health", "Production"],
    "Fisheries": ["Aquaculture", "Fish farming", "Water quality", "Feeds", "Storage"],
    "Yoruba": ["Vocabulary", "Grammar", "Culture", "Conversation", "Writing"],
    "Hausa": ["Vocabulary", "Grammar", "Culture", "Conversation", "Writing"],
    "Igbo": ["Vocabulary", "Grammar", "Culture", "Conversation", "Writing"],
    "French Language": ["Vocabulary", "Grammar", "Conversation", "Culture", "Comprehension"],
}


def slugify(value: str) -> str:
    return ''.join(ch.lower() if ch.isalnum() else '-' for ch in value).strip('-')


def build_subjects() -> list[dict[str, Any]]:
    subjects: list[dict[str, Any]] = []
    for education_level, entries in {
        'Primary': PRIMARY_SUBJECTS,
        'JSS': JSS_SUBJECTS,
        'SSS': SSS_SUBJECTS,
    }.items():
        for subject in entries:
            subjects.append({
                'subjectId': slugify(f'{subject}-{education_level}'),
                'subjectCode': f'{education_level[:2].upper()}-{slugify(subject)[:5]}',
                'subjectName': subject,
                'description': f'{subject} study content for {education_level} learners.',
                'category': education_level,
                'educationLevel': education_level,
                'isActive': True,
                'totalQuestions': 0,
            })
    return subjects


def write_subject_seed(base_dir: Path) -> Path:
    base_dir.mkdir(parents=True, exist_ok=True)
    subjects_path = base_dir / 'subjects.json'
    subjects = build_subjects()
    subjects_path.write_text(json.dumps(subjects, indent=2), encoding='utf-8')
    return subjects_path


def load_questions(
    path: Path,
    subject_ids: set[str] | None = None,
) -> list[dict[str, Any]]:
    questions = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(questions, list):
        raise SystemExit(f'Question seed must be a JSON list: {path}')
    if subject_ids is not None:
        questions = [
            question
            for question in questions
            if question.get('subjectId') in subject_ids
            and question.get('educationLevel') == 'SSS'
        ]
    for question in questions:
        raw_options = question.get('options', {})
        option_values = (
            [str(value) for value in raw_options.values()]
            if isinstance(raw_options, dict)
            else []
        )
        if any(
            value.strip().lower() == 'correct answer'
            or re.search(r'\bconcept\s+\d+\b', value.lower())
            for value in option_values
        ):
            raise SystemExit(
                f'Refusing to upload placeholder question data from {path}. '
                'Replace it with reviewed, original questions before seeding.'
            )
        if not question.get('questionId') or not question.get('subjectId'):
            raise SystemExit(f'Question is missing questionId or subjectId in {path}')
        if set(question.get('options', {})) != {'A', 'B', 'C', 'D'}:
            raise SystemExit(f'Question {question["questionId"]} must have A-D options.')
        if question.get('correctAnswer') not in {'A', 'B', 'C', 'D'}:
            raise SystemExit(f'Question {question["questionId"]} has an invalid correctAnswer.')
        if not question.get('questionText', '').strip():
            raise SystemExit(f'Question {question["questionId"]} has no question text.')
        if question.get('questionType', 'multiple_choice') != 'multiple_choice':
            raise SystemExit(f'Question {question["questionId"]} must be multiple choice.')
    if subject_ids is not None:
        counts: dict[str, int] = {}
        for question in questions:
            subject_id = question['subjectId']
            counts[subject_id] = counts.get(subject_id, 0) + 1
        if set(counts) != subject_ids or any(count < 50 for count in counts.values()):
            raise SystemExit(
                'The exam bank must contain at least 50 SSS questions for every selected subject.'
            )
    return questions


def firestore_question_payload(question: dict[str, Any]) -> dict[str, Any]:
    options = question.get('options')
    if not isinstance(options, dict):
        raise ValueError(f'Question {question.get("questionId")} has invalid options.')
    correct_answer = question.get('correctAnswer')
    if correct_answer not in {'A', 'B', 'C', 'D'}:
        raise ValueError(f'Question {question.get("questionId")} has an invalid correct answer.')

    payload = dict(question)
    payload['options'] = [
        {'key': key, 'text': str(text)}
        for key, text in options.items()
    ]
    payload['questionType'] = 'multiple_choice'
    payload['correctAnswers'] = [correct_answer]
    payload['acceptedAnswers'] = []
    payload['caseSensitive'] = False
    payload['status'] = 'published'
    payload['isActive'] = True
    payload.pop('correctAnswer', None)
    return payload


def _upload_collection(db: Any, collection: str, records: list[dict[str, Any]], update_existing: bool) -> tuple[int, int]:
    created = 0
    skipped = 0
    batch = db.batch()
    batch_size = 0
    refs: list[Any] = []

    def commit_batch() -> None:
        nonlocal batch, batch_size
        if batch_size:
            batch.commit()
            batch = db.batch()
            batch_size = 0

    for record in records:
        document_id = record.get('subjectId') if collection == 'subjects' else record.get('questionId')
        if not document_id:
            raise ValueError(f'A {collection} seed record is missing its document ID.')
        ref = db.collection(collection).document(document_id)
        if not update_existing and ref.get().exists:
            skipped += 1
            continue
        batch.set(ref, record, merge=update_existing)
        refs.append(ref)
        created += 1
        batch_size += 1
        if batch_size >= 450:
            commit_batch()

    commit_batch()
    verified = sum(1 for snapshot in db.get_all(refs) if snapshot.exists) if refs else 0
    if verified != created:
        raise RuntimeError(
            f'Verification failed for {collection}: wrote {created}, verified {verified}.'
        )
    print(
        f'{collection}: created/updated={created}, skipped-existing={skipped}, '
        f'verified={verified}'
    )
    return created, skipped


def upload_seed_data(
    subjects: list[dict[str, Any]],
    questions: list[dict[str, Any]],
    project_id: str | None,
    dry_run: bool,
    service_account_path: str | None = None,
    subjects_only: bool = False,
    update_existing: bool = False,
) -> None:
    firestore_questions = [
        firestore_question_payload(question)
        for question in questions
    ]
    if dry_run:
        print(
            f'DRY RUN: project={project_id or "default"}, subjects={len(subjects)}, '
            f'questions={0 if subjects_only else len(firestore_questions)}, '
            f'update_existing={update_existing}'
        )
        return

    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError as exc:  # pragma: no cover
        raise SystemExit(f'firebase_admin is required for live uploads: {exc}') from exc

    if project_id:
        os.environ.setdefault('GOOGLE_CLOUD_PROJECT', project_id)

    if not firebase_admin._apps:
        cred_path = service_account_path or os.environ.get('FIREBASE_SERVICE_ACCOUNT')
        if not cred_path:
            raise SystemExit(
                'Set FIREBASE_SERVICE_ACCOUNT or pass --service-account to a Firebase service-account JSON before uploading.'
            )
        cred = credentials.Certificate(cred_path)
        app = firebase_admin.initialize_app(
            cred,
            {'projectId': project_id} if project_id else None,
        )
    else:
        app = firebase_admin.get_app()

    if project_id and app.project_id != project_id:
        raise SystemExit(
            f'Credential project is {app.project_id!r}, but requested project is {project_id!r}.'
        )

    db = firestore.client()
    subject_created, subject_skipped = _upload_collection(
        db, 'subjects', subjects, update_existing
    )
    question_created = question_skipped = 0
    if not subjects_only:
        question_created, question_skipped = _upload_collection(
            db, 'questions', firestore_questions, update_existing
        )
    print(
        f'Summary: subjects-created={subject_created}, '
        f'questions-created={question_created}, '
        f'skipped-existing={subject_skipped + question_skipped}'
    )


def main() -> None:
    parser = argparse.ArgumentParser(description='Generate and optionally upload NAYS CBT seed data.')
    parser.add_argument('--output', type=Path, default=Path('seed_data'))
    parser.add_argument('--project-id', default=None, help='Optional Firebase project id for live uploads.')
    parser.add_argument('--service-account', default=None, help='Path to the Firebase service-account JSON key.')
    parser.add_argument('--dry-run', action='store_true', help='Generate the JSON files without uploading anything.')
    parser.add_argument('--subjects-only', action='store_true', help='Upload subjects only; do not read or write questions.')
    parser.add_argument('--update-existing', action='store_true', help='Update documents with deterministic seed IDs.')
    parser.add_argument(
        '--exam-bank-only',
        action='store_true',
        help='Upload only the reviewed SSS JAMB/WAEC-style bank, excluding all other seed data.',
    )
    args = parser.parse_args()

    subjects_path = write_subject_seed(args.output)
    all_subjects = json.loads(subjects_path.read_text(encoding='utf-8'))
    subjects = all_subjects
    subject_ids: set[str] | None = None
    if args.exam_bank_only:
        subjects = [
            subject
            for subject in subjects
            if subject.get('educationLevel') == 'SSS'
            and subject.get('subjectName') in EXAM_BANK_SUBJECTS
        ]
        if {subject.get('subjectName') for subject in subjects} != set(EXAM_BANK_SUBJECTS):
            raise SystemExit('Could not resolve all requested SSS subjects from the subject catalogue.')
        subject_ids = {subject['subjectId'] for subject in subjects}
        questions_path = args.output / 'exam_questions.json'
    else:
        questions_path = args.output / 'questions.json'

    questions = (
        []
        if args.subjects_only
        else load_questions(questions_path, subject_ids=subject_ids)
    )
    if questions:
        question_counts: dict[str, int] = {}
        for question in questions:
            subject_id = question['subjectId']
            question_counts[subject_id] = question_counts.get(subject_id, 0) + 1
        for subject in all_subjects:
            subject['totalQuestions'] = question_counts.get(subject['subjectId'], 0)
        subjects_path.write_text(json.dumps(all_subjects, indent=2) + '\n', encoding='utf-8')
    print(f'Subject seed: {subjects_path}')
    print(f'Subject count: {len(subjects)}')
    if not args.subjects_only:
        print(f'Question seed: {questions_path}')
        print(f'Question count: {len(questions)}')
    upload_seed_data(
        subjects,
        questions,
        args.project_id,
        args.dry_run,
        service_account_path=args.service_account,
        subjects_only=args.subjects_only,
        update_existing=args.update_existing,
    )


if __name__ == '__main__':
    main()

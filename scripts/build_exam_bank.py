#!/usr/bin/env python3
"""Build the original SSS JAMB/WAEC-style question bank from its TSV source."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


SUBJECTS = (
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
LETTERS = ("A", "B", "C", "D")
ROOT = Path(__file__).resolve().parents[1]


def slugify(value: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", value.lower())).strip("-")


def read_source(path: Path) -> list[dict[str, Any]]:
    questions: list[dict[str, Any]] = []
    counts: Counter[str] = Counter()
    seen: set[tuple[str, str]] = set()

    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) != 7:
            raise ValueError(f"{path}:{line_number}: expected 7 tab-separated fields.")
        subject, topic, text, correct, *distractors = fields
        if subject not in SUBJECTS:
            raise ValueError(f"{path}:{line_number}: unsupported subject {subject!r}.")
        if not all(value.strip() for value in fields):
            raise ValueError(f"{path}:{line_number}: question fields must not be empty.")
        if len(set([correct, *distractors])) != 4:
            raise ValueError(f"{path}:{line_number}: options must be distinct.")
        question_key = (subject, text)
        if question_key in seen:
            raise ValueError(f"{path}:{line_number}: duplicate question text.")
        seen.add(question_key)

        counts[subject] += 1
        index = counts[subject]
        choices = [correct, *distractors]
        rotation = (index - 1) % len(choices)
        choices = choices[rotation:] + choices[:rotation]
        options = dict(zip(LETTERS, choices, strict=True))
        correct_answer = next(key for key, value in options.items() if value == correct)
        questions.append({
            "questionId": f"{slugify(subject)}-sss-{index:03d}",
            "subjectId": f"{slugify(subject)}-sss",
            "subjectName": subject,
            "educationLevel": "SSS",
            "questionText": text,
            "questionType": "multiple_choice",
            "options": options,
            "correctAnswer": correct_answer,
            "correctAnswers": [correct_answer],
            "acceptedAnswers": [],
            "caseSensitive": False,
            "explanation": f"The correct answer is {correct}; this question tests {topic}.",
            "difficulty": ("easy", "medium", "hard")[(index - 1) % 3],
            "topic": topic,
            "marks": 1,
            "status": "published",
            "isActive": True,
            "source": "Original JAMB/WAEC-style practice question",
        })

    expected = set(SUBJECTS)
    if set(counts) != expected or any(counts[name] < 50 for name in SUBJECTS):
        details = ", ".join(f"{name}: {counts[name]}" for name in SUBJECTS)
        raise ValueError(f"Every requested subject must have at least 50 questions ({details}).")
    if len(questions) != sum(counts.values()):
        raise ValueError("Question count validation failed.")
    return questions


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--admin-project-dir",
        type=Path,
        default=ROOT.parent / "nays-2.0",
        help="Optional sibling Laravel project directory for its database seeder data.",
    )
    args = parser.parse_args()

    questions = read_source(ROOT / "seed_data" / "exam_bank.tsv")
    question_by_id = {question["questionId"]: question for question in questions}
    existing_path = ROOT / "seed_data" / "questions.json"
    existing = json.loads(existing_path.read_text(encoding="utf-8"))
    if not isinstance(existing, list):
        raise ValueError(f"{existing_path} must contain a JSON list.")

    merged = [
        question_by_id.get(question.get("questionId"), question)
        for question in existing
    ]
    existing_ids = {question.get("questionId") for question in existing}
    merged.extend(
        question
        for question in questions
        if question["questionId"] not in existing_ids
    )

    write_json(ROOT / "seed_data" / "exam_questions.json", questions)
    write_json(existing_path, merged)

    subjects_path = ROOT / "seed_data" / "subjects.json"
    subjects = json.loads(subjects_path.read_text(encoding="utf-8"))
    totals = Counter(question["subjectId"] for question in questions)
    for subject in subjects:
        if subject.get("educationLevel") == "SSS":
            subject["totalQuestions"] = totals.get(subject.get("subjectId"), 0)
    write_json(subjects_path, subjects)

    admin_data = args.admin_project_dir / "database" / "seeders" / "data" / "exam_questions.json"
    if args.admin_project_dir.is_dir():
        write_json(admin_data, questions)
        print(f"Admin seed data: {admin_data}")
    else:
        print(f"Admin project not found; skipped: {args.admin_project_dir}")
    print(f"Built {len(questions)} questions across {len(SUBJECTS)} subjects.")


if __name__ == "__main__":
    main()

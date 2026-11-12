class DemoQuestion {
  const DemoQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

const availableSubjects = [
  'English Language',
  'Mathematics',
  'Biology',
  'Chemistry',
  'Physics',
  'Literature in English',
  'Government',
  'Economics',
  'Commerce',
  'Geography',
  'Agricultural Science',
  'Further Mathematics',
  'Christian Religious Studies',
  'Accounting',
  'Civic Education',
];

const demoQuestions = [
  DemoQuestion(
    prompt: 'Which process do green plants use to make their food?',
    options: ['Respiration', 'Photosynthesis', 'Transpiration', 'Germination'],
    correctIndex: 1,
    explanation:
        'Photosynthesis uses light energy to convert carbon dioxide and water into glucose.',
  ),
  DemoQuestion(
    prompt: 'If 3x + 5 = 20, what is the value of x?',
    options: ['3', '5', '7', '15'],
    correctIndex: 1,
    explanation: 'Subtract 5 from both sides, then divide 15 by 3.',
  ),
  DemoQuestion(
    prompt: 'Choose the word closest in meaning to “diligent”.',
    options: ['Careless', 'Hardworking', 'Impatient', 'Uncertain'],
    correctIndex: 1,
    explanation: 'A diligent person works carefully and consistently.',
  ),
  DemoQuestion(
    prompt: 'The chemical symbol for sodium is:',
    options: ['S', 'So', 'Na', 'N'],
    correctIndex: 2,
    explanation: 'Na comes from the Latin name natrium.',
  ),
  DemoQuestion(
    prompt: 'Which organ pumps blood around the human body?',
    options: ['Lung', 'Kidney', 'Liver', 'Heart'],
    correctIndex: 3,
    explanation: 'The heart contracts rhythmically to circulate blood.',
  ),
];

const sampleHistory = [
  ('Biology', '28 Oct 2026', '76%', 'Good progress'),
  ('English Language', '24 Oct 2026', '68%', 'Practice complete'),
  ('Mathematics', '18 Oct 2026', '82%', 'Great work'),
];

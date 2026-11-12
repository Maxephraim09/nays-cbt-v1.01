import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCollections {
  static const String users = 'users';
  static const String subjects = 'subjects';
  static const String questions = 'questions';
  static const String examinations = 'examinations';
  static const String examinationAttempts = 'examination_attempts';
  static const String results = 'results';
  static const String appSettings = 'app_settings';
  static const String topics = 'topics';
  static const String announcements = 'announcements';
  static const String registeredSubjects = 'registeredSubjects';
  static const String cbtSettings = 'cbt_settings';
  static const String examSessions = 'exam_sessions';
  static const String leaderboards = 'leaderboards';
}

class NaysUserProfile {
  const NaysUserProfile({
    required this.uid,
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.profileImage = '',
    this.role = 'student',
    this.institution = '',
    this.department = '',
    this.level = '',
    this.state = '',
    this.district = '',
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String profileImage;
  final String role;
  final String institution;
  final String department;
  final String level;
  final String state;
  final String district;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NaysUserProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return NaysUserProfile(
      uid: doc.id,
      fullName: (data['fullName'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      profileImage: (data['profileImage'] ?? '') as String,
      role: (data['role'] ?? 'student') as String,
      institution: (data['institution'] ?? '') as String,
      department: (data['department'] ?? '') as String,
      level: (data['level'] ?? '') as String,
      state: (data['state'] ?? '') as String,
      district: (data['district'] ?? '') as String,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'profileImage': profileImage,
    'role': role,
    'institution': institution,
    'department': department,
    'level': level,
    'state': state,
    'district': district,
    'updatedAt': FieldValue.serverTimestamp(),
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class NaysSubject {
  const NaysSubject({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.description,
    required this.category,
    required this.educationLevel,
    required this.isActive,
    required this.totalQuestions,
    this.createdAt,
    this.updatedAt,
  });

  final String subjectId;
  final String subjectCode;
  final String subjectName;
  final String description;
  final String category;
  final String educationLevel;
  final bool isActive;
  final int totalQuestions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NaysSubject.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return NaysSubject.fromData(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory NaysSubject.fromData(String id, Map<String, dynamic> data) {
    return NaysSubject(
      subjectId: id,
      subjectCode: (data['subjectCode'] ?? '') as String,
      subjectName: (data['subjectName'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      category: (data['category'] ?? '') as String,
      educationLevel: (data['educationLevel'] ?? '') as String,
      isActive: (data['isActive'] ?? false) as bool,
      totalQuestions: (data['totalQuestions'] ?? 0) as int,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'subjectId': subjectId,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'description': description,
    'category': category,
    'educationLevel': educationLevel,
    'isActive': isActive,
    'totalQuestions': totalQuestions,
    'updatedAt': FieldValue.serverTimestamp(),
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class CbtExamOption {
  const CbtExamOption({required this.key, required this.text, this.image});

  final String key;
  final String text;
  final String? image;

  factory CbtExamOption.fromMap(Map<String, dynamic> data) => CbtExamOption(
    key: data['key'] as String,
    text: data['text'] as String,
    image: data['image'] as String?,
  );
}

class CbtExamQuestion {
  const CbtExamQuestion({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.marks,
    this.topic = '',
    this.subtopic = '',
    this.difficulty = '',
    this.subjectId = '',
    this.subjectName = '',
    this.image,
    this.correctAnswer,
    this.explanation = '',
  });

  final String questionId;
  final String questionText;
  final String questionType;
  final List<CbtExamOption> options;
  final num marks;
  final String topic;
  final String subtopic;
  final String difficulty;
  final String subjectId;
  final String subjectName;
  final String? image;
  final Object? correctAnswer;
  final String explanation;

  factory CbtExamQuestion.fromMap(Map<String, dynamic> data) {
    final rawOptions = data['options'];
    if (rawOptions is! List) {
      throw const FormatException('Exam question options are missing.');
    }
    return CbtExamQuestion(
      questionId: data['questionId'] as String,
      questionText: data['questionText'] as String,
      questionType: data['questionType'] as String,
      options: rawOptions
          .map(
            (option) =>
                CbtExamOption.fromMap(Map<String, dynamic>.from(option as Map)),
          )
          .toList(growable: false),
      marks: data['marks'] as num,
      topic: data['topic'] as String? ?? '',
      subtopic: data['subtopic'] as String? ?? '',
      difficulty: data['difficulty'] as String? ?? '',
      subjectId: data['subjectId'] as String? ?? '',
      subjectName: data['subjectName'] as String? ?? '',
      image: data['image'] as String?,
      correctAnswer: data['correctAnswer'],
      explanation: data['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'questionId': questionId,
    'questionText': questionText,
    'questionType': questionType,
    'options': options
        .map(
          (option) => {
            'key': option.key,
            'text': option.text,
            if (option.image != null) 'image': option.image,
          },
        )
        .toList(),
    'marks': marks,
    'topic': topic,
    'subtopic': subtopic,
    'difficulty': difficulty,
    if (subjectId.isNotEmpty) 'subjectId': subjectId,
    if (subjectName.isNotEmpty) 'subjectName': subjectName,
    if (image != null) 'image': image,
    if (correctAnswer != null) 'correctAnswer': correctAnswer,
    if (explanation.isNotEmpty) 'explanation': explanation,
  };
}

class CbtExamSession {
  const CbtExamSession({
    required this.sessionId,
    required this.subjectId,
    required this.subjectName,
    required this.startedAt,
    required this.durationMinutes,
    required this.questions,
    this.isOffline = false,
    this.showExplanations = true,
  });

  final String sessionId;
  final String subjectId;
  final String subjectName;
  final DateTime startedAt;
  final int durationMinutes;
  final List<CbtExamQuestion> questions;
  final bool isOffline;
  final bool showExplanations;

  factory CbtExamSession.fromMap(Map<String, dynamic> data) {
    final rawQuestions = data['questions'];
    if (rawQuestions is! List) {
      throw const FormatException('Exam session questions are missing.');
    }
    return CbtExamSession(
      sessionId: data['sessionId'] as String,
      subjectId: data['subjectId'] as String,
      subjectName: data['subjectName'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(data['startedAt'] as int),
      durationMinutes: data['durationMinutes'] as int,
      isOffline: data['isOffline'] as bool? ?? false,
      showExplanations: data['showExplanations'] as bool? ?? true,
      questions: rawQuestions
          .map(
            (question) => CbtExamQuestion.fromMap(
              Map<String, dynamic>.from(question as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'subjectId': subjectId,
    'subjectName': subjectName,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'durationMinutes': durationMinutes,
    'isOffline': isOffline,
    'showExplanations': showExplanations,
    'questions': questions.map((question) => question.toMap()).toList(),
  };
}

class NaysCbtPreferences {
  static const minimumQuestionsPerExam = 5;
  static const maximumQuestionsPerExam = 30;

  const NaysCbtPreferences({
    this.difficulty = 'Mixed',
    this.durationMinutes = 60,
    this.questionsPerExam = 20,
    this.shuffleQuestions = true,
    this.shuffleAnswers = true,
    this.showExplanations = true,
    this.negativeMarking = false,
  });

  final String difficulty;
  final int durationMinutes;
  final int questionsPerExam;
  final bool shuffleQuestions;
  final bool shuffleAnswers;
  final bool showExplanations;
  final bool negativeMarking;

  factory NaysCbtPreferences.fromMap(Map<String, dynamic> data) {
    final difficulty = data['difficulty'];
    return NaysCbtPreferences(
      difficulty:
          difficulty is String &&
              const {'Easy', 'Medium', 'Hard', 'Mixed'}.contains(difficulty)
          ? difficulty
          : 'Mixed',
      durationMinutes: _boundedInt(data['durationMinutes'], 60, 15, 120),
      questionsPerExam: _boundedInt(
        data['questionsPerExam'],
        20,
        minimumQuestionsPerExam,
        maximumQuestionsPerExam,
      ),
      shuffleQuestions: data['shuffleQuestions'] is bool
          ? data['shuffleQuestions'] as bool
          : true,
      shuffleAnswers: data['shuffleAnswers'] is bool
          ? data['shuffleAnswers'] as bool
          : true,
      showExplanations: data['showExplanations'] is bool
          ? data['showExplanations'] as bool
          : true,
      negativeMarking: data['negativeMarking'] is bool
          ? data['negativeMarking'] as bool
          : false,
    );
  }

  static int _boundedInt(
    dynamic value,
    int fallback,
    int minimum,
    int maximum,
  ) {
    if (value is! int) return fallback;
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
  }

  Map<String, dynamic> toMap() => {
    'difficulty': difficulty,
    'durationMinutes': durationMinutes,
    'questionsPerExam': questionsPerExam,
    'shuffleQuestions': shuffleQuestions,
    'shuffleAnswers': shuffleAnswers,
    'showExplanations': showExplanations,
    'negativeMarking': negativeMarking,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class NaysLeaderboardEntry {
  const NaysLeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.averagePercentage,
    required this.totalExams,
    this.avatarUrl = '',
  });

  final String userId;
  final String displayName;
  final double averagePercentage;
  final int totalExams;
  final String avatarUrl;

  factory NaysLeaderboardEntry.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return NaysLeaderboardEntry(
      userId: document.id,
      displayName: data['displayName'] as String? ?? 'NAYS learner',
      averagePercentage: (data['averagePercentage'] as num? ?? 0).toDouble(),
      totalExams: data['totalExams'] as int? ?? 0,
      avatarUrl: data['avatarUrl'] as String? ?? '',
    );
  }
}

class NaysResult {
  const NaysResult({
    required this.resultId,
    required this.userId,
    required this.examinationId,
    required this.subjectId,
    this.subjectName = '',
    required this.score,
    required this.totalMarks,
    required this.percentage,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.unanswered,
    required this.timeSpent,
    this.questionCount = 0,
    this.startedAt,
    required this.submittedAt,
    required this.status,
  });

  final String resultId;
  final String userId;
  final String examinationId;
  final String subjectId;
  final String subjectName;
  final num score;
  final num totalMarks;
  final double percentage;
  final int correctAnswers;
  final int incorrectAnswers;
  final int unanswered;
  final int timeSpent;
  final int questionCount;
  final DateTime? startedAt;
  final DateTime submittedAt;
  final String status;

  factory NaysResult.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return NaysResult(
      resultId: doc.id,
      userId: (data['userId'] ?? '') as String,
      examinationId:
          (data['examinationId'] ?? data['sessionId'] ?? '') as String,
      subjectId: (data['subjectId'] ?? '') as String,
      subjectName: (data['subjectName'] ?? '') as String,
      score: (data['score'] ?? 0) as num,
      totalMarks: (data['totalMarks'] ?? 0) as num,
      percentage: ((data['percentage'] ?? 0) as num).toDouble(),
      correctAnswers: (data['correctAnswers'] ?? 0) as int,
      incorrectAnswers: (data['incorrectAnswers'] ?? 0) as int,
      unanswered: (data['unanswered'] ?? 0) as int,
      timeSpent: (data['timeSpent'] ?? 0) as int,
      questionCount: (data['questionCount'] ?? 0) as int,
      startedAt: _readDate(data['startedAt']),
      submittedAt:
          _readDate(data['submittedAt']) ??
          (throw const FormatException(
            'Exam result submission date is missing.',
          )),
      status: (data['status'] ?? 'submitted') as String,
    );
  }

  factory NaysResult.fromLocalMap(Map<String, Object?> data) {
    final createdAt = DateTime.parse(data['created_at']! as String);
    final startedAt = DateTime.parse(data['started_at']! as String);
    return NaysResult(
      resultId: data['attempt_id']! as String,
      userId: data['user_id']! as String,
      examinationId: data['attempt_id']! as String,
      subjectId: data['subject_id']! as String,
      subjectName: data['subject_name'] as String? ?? '',
      score: data['score'] as num? ?? 0,
      totalMarks: data['total_marks'] as num? ?? 0,
      percentage: (data['percentage'] as num? ?? 0).toDouble(),
      correctAnswers: data['correct_answers'] as int? ?? 0,
      incorrectAnswers: data['wrong_answers'] as int? ?? 0,
      unanswered: data['unanswered'] as int? ?? 0,
      timeSpent: data['time_used'] as int? ?? 0,
      questionCount: data['total_questions'] as int? ?? 0,
      startedAt: startedAt,
      submittedAt: createdAt,
      status: 'completed_offline',
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class NaysAppSettings {
  const NaysAppSettings({
    this.appName = 'NAYS CBT',
    this.appLogo = '',
    this.primaryColor = '#0F3A2E',
    this.secondaryColor = '#D0B76E',
    this.maintenanceMode = false,
    this.allowRegistration = true,
    this.defaultExamDuration = 60,
    this.defaultQuestionCount = 20,
    this.enableExplanations = true,
    this.enableNegativeMarking = false,
    this.negativeMarkValue = 0,
    this.shuffleQuestions = true,
    this.shuffleAnswers = true,
    this.updatedAt,
  });

  final String appName;
  final String appLogo;
  final String primaryColor;
  final String secondaryColor;
  final bool maintenanceMode;
  final bool allowRegistration;
  final int defaultExamDuration;
  final int defaultQuestionCount;
  final bool enableExplanations;
  final bool enableNegativeMarking;
  final int negativeMarkValue;
  final bool shuffleQuestions;
  final bool shuffleAnswers;
  final DateTime? updatedAt;

  factory NaysAppSettings.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return NaysAppSettings(
      appName: (data['appName'] ?? 'NAYS CBT') as String,
      appLogo: (data['appLogo'] ?? '') as String,
      primaryColor: (data['primaryColor'] ?? '#0F3A2E') as String,
      secondaryColor: (data['secondaryColor'] ?? '#D0B76E') as String,
      maintenanceMode: (data['maintenanceMode'] ?? false) as bool,
      allowRegistration: (data['allowRegistration'] ?? true) as bool,
      defaultExamDuration: (data['defaultExamDuration'] ?? 60) as int,
      defaultQuestionCount: (data['defaultQuestionCount'] ?? 20) as int,
      enableExplanations: (data['enableExplanations'] ?? true) as bool,
      enableNegativeMarking: (data['enableNegativeMarking'] ?? false) as bool,
      negativeMarkValue: (data['negativeMarkValue'] ?? 0) as int,
      shuffleQuestions: (data['shuffleQuestions'] ?? true) as bool,
      shuffleAnswers: (data['shuffleAnswers'] ?? true) as bool,
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'appName': appName,
    'appLogo': appLogo,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'maintenanceMode': maintenanceMode,
    'allowRegistration': allowRegistration,
    'defaultExamDuration': defaultExamDuration,
    'defaultQuestionCount': defaultQuestionCount,
    'enableExplanations': enableExplanations,
    'enableNegativeMarking': enableNegativeMarking,
    'negativeMarkValue': negativeMarkValue,
    'shuffleQuestions': shuffleQuestions,
    'shuffleAnswers': shuffleAnswers,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class NaysTopic {
  const NaysTopic({
    required this.topicId,
    required this.subjectId,
    required this.topicName,
    required this.description,
    required this.isActive,
  });

  final String topicId;
  final String subjectId;
  final String topicName;
  final String description;
  final bool isActive;

  factory NaysTopic.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return NaysTopic(
      topicId: doc.id,
      subjectId: (data['subjectId'] ?? '') as String,
      topicName: (data['topicName'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      isActive: (data['isActive'] ?? true) as bool,
    );
  }
}

class NaysAnnouncement {
  const NaysAnnouncement({
    required this.announcementId,
    required this.title,
    required this.message,
    required this.image,
    required this.isActive,
    this.createdAt,
  });

  final String announcementId;
  final String title;
  final String message;
  final String image;
  final bool isActive;
  final DateTime? createdAt;

  factory NaysAnnouncement.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return NaysAnnouncement(
      announcementId: doc.id,
      title: (data['title'] ?? '') as String,
      message: (data['message'] ?? '') as String,
      image: (data['image'] ?? '') as String,
      isActive: (data['isActive'] ?? true) as bool,
      createdAt: _readDate(data['createdAt']),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// User Model
// ============================================================================
class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? role; // 'teacher' or 'student'
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.role,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: data['role'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'role': role,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  AppUser copyWith({String? role}) => AppUser(
        id: id,
        email: email,
        displayName: displayName,
        role: role ?? this.role,
        createdAt: createdAt,
      );

  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
}

// ============================================================================
// Plan Model
// ============================================================================
class Plan {
  final String id;
  final String teacherId;
  final String title;
  final String description;
  final String instrument;
  final String difficulty; // 'beginner', 'intermediate', 'advanced'
  final bool published;
  final DateTime createdAt;

  Plan({
    required this.id,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.instrument,
    required this.difficulty,
    required this.published,
    required this.createdAt,
  });

  factory Plan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Plan(
      id: doc.id,
      teacherId: data['teacherId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      instrument: data['instrument'] ?? '',
      difficulty: data['difficulty'] ?? 'beginner',
      published: data['published'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'teacherId': teacherId,
        'title': title,
        'description': description,
        'instrument': instrument,
        'difficulty': difficulty,
        'published': published,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ============================================================================
// Session Model
// ============================================================================
class Session {
  final String id;
  final String planId;
  final String title;
  final int orderIndex;
  final int estMinutes;

  Session({
    required this.id,
    required this.planId,
    required this.title,
    required this.orderIndex,
    required this.estMinutes,
  });

  factory Session.fromFirestore(DocumentSnapshot doc, String planId) {
    final data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      planId: planId,
      title: data['title'] ?? '',
      orderIndex: data['orderIndex'] ?? 0,
      estMinutes: data['estMinutes'] ?? 15,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'orderIndex': orderIndex,
        'estMinutes': estMinutes,
      };
}

// ============================================================================
// Exercise Model
// ============================================================================
class Exercise {
  final String id;
  final String sessionId;
  final String title;
  final String instructions;
  final int orderIndex;
  final int? targetBpm;
  final int? targetSeconds;
  final List<String> attachmentUrls;

  Exercise({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.instructions,
    required this.orderIndex,
    this.targetBpm,
    this.targetSeconds,
    this.attachmentUrls = const [],
  });

  factory Exercise.fromFirestore(DocumentSnapshot doc, String sessionId) {
    final data = doc.data() as Map<String, dynamic>;
    return Exercise(
      id: doc.id,
      sessionId: sessionId,
      title: data['title'] ?? '',
      instructions: data['instructions'] ?? '',
      orderIndex: data['orderIndex'] ?? 0,
      targetBpm: data['targetBpm'],
      targetSeconds: data['targetSeconds'],
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'instructions': instructions,
        'orderIndex': orderIndex,
        'targetBpm': targetBpm,
        'targetSeconds': targetSeconds,
        'attachmentUrls': attachmentUrls,
      };
}

// ============================================================================
// Assignment Model
// ============================================================================
class Assignment {
  final String id;
  final String teacherId;
  final String studentId;
  final String studentEmail;
  final String planId;
  final DateTime assignedAt;

  Assignment({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.studentEmail,
    required this.planId,
    required this.assignedAt,
  });

  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Assignment(
      id: doc.id,
      teacherId: data['teacherId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      planId: data['planId'] ?? '',
      assignedAt:
          (data['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'teacherId': teacherId,
        'studentId': studentId,
        'studentEmail': studentEmail,
        'planId': planId,
        'assignedAt': Timestamp.fromDate(assignedAt),
      };
}

// ============================================================================
// PracticeLog Model
// ============================================================================
class PracticeLog {
  final String id;
  final String studentId;
  final String teacherId; // Added for MVP query simplicity
  final String planId;
  final String sessionId;
  final String exerciseId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationSeconds;

  PracticeLog({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.planId,
    required this.sessionId,
    required this.exerciseId,
    required this.startedAt,
    this.completedAt,
    required this.durationSeconds,
  });

  factory PracticeLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PracticeLog(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      teacherId: data['teacherId'] ?? '',
      planId: data['planId'] ?? '',
      sessionId: data['sessionId'] ?? '',
      exerciseId: data['exerciseId'] ?? '',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      durationSeconds: data['durationSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'teacherId': teacherId,
        'planId': planId,
        'sessionId': sessionId,
        'exerciseId': exerciseId,
        'startedAt': Timestamp.fromDate(startedAt),
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'durationSeconds': durationSeconds,
      };
}

// ============================================================================
// Template Exercise Model
// ============================================================================
class TemplateExercise {
  final String id;
  final String title;
  final String description;
  final TemplateVariant variantA;
  final TemplateVariant variantB;
  final TemplateVariant variantC;
  final DateTime createdAt;

  TemplateExercise({
    required this.id,
    required this.title,
    required this.description,
    required this.variantA,
    required this.variantB,
    required this.variantC,
    required this.createdAt,
  });

  factory TemplateExercise.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TemplateExercise(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      variantA: TemplateVariant.fromMap(data['variantA'] ?? {}),
      variantB: TemplateVariant.fromMap(data['variantB'] ?? {}),
      variantC: TemplateVariant.fromMap(data['variantC'] ?? {}),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'variantA': variantA.toMap(),
        'variantB': variantB.toMap(),
        'variantC': variantC.toMap(),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class TemplateVariant {
  final String instructions;
  final int? targetBpm;
  final int? targetSeconds;

  TemplateVariant({
    required this.instructions,
    this.targetBpm,
    this.targetSeconds,
  });

  factory TemplateVariant.fromMap(Map<String, dynamic> map) {
    return TemplateVariant(
      instructions: map['instructions'] ?? '',
      targetBpm: map['targetBpm'],
      targetSeconds: map['targetSeconds'],
    );
  }

  Map<String, dynamic> toMap() => {
        'instructions': instructions,
        'targetBpm': targetBpm,
        'targetSeconds': targetSeconds,
      };
}

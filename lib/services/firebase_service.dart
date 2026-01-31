import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../models/models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // Auth
  // ============================================================================
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ============================================================================
  // Users
  // ============================================================================
  Future<void> createUser(AppUser user) async {
    await _firestore.collection('users').doc(user.id).set(user.toFirestore());
  }

  Future<AppUser?> getUser(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Stream<AppUser?> userStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  Future<void> updateUserRole(String userId, String role) async {
    await _firestore.collection('users').doc(userId).update({'role': role});
  }

  Future<AppUser?> getUserByEmail(String email) async {
    // Try exact match first
    var query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      return AppUser.fromFirestore(query.docs.first);
    }
    
    // Try case-insensitive by checking original email
    query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) return null;
    return AppUser.fromFirestore(query.docs.first);
  }

  Future<AppUser?> getUserByDisplayName(String displayName) async {
    final query = await _firestore
        .collection('users')
        .where('displayName', isEqualTo: displayName.trim())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return AppUser.fromFirestore(query.docs.first);
  }

  // Search students by email or display name
  Future<List<AppUser>> searchStudents(String searchTerm) async {
    final term = searchTerm.trim().toLowerCase();
    if (term.isEmpty) return [];

    // Get all students and filter (not ideal for large datasets, but works for MVP)
    final query = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();

    return query.docs
        .map((doc) => AppUser.fromFirestore(doc))
        .where((user) =>
            user.email.toLowerCase().contains(term) ||
            user.displayName.toLowerCase().contains(term))
        .toList();
  }

  // ============================================================================
  // Plans
  // ============================================================================
  Future<String> createPlan(Plan plan) async {
    final doc = await _firestore.collection('plans').add(plan.toFirestore());
    return doc.id;
  }

  Future<void> updatePlan(Plan plan) async {
    await _firestore
        .collection('plans')
        .doc(plan.id)
        .update(plan.toFirestore());
  }

  Stream<List<Plan>> teacherPlansStream(String teacherId) {
    return _firestore
        .collection('plans')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Plan.fromFirestore(doc)).toList());
  }

  Future<Plan?> getPlan(String planId) async {
    final doc = await _firestore.collection('plans').doc(planId).get();
    if (!doc.exists) return null;
    return Plan.fromFirestore(doc);
  }

  // ============================================================================
  // Sessions
  // ============================================================================
  Future<String> createSession(String planId, Session session) async {
    final doc = await _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .add(session.toFirestore());
    return doc.id;
  }

  Future<void> updateSession(String planId, Session session) async {
    await _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .doc(session.id)
        .update(session.toFirestore());
  }

  Stream<List<Session>> sessionsStream(String planId) {
    return _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Session.fromFirestore(doc, planId))
            .toList());
  }

  Future<Session?> getSession(String planId, String sessionId) async {
    final doc = await _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .doc(sessionId)
        .get();
    if (!doc.exists) return null;
    return Session.fromFirestore(doc, planId);
  }

  Future<int> getSessionsCount(String planId) async {
    final snapshot = await _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ============================================================================
  // Exercises
  // ============================================================================
  Future<String> createExercise(
      String planId, String sessionId, Exercise exercise) async {
    final exerciseRef = _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .doc(sessionId)
        .collection('exercises');
    
    // If exercise has an ID, use it (for file uploads before creation)
    if (exercise.id.isNotEmpty) {
      await exerciseRef.doc(exercise.id).set(exercise.toFirestore());
      return exercise.id;
    } else {
      // Otherwise, let Firestore generate ID
      final doc = await exerciseRef.add(exercise.toFirestore());
      return doc.id;
    }
  }

  Future<void> updateExercise(
      String planId, String sessionId, Exercise exercise) async {
    await _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .doc(sessionId)
        .collection('exercises')
        .doc(exercise.id)
        .update(exercise.toFirestore());
  }

  Stream<List<Exercise>> exercisesStream(String planId, String sessionId) {
    return _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .doc(sessionId)
        .collection('exercises')
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Exercise.fromFirestore(doc, sessionId))
            .toList());
  }

  Future<List<Exercise>> getExercises(String planId, String sessionId) async {
    final snapshot = await _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .doc(sessionId)
        .collection('exercises')
        .orderBy('orderIndex')
        .get();
    return snapshot.docs
        .map((doc) => Exercise.fromFirestore(doc, sessionId))
        .toList();
  }

  Future<int> getExercisesCount(String planId, String sessionId) async {
    final snapshot = await _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .doc(sessionId)
        .collection('exercises')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ============================================================================
  // Assignments
  // ============================================================================
  Future<String> createAssignment(Assignment assignment) async {
    final doc =
        await _firestore.collection('assignments').add(assignment.toFirestore());
    return doc.id;
  }

  Stream<List<Assignment>> teacherAssignmentsStream(String teacherId) {
    return _firestore
        .collection('assignments')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('assignedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Assignment.fromFirestore(doc)).toList());
  }

  Stream<List<Assignment>> studentAssignmentsStream(String studentId) {
    return _firestore
        .collection('assignments')
        .where('studentId', isEqualTo: studentId)
        .orderBy('assignedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Assignment.fromFirestore(doc)).toList());
  }

  // Get existing assignment for student + plan combination
  Future<Assignment?> getAssignmentByStudentAndPlan(
      String studentId, String planId) async {
    final query = await _firestore
        .collection('assignments')
        .where('studentId', isEqualTo: studentId)
        .where('planId', isEqualTo: planId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return Assignment.fromFirestore(query.docs.first);
  }

  // Delete assignment
  Future<void> deleteAssignment(String assignmentId) async {
    await _firestore.collection('assignments').doc(assignmentId).delete();
  }

  // ============================================================================
  // Practice Logs
  // ============================================================================
  Future<String> createPracticeLog(PracticeLog log) async {
    final doc =
        await _firestore.collection('practiceLogs').add(log.toFirestore());
    return doc.id;
  }

  Stream<List<PracticeLog>> studentPracticeLogsStream(String studentId) {
    return _firestore
        .collection('practiceLogs')
        .where('studentId', isEqualTo: studentId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PracticeLog.fromFirestore(doc)).toList());
  }

  // Get practice logs for a teacher's students
  Stream<List<PracticeLog>> teacherPracticeLogsStream(String teacherId) {
    return _firestore
        .collection('practiceLogs')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PracticeLog.fromFirestore(doc)).toList());
  }

  // Get practice logs for a specific student (teacher view)
  Future<List<PracticeLog>> getStudentPracticeLogs(String studentId) async {
    final snapshot = await _firestore
        .collection('practiceLogs')
        .where('studentId', isEqualTo: studentId)
        .orderBy('startedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => PracticeLog.fromFirestore(doc))
        .toList();
  }

  // ============================================================================
  // File Storage
  // ============================================================================
  Future<String> uploadExerciseFile({
    required String planId,
    required String sessionId,
    required String exerciseId,
    required PlatformFile platformFile,
    required String fileName,
    Uint8List? data,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Not authenticated');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath =
        'exercises/$planId/$sessionId/$exerciseId/${timestamp}_$fileName';

    final storage = FirebaseStorage.instanceFor(
      app: Firebase.app(),
    );
    final ref = storage.ref().child(storagePath);

    final ext = fileName.split('.').last.toLowerCase();
    String? contentType;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        contentType = 'image/jpeg';
        break;
      case 'png':
        contentType = 'image/png';
        break;
      case 'gif':
        contentType = 'image/gif';
        break;
      case 'mp4':
        contentType = 'video/mp4';
        break;
      case 'mov':
        contentType = 'video/quicktime';
        break;
      case 'mp3':
        contentType = 'audio/mpeg';
        break;
      case 'wav':
        contentType = 'audio/wav';
        break;
      case 'm4a':
        contentType = 'audio/mp4';
        break;
      case 'pdf':
        contentType = 'application/pdf';
        break;
    }

    if (data != null) {
      await ref.putData(
        data,
        SettableMetadata(contentType: contentType),
      );
    } else if (kIsWeb) {
      if (platformFile.bytes == null) {
        throw Exception('File bytes are null');
      }
      await ref.putData(
        platformFile.bytes!,
        SettableMetadata(contentType: contentType),
      );
    } else {
      if (platformFile.path == null) {
        throw Exception('File path is null');
      }
      final file = File(platformFile.path!);
      await ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
    }

    return await ref.getDownloadURL();
  }

  Future<void> deleteExerciseFile(String fileUrl) async {
    try {
      final storage = FirebaseStorage.instanceFor(app: Firebase.app());
      final ref = storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      // File might not exist, ignore error
    }
  }

  // ============================================================================
  // Template Exercises
  // ============================================================================
  Future<String> createTemplateExercise(TemplateExercise template) async {
    final doc = await _firestore
        .collection('templateExercises')
        .add(template.toFirestore());
    return doc.id;
  }

  Stream<List<TemplateExercise>> templateExercisesStream() {
    return _firestore
        .collection('templateExercises')
        .orderBy('title')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TemplateExercise.fromFirestore(doc))
            .toList());
  }

  Future<List<TemplateExercise>> getTemplateExercises() async {
    final snapshot = await _firestore
        .collection('templateExercises')
        .orderBy('title')
        .get();
    return snapshot.docs
        .map((doc) => TemplateExercise.fromFirestore(doc))
        .toList();
  }
}

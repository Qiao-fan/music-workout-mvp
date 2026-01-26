import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final doc = await _firestore
        .collection('plans')
        .doc(planId)
        .collection('sessions')
        .doc(sessionId)
        .collection('exercises')
        .add(exercise.toFirestore());
    return doc.id;
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
}

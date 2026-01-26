import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

// ============================================================================
// Firebase Service Provider
// ============================================================================
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

// ============================================================================
// Auth Providers
// ============================================================================
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseServiceProvider).authStateChanges;
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(firebaseServiceProvider).userStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ============================================================================
// Plan Providers
// ============================================================================
final teacherPlansProvider =
    StreamProvider.family<List<Plan>, String>((ref, teacherId) {
  return ref.watch(firebaseServiceProvider).teacherPlansStream(teacherId);
});

final planProvider = FutureProvider.family<Plan?, String>((ref, planId) {
  return ref.watch(firebaseServiceProvider).getPlan(planId);
});

// ============================================================================
// Session Providers
// ============================================================================
final sessionsProvider =
    StreamProvider.family<List<Session>, String>((ref, planId) {
  return ref.watch(firebaseServiceProvider).sessionsStream(planId);
});

final sessionProvider =
    FutureProvider.family<Session?, ({String planId, String sessionId})>(
        (ref, params) {
  return ref
      .watch(firebaseServiceProvider)
      .getSession(params.planId, params.sessionId);
});

// ============================================================================
// Exercise Providers
// ============================================================================
final exercisesProvider = StreamProvider.family<List<Exercise>,
    ({String planId, String sessionId})>((ref, params) {
  return ref
      .watch(firebaseServiceProvider)
      .exercisesStream(params.planId, params.sessionId);
});

final exercisesListProvider = FutureProvider.family<List<Exercise>,
    ({String planId, String sessionId})>((ref, params) {
  return ref
      .watch(firebaseServiceProvider)
      .getExercises(params.planId, params.sessionId);
});

// ============================================================================
// Assignment Providers
// ============================================================================
final teacherAssignmentsProvider =
    StreamProvider.family<List<Assignment>, String>((ref, teacherId) {
  return ref
      .watch(firebaseServiceProvider)
      .teacherAssignmentsStream(teacherId);
});

final studentAssignmentsProvider =
    StreamProvider.family<List<Assignment>, String>((ref, studentId) {
  return ref
      .watch(firebaseServiceProvider)
      .studentAssignmentsStream(studentId);
});

// ============================================================================
// Practice Log Providers
// ============================================================================
final studentPracticeLogsProvider =
    StreamProvider.family<List<PracticeLog>, String>((ref, studentId) {
  return ref
      .watch(firebaseServiceProvider)
      .studentPracticeLogsStream(studentId);
});

final teacherPracticeLogsProvider =
    StreamProvider.family<List<PracticeLog>, String>((ref, teacherId) {
  return ref
      .watch(firebaseServiceProvider)
      .teacherPracticeLogsStream(teacherId);
});

final studentProgressProvider =
    FutureProvider.family<List<PracticeLog>, String>((ref, studentId) {
  return ref.watch(firebaseServiceProvider).getStudentPracticeLogs(studentId);
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/role_screen.dart';
import '../screens/teacher/teacher_home_screen.dart';
import '../screens/teacher/plan_editor_screen.dart';
import '../screens/teacher/session_editor_screen.dart';
import '../screens/teacher/exercise_editor_screen.dart';
import '../screens/teacher/assign_screen.dart';
import '../screens/teacher/progress_screen.dart';
import '../screens/teacher/template_editor_screen.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/student/plan_detail_screen.dart';
import '../screens/student/session_player_screen.dart';

// Auth state notifier for router refresh
class AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _userRole;

  bool get isLoggedIn => _isLoggedIn;
  String? get userRole => _userRole;

  void update(bool isLoggedIn, String? userRole) {
    final changed = _isLoggedIn != isLoggedIn || _userRole != userRole;
    _isLoggedIn = isLoggedIn;
    _userRole = userRole;
    if (changed) {
      notifyListeners();
    }
  }
}

final authNotifierProvider = Provider<AuthNotifier>((ref) {
  final notifier = AuthNotifier();
  
  // Listen to auth state changes
  ref.listen(authStateProvider, (previous, next) {
    final isLoggedIn = next.valueOrNull != null;
    final currentRole = ref.read(currentUserProvider).valueOrNull?.role;
    notifier.update(isLoggedIn, currentRole);
  });
  
  // Listen to user changes (for role updates)
  ref.listen(currentUserProvider, (previous, next) {
    final isLoggedIn = ref.read(authStateProvider).valueOrNull != null;
    final userRole = next.valueOrNull?.role;
    notifier.update(isLoggedIn, userRole);
  });
  
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider);
      
      final isLoggedIn = authState.valueOrNull != null;
      final user = currentUser.valueOrNull;
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      final isRoleSelection = state.matchedLocation == '/role';

      // Still loading auth state - stay where we are
      if (authState.isLoading) {
        return null;
      }

      // Not logged in - go to login
      if (!isLoggedIn) {
        if (isLoggingIn) return null;
        return '/login';
      }

      // Logged in but user data still loading - stay where we are
      if (currentUser.isLoading) {
        return null;
      }

      // Logged in but no user document yet - stay where we are (will reload)
      if (user == null) {
        return null;
      }

      // Logged in but no role - go to role selection
      if (user.role == null && !isRoleSelection) {
        return '/role';
      }

      // Logged in with role - redirect from auth pages to home
      if (user.role != null && (isLoggingIn || isRoleSelection)) {
        if (user.role == 'teacher') return '/teacher/home';
        if (user.role == 'student') return '/student/home';
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleScreen(),
      ),

      // Teacher routes
      GoRoute(
        path: '/teacher/home',
        builder: (context, state) => const TeacherHomeScreen(),
      ),
      GoRoute(
        path: '/teacher/plan/new',
        builder: (context, state) => const PlanEditorScreen(),
      ),
      GoRoute(
        path: '/teacher/plan/:planId/edit',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          return PlanEditorScreen(planId: planId);
        },
      ),
      GoRoute(
        path: '/teacher/plan/:planId/session/new',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          return SessionEditorScreen(planId: planId);
        },
      ),
      GoRoute(
        path: '/teacher/plan/:planId/session/:sessionId',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          final sessionId = state.pathParameters['sessionId']!;
          return SessionEditorScreen(planId: planId, sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/teacher/plan/:planId/session/:sessionId/exercise/new',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          final sessionId = state.pathParameters['sessionId']!;
          return ExerciseEditorScreen(planId: planId, sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/teacher/plan/:planId/session/:sessionId/exercise/:exerciseId',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          final sessionId = state.pathParameters['sessionId']!;
          final exerciseId = state.pathParameters['exerciseId']!;
          return ExerciseEditorScreen(
            planId: planId,
            sessionId: sessionId,
            exerciseId: exerciseId,
          );
        },
      ),
      GoRoute(
        path: '/teacher/plan/:planId/template/new',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          return TemplateEditorScreen(planId: planId);
        },
      ),
      GoRoute(
        path: '/teacher/plan/:planId/template/:templateId',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          final templateId = state.pathParameters['templateId']!;
          return TemplateEditorScreen(planId: planId, templateId: templateId);
        },
      ),
      GoRoute(
        path: '/teacher/assign',
        builder: (context, state) => const AssignScreen(),
      ),
      GoRoute(
        path: '/teacher/student/:studentId/progress',
        builder: (context, state) {
          final studentId = state.pathParameters['studentId']!;
          return ProgressScreen(studentId: studentId);
        },
      ),

      // Student routes
      GoRoute(
        path: '/student/home',
        builder: (context, state) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: '/student/plan/:planId',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          return PlanDetailScreen(planId: planId);
        },
      ),
      GoRoute(
        path: '/student/plan/:planId/session/:sessionId/player',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          final sessionId = state.pathParameters['sessionId']!;
          return SessionPlayerScreen(planId: planId, sessionId: sessionId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

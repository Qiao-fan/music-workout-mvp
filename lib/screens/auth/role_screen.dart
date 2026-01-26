import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});

  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  String? _selectedRole;
  bool _isLoading = false;

  Future<void> _saveRole() async {
    if (_selectedRole == null) return;

    setState(() => _isLoading = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final authUser = firebaseService.currentUser;
      if (authUser != null) {
        // Check if user document exists
        final existingUser = await firebaseService.getUser(authUser.uid);
        
        if (existingUser == null) {
          // Create user document if it doesn't exist
          final newUser = AppUser(
            id: authUser.uid,
            email: authUser.email ?? '',
            displayName: authUser.displayName ?? authUser.email?.split('@').first ?? 'User',
            role: _selectedRole,
            createdAt: DateTime.now(),
          );
          await firebaseService.createUser(newUser);
        } else {
          // Update existing user
          await firebaseService.updateUserRole(authUser.uid, _selectedRole!);
        }
        
        // Navigate to appropriate home
        if (mounted) {
          if (_selectedRole == 'teacher') {
            context.go('/teacher/home');
          } else {
            context.go('/student/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'I am a...',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your role to get started',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _RoleCard(
                icon: Icons.school,
                title: 'Teacher',
                description: 'Create practice plans and assign them to students',
                isSelected: _selectedRole == 'teacher',
                onTap: () => setState(() => _selectedRole = 'teacher'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.person,
                title: 'Student',
                description: 'Follow practice plans and track your progress',
                isSelected: _selectedRole == 'student',
                onTap: () => setState(() => _selectedRole = 'student'),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed:
                    _selectedRole == null || _isLoading ? null : _saveRole,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

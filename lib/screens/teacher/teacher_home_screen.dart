import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/platform_utils.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

bool get _isWeb => kIsWeb;

class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser.valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Plans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment),
            tooltip: 'Assignments',
            onPressed: () => context.push('/teacher/assign'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(firebaseServiceProvider).signOut();
              if (!context.mounted) return;
              if (_isWeb) {
                reloadPage();
              } else {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : _PlansList(teacherId: userId),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/teacher/plan/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
    );
  }
}

class _PlansList extends ConsumerWidget {
  final String teacherId;

  const _PlansList({required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(teacherPlansProvider(teacherId));

    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_music,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No plans yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first practice plan',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            return _PlanCard(plan: plan);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        debugPrint('TEACHER HOME ERROR: $error');
        debugPrint('STACK: $stack');
        return Center(child: Text('Error: $error'));
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/teacher/plan/${plan.id}/edit'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: plan.published
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan.published ? 'Published' : 'Draft',
                      style: TextStyle(
                        fontSize: 12,
                        color: plan.published ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.music_note,
                    label: plan.instrument,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.signal_cellular_alt,
                    label: plan.difficulty,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

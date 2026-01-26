import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/platform_utils.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

bool get _isWeb => kIsWeb;

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser.valueOrNull?.id;
    final userName = currentUser.valueOrNull?.displayName ?? 'Student';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Practice'),
        actions: [
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
          : _buildBody(context, ref, userId, userName),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, String userId, String userName) {
    final assignmentsAsync = ref.watch(studentAssignmentsProvider(userId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.music_note,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                        ),
                        Text(
                          userName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Assigned Plans',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          assignmentsAsync.when(
            data: (assignments) {
              if (assignments.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.library_music,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No plans assigned yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask your teacher to assign you a practice plan',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assignments.length,
                itemBuilder: (context, index) {
                  final assignment = assignments[index];
                  return _AssignedPlanCard(assignment: assignment);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
          ),
        ],
      ),
    );
  }
}

class _AssignedPlanCard extends ConsumerWidget {
  final Assignment assignment;

  const _AssignedPlanCard({required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planProvider(assignment.planId));

    return planAsync.when(
      data: (plan) {
        if (plan == null) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => context.push('/student/plan/${plan.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.library_music,
                          color:
                              Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plan.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(icon: Icons.music_note, label: plan.instrument),
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: Icons.signal_cellular_alt,
                          label: plan.difficulty),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Card(
        margin: EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
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
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

class PlanDetailScreen extends ConsumerWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planProvider(planId));
    final sessionsAsync = ref.watch(sessionsProvider(planId));

    return Scaffold(
      body: planAsync.when(
        data: (plan) {
          if (plan == null) {
            return const Center(child: Text('Plan not found'));
          }
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, plan),
              SliverToBoxAdapter(
                child: _buildPlanInfo(context, plan),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Sessions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              _buildSessionsList(context, sessionsAsync),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Plan plan) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          plan.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 4,
                color: Colors.black45,
              ),
            ],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.library_music,
              size: 80,
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanInfo(BuildContext context, Plan plan) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InfoChip(icon: Icons.music_note, label: plan.instrument),
              const SizedBox(width: 8),
              _InfoChip(icon: Icons.signal_cellular_alt, label: plan.difficulty),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            plan.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(
      BuildContext context, AsyncValue<List<Session>> sessionsAsync) {
    return sessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.playlist_remove,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sessions available',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final session = sessions[index];
                return _SessionCard(
                  session: session,
                  index: index,
                  onTap: () => context.push(
                    '/student/plan/$planId/session/${session.id}/player',
                  ),
                );
              },
              childCount: sessions.length,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        child: Center(child: Text('Error: $error')),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  final int index;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${session.estMinutes} minutes',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: onTap,
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

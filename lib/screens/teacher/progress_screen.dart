import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class ProgressScreen extends ConsumerWidget {
  final String studentId;

  const ProgressScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(studentProgressProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Progress'),
      ),
      body: logsAsync.when(
        data: (logs) => _buildProgressView(context, logs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildProgressView(BuildContext context, List<PracticeLog> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No practice logs yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Student has not completed any exercises',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    // Calculate stats
    final totalMinutes = logs.fold<int>(
      0,
      (sum, log) => sum + (log.durationSeconds ~/ 60),
    );
    final lastActivity = logs.first.startedAt;
    final sessionsCompleted = logs.map((l) => l.sessionId).toSet().length;
    final exercisesCompleted = logs.length;

    // Group logs by session
    final logsBySession = <String, List<PracticeLog>>{};
    for (final log in logs) {
      logsBySession.putIfAbsent(log.sessionId, () => []).add(log);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.timer,
                  label: 'Total Minutes',
                  value: totalMinutes.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.fitness_center,
                  label: 'Exercises',
                  value: exercisesCompleted.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.playlist_play,
                  label: 'Sessions',
                  value: sessionsCompleted.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_today,
                  label: 'Last Active',
                  value: _formatDate(lastActivity),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Practice History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _PracticeLogCard(log: log);
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeLogCard extends ConsumerWidget {
  final PracticeLog log;

  const _PracticeLogCard({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM d, yyyy - h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text('Exercise completed'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(log.startedAt)),
            Text(
              '${log.durationSeconds ~/ 60} minutes',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

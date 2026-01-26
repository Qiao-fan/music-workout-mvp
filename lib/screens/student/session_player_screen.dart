import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class SessionPlayerScreen extends ConsumerStatefulWidget {
  final String planId;
  final String sessionId;

  const SessionPlayerScreen({
    super.key,
    required this.planId,
    required this.sessionId,
  });

  @override
  ConsumerState<SessionPlayerScreen> createState() =>
      _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends ConsumerState<SessionPlayerScreen> {
  int _currentExerciseIndex = 0;
  bool _isTimerRunning = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  DateTime? _exerciseStartTime;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _exerciseStartTime ??= DateTime.now();
    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _elapsedSeconds = 0;
      _exerciseStartTime = null;
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _markComplete(Exercise exercise, Plan plan) async {
    final firebaseService = ref.read(firebaseServiceProvider);
    final userId = firebaseService.currentUser?.uid;

    if (userId == null) return;

    try {
      final log = PracticeLog(
        id: '',
        studentId: userId,
        teacherId: plan.teacherId,
        planId: widget.planId,
        sessionId: widget.sessionId,
        exerciseId: exercise.id,
        startedAt: _exerciseStartTime ?? DateTime.now(),
        completedAt: DateTime.now(),
        durationSeconds: _elapsedSeconds,
      );

      await firebaseService.createPracticeLog(log);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completed: ${exercise.title}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _nextExercise(List<Exercise> exercises, Plan plan) async {
    if (_currentExerciseIndex < exercises.length - 1) {
      // Mark current as complete
      await _markComplete(exercises[_currentExerciseIndex], plan);
      _resetTimer();
      setState(() => _currentExerciseIndex++);
    } else {
      // Last exercise - mark complete and show completion
      await _markComplete(exercises[_currentExerciseIndex], plan);
      _showCompletionDialog();
    }
  }

  void _previousExercise() {
    if (_currentExerciseIndex > 0) {
      _resetTimer();
      setState(() => _currentExerciseIndex--);
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.celebration, size: 48),
        title: const Text('Session Complete!'),
        content: const Text(
          'Great job! You\'ve completed all exercises in this session.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/student/home');
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesListProvider((
      planId: widget.planId,
      sessionId: widget.sessionId,
    )));
    final planAsync = ref.watch(planProvider(widget.planId));
    final sessionAsync = ref.watch(sessionProvider((
      planId: widget.planId,
      sessionId: widget.sessionId,
    )));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(),
        ),
        title: sessionAsync.when(
          data: (session) => Text(session?.title ?? 'Session'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Session'),
        ),
        actions: [
          exercisesAsync.when(
            data: (exercises) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentExerciseIndex + 1} / ${exercises.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: exercisesAsync.when(
        data: (exercises) {
          if (exercises.isEmpty) {
            return const Center(
              child: Text('No exercises in this session'),
            );
          }
          return planAsync.when(
            data: (plan) {
              if (plan == null) return const Center(child: Text('Plan not found'));
              return _buildPlayerUI(exercises, plan);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildPlayerUI(List<Exercise> exercises, Plan plan) {
    final exercise = exercises[_currentExerciseIndex];
    final isFirst = _currentExerciseIndex == 0;
    final isLast = _currentExerciseIndex == exercises.length - 1;

    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: ((_currentExerciseIndex + 1) / exercises.length),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exercise title
                Text(
                  exercise.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Target info
                if (exercise.targetBpm != null ||
                    exercise.targetSeconds != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      if (exercise.targetBpm != null)
                        Chip(
                          avatar: const Icon(Icons.speed, size: 18),
                          label: Text('${exercise.targetBpm} BPM'),
                        ),
                      if (exercise.targetSeconds != null)
                        Chip(
                          avatar: const Icon(Icons.timer, size: 18),
                          label: Text('${exercise.targetSeconds}s target'),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Timer card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          _formatTime(_elapsedSeconds),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w300,
                                fontFamily: 'monospace',
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filled(
                              onPressed:
                                  _isTimerRunning ? _pauseTimer : _startTimer,
                              icon: Icon(
                                _isTimerRunning
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              iconSize: 32,
                            ),
                            const SizedBox(width: 16),
                            IconButton.outlined(
                              onPressed: _resetTimer,
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Instructions
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    exercise.instructions,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),

                // Attachments
                if (exercise.attachmentUrls.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Attachments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...exercise.attachmentUrls.map((url) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.link),
                          title: Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () {
                            // TODO: Open URL
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Open: $url')),
                            );
                          },
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),

        // Bottom navigation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (!isFirst)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _previousExercise,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  ),
                if (!isFirst) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _nextExercise(exercises, plan),
                    icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
                    label: Text(isLast ? 'Complete' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Session?'),
        content: const Text(
          'Your progress for this exercise will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

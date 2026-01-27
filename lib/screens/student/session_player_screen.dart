import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Metronome state
  bool _metronomeOn = false;
  int _currentBpm = 80;
  Timer? _metronomeTimer;
  bool _metronomeTickOn = false;
  bool _metronomeSoundOn = true;

  // Countdown state
  bool _isCountdown = false;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _metronomeTimer?.cancel();
    super.dispose();
  }

  void _startTimer(Exercise exercise) {
    // Reset any existing timer
    _timer?.cancel();

    _exerciseStartTime ??= DateTime.now();

    // Configure countdown vs stopwatch based on suggested duration
    if (exercise.targetSeconds != null) {
      _isCountdown = true;
      // If we haven't started yet or we've reset, initialize remaining
      if (_remainingSeconds == 0) {
        _remainingSeconds = exercise.targetSeconds!;
      }
    } else {
      _isCountdown = false;
      _remainingSeconds = 0;
    }

    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;

        if (_isCountdown && _remainingSeconds > 0) {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            _isTimerRunning = false;
            _timer?.cancel();
          }
        }
      });
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
      _isCountdown = false;
      _remainingSeconds = 0;
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

  void _startMetronome() {
    _metronomeTimer?.cancel();
    if (_currentBpm <= 0) return;
    final intervalMs = (60000 / _currentBpm).round();
    _metronomeTimer =
        Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      setState(() {
        _metronomeTickOn = !_metronomeTickOn;
      });
      if (_metronomeSoundOn) {
        SystemSound.play(SystemSoundType.click);
      }
    });
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    setState(() {
      _metronomeTickOn = false;
    });
  }

  void _toggleMetronome() {
    if (_metronomeOn) {
      _startMetronome();
    } else {
      _stopMetronome();
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
    final completedExercises = _currentExerciseIndex;
    final totalExercises = exercises.length;

    // If this is the first time we see this exercise and it has a target BPM,
    // use that as the default metronome BPM.
    if (_elapsedSeconds == 0 &&
        _exerciseStartTime == null &&
        exercise.targetBpm != null &&
        _currentBpm == 80) {
      _currentBpm = exercise.targetBpm!;
    }

    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: totalExercises == 0
              ? 0
              : (completedExercises / totalExercises),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '$completedExercises of $totalExercises exercises completed',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
                          label: Text('Suggested: ${exercise.targetSeconds}s'),
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
                          _formatTime(
                            _isCountdown ? _remainingSeconds : _elapsedSeconds,
                          ),
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
                                  _isTimerRunning ? _pauseTimer : () => _startTimer(exercise),
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
                        const SizedBox(height: 16),

                        // Metronome controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Switch(
                              value: _metronomeOn,
                              onChanged: (value) {
                                setState(() {
                                  _metronomeOn = value;
                                });
                                _toggleMetronome();
                              },
                            ),
                            const Text('Metronome'),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: _metronomeOn
                                  ? (_metronomeTickOn
                                      ? Colors.green
                                      : Colors.green.withOpacity(0.3))
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.5),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 90,
                              child: TextFormField(
                                initialValue: _currentBpm.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'BPM',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final bpm = int.tryParse(value);
                                  if (bpm == null || bpm <= 0) return;
                                  setState(() {
                                    _currentBpm = bpm;
                                  });
                                  if (_metronomeOn) {
                                    _startMetronome();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                _metronomeSoundOn
                                    ? Icons.volume_up
                                    : Icons.volume_off,
                              ),
                              tooltip:
                                  _metronomeSoundOn ? 'Mute metronome' : 'Unmute metronome',
                              onPressed: () {
                                setState(() {
                                  _metronomeSoundOn = !_metronomeSoundOn;
                                });
                              },
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

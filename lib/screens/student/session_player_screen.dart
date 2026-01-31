import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/pdf_viewer.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
  final AudioPlayer _metronomePlayer = AudioPlayer();

  // Countdown state
  bool _isCountdown = false;
  int _remainingSeconds = 0;

  // When true, PDF viewer is hidden so it cannot overlay dialogs (web iframe fix)
  bool _isDialogOpen = false;

  @override
  void dispose() {
    _timer?.cancel();
    _metronomeTimer?.cancel();
    _metronomePlayer.dispose();
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

  void _resetTimer(Exercise exercise) {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _elapsedSeconds = 0;
      _isCountdown = exercise.targetSeconds != null;
      _remainingSeconds = exercise.targetSeconds ?? 0;
      _exerciseStartTime = null;
    });
  }

  int _getDisplaySeconds(Exercise exercise) {
    if (exercise.targetSeconds != null && !_isTimerRunning && _elapsedSeconds == 0) {
      return exercise.targetSeconds!;
    }
    if (_isCountdown) return _remainingSeconds;
    return _elapsedSeconds;
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
      // Play click sound
      if (_metronomeSoundOn) {
        _metronomePlayer.play(AssetSource('sounds/click.wav'));
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
      setState(() => _currentExerciseIndex++);
      _resetTimer(exercises[_currentExerciseIndex]);
    } else {
      // Last exercise - mark complete and show completion
      await _markComplete(exercises[_currentExerciseIndex], plan);
      _showCompletionDialog();
    }
  }

  void _previousExercise(List<Exercise> exercises) {
    if (_currentExerciseIndex > 0) {
      setState(() => _currentExerciseIndex--);
      _resetTimer(exercises[_currentExerciseIndex]);
    }
  }

  void _showCompletionDialog() {
    setState(() => _isDialogOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PointerInterceptor(
          child: AlertDialog(
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
        ),
      ).then((_) {
        if (mounted) setState(() => _isDialogOpen = false);
      });
    });
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
                // Exercise title with metronome controls
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        exercise.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    // Metronome controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
                        const SizedBox(width: 4),
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
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 70,
                          child: TextFormField(
                            initialValue: _currentBpm.toString(),
                            decoration: const InputDecoration(
                              labelText: 'BPM',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                            size: 20,
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
                const SizedBox(height: 16),

                // Target BPM and Timer (compact, less prominent)
                Row(
                  children: [
                    if (exercise.targetBpm != null)
                      Chip(
                        avatar: const Icon(Icons.speed, size: 16),
                        label: Text('${exercise.targetBpm} BPM'),
                      ),
                    if (exercise.targetBpm != null) const SizedBox(width: 8),
                    // Compact timer
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isTimerRunning ? Icons.pause : Icons.play_arrow,
                                size: 20,
                              ),
                              onPressed: _isTimerRunning
                                  ? _pauseTimer
                                  : () => _startTimer(exercise),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(_getDisplaySeconds(exercise)),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                            ),
                            if (_isTimerRunning || _elapsedSeconds > 0) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                onPressed: () => _resetTimer(exercise),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // MAIN CONTENT AREA: Media (Video/Image) or Instructions
                _buildMainContent(exercise),

                const SizedBox(height: 24),

                // Instructions (if media is present, show below; if no media, already shown above)
                if (exercise.attachmentUrls.isNotEmpty) ...[
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
                      onPressed: () => _previousExercise(exercises),
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

  Widget _buildMainContent(Exercise exercise) {
    // Check if there are media attachments (images or videos)
    final hasMedia = exercise.attachmentUrls.isNotEmpty;
    
    if (hasMedia) {
      // Find first image or video
      String? imageUrl;
      String? videoUrl;
      String? audioUrl;
      String? pdfUrl;
      
      for (final url in exercise.attachmentUrls) {
        final lower = url.toLowerCase();
        if (imageUrl == null && (lower.contains('.jpg') || lower.contains('.jpeg') || 
            lower.contains('.png') || lower.contains('.gif'))) {
          imageUrl = url;
        } else if (videoUrl == null && (lower.contains('.mp4') || lower.contains('.mov') || 
                   lower.contains('.avi'))) {
          videoUrl = url;
        } else if (audioUrl == null && (lower.contains('.mp3') || lower.contains('.wav') || 
                   lower.contains('.m4a'))) {
          audioUrl = url;
        } else if (pdfUrl == null && lower.contains('.pdf')) {
          pdfUrl = url;
        }
      }
      
      // Prioritize: Image > Video > Audio > PDF
      if (imageUrl != null) {
        return _buildImageContent(imageUrl);
      } else if (videoUrl != null) {
        return _buildVideoContent(videoUrl);
      } else if (audioUrl != null) {
        return _buildAudioContent(audioUrl);
      } else if (pdfUrl != null) {
        return _buildPdfContent(pdfUrl);
      }
    }
    
    // No media - show instructions as main content
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instructions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            exercise.instructions,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(String imageUrl) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: kIsWeb
            ? _buildWebImage(imageUrl)
            : Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Image load error: $error');
                  debugPrint('Image URL: $imageUrl');
                  return _buildImageError(imageUrl);
                },
              ),
      ),
    );
  }

  Widget _buildWebImage(String imageUrl) {
    // For web, try using an iframe to display the image
    // This bypasses CORS restrictions for canvas-based rendering
    return SizedBox(
      width: double.infinity,
      height: 400,
      child: Stack(
        children: [
          // Try to load image directly - if CORS is configured, this should work
          Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // If direct load fails, show clickable preview
              return _buildImageClickablePreview(imageUrl);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageClickablePreview(String imageUrl) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(imageUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Image Preview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(imageUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('View Full Image'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(String videoUrl) {
    return _InlineVideoPlayer(videoUrl: videoUrl);
  }

  Widget _buildAudioContent(String audioUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.audiotrack,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Audio File',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.parse(audioUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Audio'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageError(String imageUrl) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load image',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          // Show URL for debugging
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              imageUrl,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          // Add button to open in browser
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(imageUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in browser'),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfContent(String pdfUrl) {
    // When a dialog is open, hide the PDF viewer so it cannot overlay the dialog.
    // The web iframe renders in a separate DOM layer and captures pointer events.
    if (_isDialogOpen) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Icon(
            Icons.picture_as_pdf,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }
    return buildPdfViewer(pdfUrl);
  }

  void _showExitConfirmation() {
    setState(() => _isDialogOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => PointerInterceptor(
          child: AlertDialog(
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
        ),
      ).then((_) {
        if (mounted) setState(() => _isDialogOpen = false);
      });
    });
  }
}

// ============================================================================
// Inline Video Player (media_kit - supports MOV on mobile/desktop)
// ============================================================================
class _InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _InlineVideoPlayer({required this.videoUrl});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;
  StreamSubscription<String>? _errorSub;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _errorSub = _player.stream.error.listen((e) {
      if (mounted) setState(() => _error = e);
    });
    _player.open(Media(widget.videoUrl), play: false).then((_) {
      if (mounted) setState(() => _isReady = true);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Widget _buildErrorState() {
    final isMov = widget.videoUrl.toLowerCase().contains('.mov');
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load video',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (isMov && kIsWeb) ...[
            const SizedBox(height: 12),
            Text(
              'MOV files often don\'t play in-browser. Convert to MP4 (H.264) for web, or try the app on mobile.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(widget.videoUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open video externally'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _buildErrorState();

    if (!_isReady) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 300),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 250, maxHeight: 500),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Video(
          controller: _controller,
          controls: AdaptiveVideoControls,
        ),
      ),
    );
  }
}

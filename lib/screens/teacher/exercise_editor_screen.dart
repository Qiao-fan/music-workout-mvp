import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class ExerciseEditorScreen extends ConsumerStatefulWidget {
  final String planId;
  final String sessionId;
  final String? exerciseId;

  const ExerciseEditorScreen({
    super.key,
    required this.planId,
    required this.sessionId,
    this.exerciseId,
  });

  @override
  ConsumerState<ExerciseEditorScreen> createState() =>
      _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends ConsumerState<ExerciseEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _bpmController = TextEditingController();
  final _secondsController = TextEditingController();
  final _urlController = TextEditingController();
  List<String> _attachmentUrls = [];
  bool _isLoading = false;
  bool _isSaved = false;
  bool _isInitialized = false;
  int _currentOrderIndex = 0;

  bool get isEditing => widget.exerciseId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _bpmController.dispose();
    _secondsController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _initFromExercise(Exercise exercise) {
    if (_isInitialized) return;
    _titleController.text = exercise.title;
    _instructionsController.text = exercise.instructions;
    _bpmController.text = exercise.targetBpm?.toString() ?? '';
    _secondsController.text = exercise.targetSeconds?.toString() ?? '';
    _attachmentUrls = List.from(exercise.attachmentUrls);
    _currentOrderIndex = exercise.orderIndex;
    _isInitialized = true;
  }

  void _addUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        _attachmentUrls.add(url);
        _urlController.clear();
      });
    }
  }

  void _removeUrl(int index) {
    setState(() {
      _attachmentUrls.removeAt(index);
    });
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isSaved = false;
    });

    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      int orderIndex = _currentOrderIndex;
      
      // For new exercises, auto-assign order based on existing count
      if (!isEditing) {
        final existingExercises = await firebaseService.getExercisesCount(
          widget.planId, 
          widget.sessionId,
        );
        orderIndex = existingExercises;
      }

      final exercise = Exercise(
        id: widget.exerciseId ?? '',
        sessionId: widget.sessionId,
        title: _titleController.text.trim(),
        instructions: _instructionsController.text.trim(),
        orderIndex: orderIndex,
        targetBpm: int.tryParse(_bpmController.text),
        targetSeconds: int.tryParse(_secondsController.text),
        attachmentUrls: _attachmentUrls,
      );

      if (isEditing) {
        await firebaseService.updateExercise(
          widget.planId,
          widget.sessionId,
          exercise,
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isSaved = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Exercise saved!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Reset saved indicator after delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isSaved = false);
          });
        }
      } else {
        await firebaseService.createExercise(
          widget.planId,
          widget.sessionId,
          exercise,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Exercise created!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/teacher/plan/${widget.planId}/session/${widget.sessionId}'),
          tooltip: 'Back to Session',
        ),
        title: Text(isEditing ? 'Edit Exercise' : 'New Exercise'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveExercise,
            icon: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _isSaved
                    ? const Icon(Icons.check, color: Colors.green)
                    : const Icon(Icons.save),
            label: Text(_isSaved ? 'Saved' : 'Save'),
          ),
        ],
      ),
      body: isEditing ? _buildEditingBody() : _buildForm(),
    );
  }

  Widget _buildEditingBody() {
    final exercisesAsync = ref.watch(exercisesProvider((
      planId: widget.planId,
      sessionId: widget.sessionId,
    )));

    return exercisesAsync.when(
      data: (exercises) {
        final exercise = exercises.where((e) => e.id == widget.exerciseId).firstOrNull;
        if (exercise == null) {
          return const Center(child: Text('Exercise not found'));
        }
        _initFromExercise(exercise);
        return _buildForm();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Simple crotchets, consistent feel',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'Describe how to perform this exercise',
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter instructions';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bpmController,
              decoration: const InputDecoration(
                labelText: 'Target BPM (optional)',
                hintText: '80',
                suffixText: 'BPM',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _secondsController,
              decoration: const InputDecoration(
                labelText: 'Suggested duration (optional)',
                hintText: 'e.g. 120',
                suffixText: 'seconds',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            Text(
              'Attachment URLs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Add URL',
                      hintText: 'https://...',
                    ),
                    onFieldSubmitted: (_) => _addUrl(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addUrl,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_attachmentUrls.isNotEmpty) ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attachmentUrls.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.link),
                      title: Text(
                        _attachmentUrls[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeUrl(index),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

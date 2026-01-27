import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class SessionEditorScreen extends ConsumerStatefulWidget {
  final String planId;
  final String? sessionId;

  const SessionEditorScreen({
    super.key,
    required this.planId,
    this.sessionId,
  });

  @override
  ConsumerState<SessionEditorScreen> createState() =>
      _SessionEditorScreenState();
}

class _SessionEditorScreenState extends ConsumerState<SessionEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _minutesController = TextEditingController(text: '15');
  bool _isLoading = false;
  bool _isSaved = false;
  bool _isInitialized = false;
  int _currentOrderIndex = 0;

  bool get isEditing => widget.sessionId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _initFromSession(Session session) {
    if (_isInitialized) return;
    _titleController.text = session.title;
    _minutesController.text = session.estMinutes.toString();
    _currentOrderIndex = session.orderIndex;
    _isInitialized = true;
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isSaved = false;
    });

    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      int orderIndex = _currentOrderIndex;
      
      // For new sessions, auto-assign order based on existing count
      if (!isEditing) {
        final existingSessions = await firebaseService.getSessionsCount(widget.planId);
        orderIndex = existingSessions;
      }

      final session = Session(
        id: widget.sessionId ?? '',
        planId: widget.planId,
        title: _titleController.text.trim(),
        orderIndex: orderIndex,
        estMinutes: int.tryParse(_minutesController.text) ?? 15,
      );

      if (isEditing) {
        await firebaseService.updateSession(widget.planId, session);
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
                  Text('Session saved!'),
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
        await firebaseService.createSession(widget.planId, session);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Session created!'),
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
          onPressed: () => context.go('/teacher/plan/${widget.planId}/edit'),
          tooltip: 'Back to Plan',
        ),
        title: Text(isEditing ? 'Edit Session' : 'New Session'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveSession,
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
    final sessionAsync = ref.watch(sessionProvider((
      planId: widget.planId,
      sessionId: widget.sessionId!,
    )));

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          return const Center(child: Text('Session not found'));
        }
        _initFromSession(session);
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
                hintText: 'e.g., Day 1: Right-hand thumb development',
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
              controller: _minutesController,
              decoration: const InputDecoration(
                labelText: 'Estimated Minutes',
                hintText: '15',
                suffixText: 'min',
              ),
              keyboardType: TextInputType.number,
            ),
            if (isEditing) ...[
              const Divider(height: 32),
              _ExercisesSection(
                planId: widget.planId,
                sessionId: widget.sessionId!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExercisesSection extends ConsumerWidget {
  final String planId;
  final String sessionId;

  const _ExercisesSection({
    required this.planId,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider((
      planId: planId,
      sessionId: sessionId,
    )));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Exercises',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FilledButton.icon(
              onPressed: () => context.push(
                '/teacher/plan/$planId/session/$sessionId/exercise/new',
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        exercisesAsync.when(
          data: (exercises) {
            if (exercises.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No exercises yet',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(exercise.title),
                    subtitle: Text(
                      exercise.targetBpm != null
                          ? '${exercise.targetBpm} BPM'
                          : 'No target BPM',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/teacher/plan/$planId/session/$sessionId/exercise/${exercise.id}',
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Error: $error'),
        ),
      ],
    );
  }
}

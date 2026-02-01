import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class PlanEditorScreen extends ConsumerStatefulWidget {
  final String? planId;

  const PlanEditorScreen({super.key, this.planId});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _instrument = 'Guitar';
  String _difficulty = 'beginner';
  bool _published = false;
  bool _isLoading = false;
  bool _isSaved = false;
  bool _isInitialized = false;

  static const instruments = [
    'Guitar',
    'Bass',
    'Piano',
    'Drums',
    'Vocals',
    'Violin',
    'Other'
  ];
  static const difficulties = ['beginner', 'intermediate', 'advanced'];

  bool get isEditing => widget.planId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initFromPlan(Plan plan) {
    if (_isInitialized) return;
    _titleController.text = plan.title;
    _descriptionController.text = plan.description;
    _instrument = plan.instrument;
    _difficulty = plan.difficulty;
    _published = plan.published;
    _isInitialized = true;
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isSaved = false;
    });

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final userId = firebaseService.currentUser?.uid;

      if (userId == null) throw Exception('Not logged in');

      if (isEditing) {
        final plan = Plan(
          id: widget.planId!,
          teacherId: userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          instrument: _instrument,
          difficulty: _difficulty,
          published: _published,
          createdAt: DateTime.now(),
        );
        await firebaseService.updatePlan(plan);
        
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
                  Text('Plan saved!'),
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
        final plan = Plan(
          id: '',
          teacherId: userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          instrument: _instrument,
          difficulty: _difficulty,
          published: _published,
          createdAt: DateTime.now(),
        );
        final planId = await firebaseService.createPlan(plan);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Plan created!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          context.go('/teacher/plan/$planId/edit');
        }
        return;
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
          onPressed: () => context.go('/teacher/home'),
          tooltip: 'Back to My Plans',
        ),
        title: Text(isEditing ? 'Edit Plan' : 'New Plan'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _savePlan,
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
      body: isEditing
          ? _buildEditingBody()
          : _buildForm(),
    );
  }

  Widget _buildEditingBody() {
    final planAsync = ref.watch(planProvider(widget.planId!));

    return planAsync.when(
      data: (plan) {
        if (plan == null) {
          return const Center(child: Text('Plan not found'));
        }
        _initFromPlan(plan);
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
                hintText: 'e.g., Learn Slap Bass',
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
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe what students will learn',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _instrument,
              decoration: const InputDecoration(
                labelText: 'Instrument',
              ),
              items: instruments
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _instrument = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _difficulty,
              decoration: const InputDecoration(
                labelText: 'Difficulty',
              ),
              items: difficulties
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d[0].toUpperCase() + d.substring(1)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _difficulty = value);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Published'),
              subtitle: const Text('Make this plan available for assignment'),
              value: _published,
              onChanged: (value) => setState(() => _published = value),
            ),
            if (isEditing) ...[
              const Divider(height: 32),
              _SessionsSection(planId: widget.planId!),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _duplicateSession(
  BuildContext context,
  WidgetRef ref,
  String planId,
  Session original,
  int nextOrderIndex,
) async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicating session...')),
    );

    final firebaseService = ref.read(firebaseServiceProvider);
    final exercises = await firebaseService.getExercises(planId, original.id);

    // Create new session
    final newSession = Session(
      id: '',
      planId: planId,
      title: 'Duplicate of ${original.title}',
      orderIndex: nextOrderIndex,
      estMinutes: original.estMinutes,
    );
    final newSessionId = await firebaseService.createSession(planId, newSession);

    // Copy all exercises to the new session
    for (var i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      final newExercise = Exercise(
        id: '',
        sessionId: newSessionId,
        title: ex.title,
        instructions: ex.instructions,
        orderIndex: i,
        targetBpm: ex.targetBpm,
        targetSeconds: ex.targetSeconds,
        attachmentUrls: List.from(ex.attachmentUrls),
      );
      await firebaseService.createExercise(planId, newSessionId, newExercise);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Duplicated "${original.title}" with ${exercises.length} exercise(s)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error duplicating: $e')),
      );
    }
  }
}

class _SessionsSection extends ConsumerWidget {
  final String planId;

  const _SessionsSection({required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider(planId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sessions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FilledButton.icon(
              onPressed: () =>
                  context.push('/teacher/plan/$planId/session/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.playlist_add,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No sessions yet',
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
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(session.title),
                    subtitle: Text('${session.estMinutes} minutes'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _duplicateSession(
                            context,
                            ref,
                            planId,
                            session,
                            sessions.length,
                          ),
                          tooltip: 'Duplicate session',
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push(
                      '/teacher/plan/$planId/session/${session.id}',
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

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

class _TemplateExercisesSection extends ConsumerWidget {
  final String planId;
  final String sessionId;
  final String instrument; // Plan's instrument - templates are filtered by this
  final bool isCompact;
  final ScrollController? scrollController;
  final VoidCallback? onAdded;

  const _TemplateExercisesSection({
    required this.planId,
    required this.sessionId,
    required this.instrument,
    this.isCompact = false,
    this.scrollController,
    this.onAdded,
  });

  List<Widget> _buildVariantButtons(
    BuildContext context,
    WidgetRef ref,
    TemplateExercise template,
    VoidCallback? onAdded,
  ) {
    final hasB = template.variantB.instructions.isNotEmpty;
    final hasC = template.variantC.instructions.isNotEmpty;
    final variants = <(TemplateVariant v, String label)>[
      (template.variantA, 'A'),
    ];
    if (hasB) variants.add((template.variantB, 'B'));
    if (hasC) variants.add((template.variantC, 'C'));

    final children = <Widget>[];
    for (var i = 0; i < variants.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 8));
      children.add(
        Expanded(
          child: OutlinedButton(
            onPressed: () => _addFromTemplate(
              context,
              ref,
              template,
              variants[i].$1,
              variants[i].$2,
              onAdded: onAdded,
            ),
            child: Text(
              variants.length == 1 ? 'Add' : 'Variant ${variants[i].$2}',
            ),
          ),
        ),
      );
    }
    return children;
  }

  Future<void> _addFromTemplate(
    BuildContext context,
    WidgetRef ref,
    TemplateExercise template,
    TemplateVariant variant,
    String variantLabel, {
    VoidCallback? onAdded,
  }) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      
      // Get next order index
      final existingExercises = await firebaseService.getExercisesCount(
        planId,
        sessionId,
      );

      // Create exercise from template variant (include template media if any)
      final attachmentUrls = template.mediaUrl.isNotEmpty
          ? [template.mediaUrl]
          : <String>[];

      final exercise = Exercise(
        id: '',
        sessionId: sessionId,
        title: '${template.title} - $variantLabel',
        instructions: variant.instructions,
        orderIndex: existingExercises,
        targetBpm: variant.targetBpm,
        targetSeconds: variant.targetSeconds,
        attachmentUrls: attachmentUrls,
      );

      await firebaseService.createExercise(planId, sessionId, exercise);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${template.title} ($variantLabel)'),
            backgroundColor: Colors.green,
          ),
        );
        onAdded?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templateExercisesProvider(instrument));

    return templatesAsync.when(
      data: (templates) {
        if (templates.isEmpty) {
          if (isCompact) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No templates for $instrument yet',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a template to quickly add exercises to your sessions.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push('/teacher/plan/$planId/template/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create template'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact) ...[
                Text(
                  'Template Exercises',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Quickly add exercises from templates',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 16),
              ],
              ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                template.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => context.push(
                                '/teacher/plan/$planId/template/${template.id}',
                              ),
                              tooltip: 'Edit template',
                            ),
                          ],
                        ),
                        if (template.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            template.description,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: _buildVariantButtons(
                            context,
                            ref,
                            template,
                            onAdded,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ],
          ),
        );
      },
      loading: () => isCompact
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox.shrink(),
      error: (err, _) => isCompact
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                      'Error loading templates',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (err.toString().contains('index'))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Deploy Firestore indexes: firebase deploy --only firestore',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

Future<void> _confirmDeleteExercise(
  BuildContext context,
  WidgetRef ref,
  String planId,
  String sessionId,
  Exercise exercise,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete exercise?'),
      content: Text(
        'Remove "${exercise.title}" from this session? This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final firebaseService = ref.read(firebaseServiceProvider);
    await firebaseService.deleteExercise(planId, sessionId, exercise.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${exercise.title}"'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

void _showBrowseTemplatesSheet(
  BuildContext context,
  WidgetRef ref,
  String planId,
  String sessionId,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _BrowseTemplatesSheet(
        planId: planId,
        sessionId: sessionId,
        scrollController: scrollController,
      ),
    ),
  );
}

class _BrowseTemplatesSheet extends ConsumerWidget {
  final String planId;
  final String sessionId;
  final ScrollController scrollController;

  const _BrowseTemplatesSheet({
    required this.planId,
    required this.sessionId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planProvider(planId));
    final instrument = planAsync.valueOrNull?.instrument ?? 'Guitar';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Exercise Templates',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (instrument.isNotEmpty)
                      Text(
                        'For $instrument',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/teacher/plan/$planId/template/new'),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Create template'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _TemplateExercisesSection(
            planId: planId,
            sessionId: sessionId,
            instrument: instrument,
            isCompact: true,
            scrollController: scrollController,
            onAdded: () => Navigator.of(context).pop(),
          ),
        ),
      ],
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showBrowseTemplatesSheet(
                    context,
                    ref,
                    planId,
                    sessionId,
                  ),
                  icon: const Icon(Icons.grid_view),
                  label: const Text('Browse Templates'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => context.push(
                    '/teacher/plan/$planId/session/$sessionId/exercise/new',
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _confirmDeleteExercise(
                            context,
                            ref,
                            planId,
                            sessionId,
                            exercise,
                          ),
                          tooltip: 'Delete exercise',
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
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

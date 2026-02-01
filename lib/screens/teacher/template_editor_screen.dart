import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/upload_config.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

/// Editor for creating or editing exercise templates.
/// Templates are scoped to the plan's instrument.
/// TODO: In future, consider teacher-scoped templates (own only) vs official shared database.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  final String planId;
  final String? templateId; // null = create, non-null = edit

  const TemplateEditorScreen({super.key, required this.planId, this.templateId});

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  bool get isEditing => widget.templateId != null && widget.templateId!.isNotEmpty;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Variant A
  final _aInstructionsController = TextEditingController();
  final _aBpmController = TextEditingController();
  final _aMinutesController = TextEditingController();

  // Variant B
  final _bInstructionsController = TextEditingController();
  final _bBpmController = TextEditingController();
  final _bMinutesController = TextEditingController();

  // Variant C
  final _cInstructionsController = TextEditingController();
  final _cBpmController = TextEditingController();
  final _cMinutesController = TextEditingController();

  int _variantCount = 1; // 1, 2, or 3 - default 1
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isInitialized = false;
  String _mediaUrl = '';
  late final String _tempTemplateId;

  String get _templateIdForUpload => widget.templateId ?? _tempTemplateId;

  @override
  void initState() {
    super.initState();
    _tempTemplateId = const Uuid().v4();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _aInstructionsController.dispose();
    _aBpmController.dispose();
    _aMinutesController.dispose();
    _bInstructionsController.dispose();
    _bBpmController.dispose();
    _bMinutesController.dispose();
    _cInstructionsController.dispose();
    _cBpmController.dispose();
    _cMinutesController.dispose();
    super.dispose();
  }

  void _initFromTemplate(TemplateExercise t) {
    if (_isInitialized) return;
    _titleController.text = t.title;
    _descriptionController.text = t.description;
    _aInstructionsController.text = t.variantA.instructions;
    _aBpmController.text = t.variantA.targetBpm?.toString() ?? '';
    _aMinutesController.text = t.variantA.targetSeconds != null
        ? (t.variantA.targetSeconds! / 60).toString().replaceAll(RegExp(r'\.0$'), '')
        : '';
    _bInstructionsController.text = t.variantB.instructions;
    _bBpmController.text = t.variantB.targetBpm?.toString() ?? '';
    _bMinutesController.text = t.variantB.targetSeconds != null
        ? (t.variantB.targetSeconds! / 60).toString().replaceAll(RegExp(r'\.0$'), '')
        : '';
    _cInstructionsController.text = t.variantC.instructions;
    _cBpmController.text = t.variantC.targetBpm?.toString() ?? '';
    _cMinutesController.text = t.variantC.targetSeconds != null
        ? (t.variantC.targetSeconds! / 60).toString().replaceAll(RegExp(r'\.0$'), '')
        : '';
    if (t.variantC.instructions.isNotEmpty) {
      _variantCount = 3;
    } else if (t.variantB.instructions.isNotEmpty) {
      _variantCount = 2;
    } else {
      _variantCount = 1;
    }
    _mediaUrl = t.mediaUrl;
    _isInitialized = true;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'mp3', 'wav', 'm4a', 'pdf'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileName = file.name;
      final ext = fileName.split('.').last.toLowerCase();

      int fileSize = file.size;
      if (fileSize == 0 && file.bytes != null) fileSize = file.bytes!.length;

      final maxSize = UploadConfig.getMaxSizeForExtension(ext);
      if (fileSize > maxSize) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File too large. Max ${UploadConfig.formatBytes(maxSize)} for ${ext.toUpperCase()} files.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() => _isSaving = true);

      Uint8List? compressedData;
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
        compressedData = await _compressImage(file, ext);
      }

      final firebaseService = ref.read(firebaseServiceProvider);
      final downloadUrl = await firebaseService.uploadTemplateFile(
        templateId: _templateIdForUpload,
        platformFile: file,
        fileName: fileName,
        data: compressedData,
      );

      if (mounted) {
        setState(() {
          _mediaUrl = downloadUrl;
          _isSaving = false;
        });
        final saved = compressedData != null
            ? ' (compressed from ${UploadConfig.formatBytes(fileSize)})'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File uploaded$saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _compressImage(PlatformFile file, String ext) async {
    try {
      if (kIsWeb) {
        if (file.bytes == null) return null;
        final result = await FlutterImageCompress.compressWithList(
          file.bytes!,
          minWidth: UploadConfig.imageMaxWidth,
          minHeight: UploadConfig.imageMaxHeight,
          quality: UploadConfig.imageCompressQuality,
          format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
        );
        return result.isEmpty ? null : Uint8List.fromList(result);
      } else {
        if (file.path == null) return null;
        return await FlutterImageCompress.compressWithFile(
          file.path!,
          minWidth: UploadConfig.imageMaxWidth,
          minHeight: UploadConfig.imageMaxHeight,
          quality: UploadConfig.imageCompressQuality,
          format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
        );
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeMedia() async {
    if (_mediaUrl.isEmpty) return;
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.deleteExerciseFile(_mediaUrl);
    } catch (_) {}
    setState(() => _mediaUrl = '');
  }

  IconData _getFileIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.pdf')) return Icons.picture_as_pdf;
    if (lower.contains('.mp4') || lower.contains('.mov')) return Icons.video_file;
    if (lower.contains('.mp3') || lower.contains('.wav') || lower.contains('.m4a')) return Icons.audiotrack;
    return Icons.image;
  }

  TemplateVariant _variantFromControllers(
    TextEditingController instructions,
    TextEditingController bpm,
    TextEditingController minutes,
  ) {
    final bpmVal = int.tryParse(bpm.text);
    final minutesVal = double.tryParse(minutes.text);
    final secondsVal =
        minutesVal != null && minutesVal > 0 ? (minutesVal * 60).round() : null;
    return TemplateVariant(
      instructions: instructions.text.trim(),
      targetBpm: bpmVal,
      targetSeconds: secondsVal,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final plan = await firebaseService.getPlan(widget.planId);
      if (plan == null) throw Exception('Plan not found');
      final instrument = plan.instrument;

      final template = TemplateExercise(
        id: widget.templateId ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        instrument: instrument,
        mediaUrl: _mediaUrl,
        variantA: _variantFromControllers(
          _aInstructionsController,
          _aBpmController,
          _aMinutesController,
        ),
        variantB: _variantCount >= 2
            ? _variantFromControllers(
                _bInstructionsController,
                _bBpmController,
                _bMinutesController,
              )
            : TemplateVariant(instructions: ''),
        variantC: _variantCount >= 3
            ? _variantFromControllers(
                _cInstructionsController,
                _cBpmController,
                _cMinutesController,
              )
            : TemplateVariant(instructions: ''),
        createdAt: DateTime.now(),
      );

      if (isEditing) {
        await firebaseService.updateTemplateExercise(template);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Template updated!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } else {
        await firebaseService.createTemplateExercise(template);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Template created!'),
                ],
              ),
              backgroundColor: Colors.green,
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
    final planAsync = ref.watch(planProvider(widget.planId));
    final instrument = planAsync.valueOrNull?.instrument ?? '';
    final templateAsync = isEditing
        ? ref.watch(templateExerciseProvider(widget.templateId!))
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEditing ? 'Edit Template' : 'Create Template'),
            if (instrument.isNotEmpty)
              Text(
                'For $instrument',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: templateAsync != null
          ? templateAsync.when(
              data: (template) {
                if (template != null) _initFromTemplate(template);
                return _buildForm();
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            )
          : _buildForm(),
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
                  labelText: 'Template title',
                  hintText: 'e.g., Scales - C major',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Brief note about when to use this template',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Text(
                'Media (optional)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'One file for all variants: image, video, audio, or PDF',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickFile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isSaving ? 'Uploading...' : (_mediaUrl.isEmpty ? 'Add media' : 'Replace media')),
              ),
              if (_mediaUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Icon(_getFileIcon(_mediaUrl)),
                    title: Text(
                      _mediaUrl.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _removeMedia,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Number of variants',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1'), icon: Icon(Icons.looks_one)),
                  ButtonSegment(value: 2, label: Text('2'), icon: Icon(Icons.looks_two)),
                  ButtonSegment(value: 3, label: Text('3'), icon: Icon(Icons.looks_3)),
                ],
                selected: {_variantCount},
                onSelectionChanged: (selected) {
                  setState(() => _variantCount = selected.first);
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Variant A',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              _buildVariantFields(
                instructions: _aInstructionsController,
                bpm: _aBpmController,
                minutes: _aMinutesController,
                hint: 'Instructions',
              ),
              if (_variantCount >= 2) ...[
                const SizedBox(height: 20),
                Text(
                  'Variant B',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _buildVariantFields(
                  instructions: _bInstructionsController,
                  bpm: _bBpmController,
                  minutes: _bMinutesController,
                  hint: 'Instructions',
                ),
              ],
              if (_variantCount >= 3) ...[
                const SizedBox(height: 20),
                Text(
                  'Variant C',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _buildVariantFields(
                  instructions: _cInstructionsController,
                  bpm: _cBpmController,
                  minutes: _cMinutesController,
                  hint: 'Instructions',
                ),
              ],
            ],
          ),
        ),
    );
  }

  Widget _buildVariantFields({
    required TextEditingController instructions,
    required TextEditingController bpm,
    required TextEditingController minutes,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        TextFormField(
          controller: instructions,
          decoration: InputDecoration(
            labelText: 'Instructions',
            hintText: hint,
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: bpm,
                decoration: const InputDecoration(
                  labelText: 'Target BPM',
                  hintText: '80',
                  suffixText: 'BPM',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: minutes,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  hintText: '2',
                  suffixText: 'min',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

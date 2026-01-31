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
  List<String> _attachmentUrls = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSaved = false;
  bool _isInitialized = false;
  int _currentOrderIndex = 0;
  late final String _tempExerciseId; // For file uploads before exercise is created

  bool get isEditing => widget.exerciseId != null;
  
  String get _exerciseIdForUpload => widget.exerciseId ?? _tempExerciseId;
  
  @override
  void initState() {
    super.initState();
    // Generate UUID for new exercises (for file uploads)
    if (!isEditing) {
      _tempExerciseId = const Uuid().v4();
    } else {
      _tempExerciseId = '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _bpmController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _initFromExercise(Exercise exercise) {
    if (_isInitialized) return;
    _titleController.text = exercise.title;
    _instructionsController.text = exercise.instructions;
    _bpmController.text = exercise.targetBpm?.toString() ?? '';
    // Store minutes in UI (convert from seconds)
    _secondsController.text = exercise.targetSeconds != null
        ? (exercise.targetSeconds! / 60).toString().replaceAll(RegExp(r'\.0$'), '')
        : '';
    _attachmentUrls = List.from(exercise.attachmentUrls);
    _currentOrderIndex = exercise.orderIndex;
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

      // Get file size
      int fileSize = file.size;
      if (fileSize == 0 && file.bytes != null) {
        fileSize = file.bytes!.length;
      }

      // Check size limit
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

      final firebaseService = ref.read(firebaseServiceProvider);
      final exerciseId = _exerciseIdForUpload;

      Uint8List? compressedData;
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
        compressedData = await _compressImage(file, ext);
      }

      final downloadUrl = await firebaseService.uploadExerciseFile(
        planId: widget.planId,
        sessionId: widget.sessionId,
        exerciseId: exerciseId,
        platformFile: file,
        fileName: fileName,
        data: compressedData,
      );

      if (mounted) {
        setState(() {
          _attachmentUrls.add(downloadUrl);
          _isSaving = false;
        });
        final saved = compressedData != null
            ? ' (compressed from ${UploadConfig.formatBytes(fileSize)})'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ext == 'mov'
                  ? 'File uploaded$saved. Tip: MP4 plays more reliably in browsers than MOV.'
                  : 'File uploaded$saved',
            ),
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
        final result = await FlutterImageCompress.compressWithFile(
          file.path!,
          minWidth: UploadConfig.imageMaxWidth,
          minHeight: UploadConfig.imageMaxHeight,
          quality: UploadConfig.imageCompressQuality,
          format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
        );
        return result;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeFile(int index) async {
    final url = _attachmentUrls[index];
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.deleteExerciseFile(url);
      setState(() {
        _attachmentUrls.removeAt(index);
      });
    } catch (e) {
      // Even if delete fails, remove from list
      setState(() {
        _attachmentUrls.removeAt(index);
      });
    }
  }

  IconData _getFileIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.jpg') || lower.contains('.jpeg') || 
        lower.contains('.png') || lower.contains('.gif')) {
      return Icons.image;
    } else if (lower.contains('.mp4') || lower.contains('.mov') || 
               lower.contains('.avi')) {
      return Icons.videocam;
    } else if (lower.contains('.mp3') || lower.contains('.wav') || 
               lower.contains('.m4a')) {
      return Icons.audiotrack;
    } else if (lower.contains('.pdf')) {
      return Icons.picture_as_pdf;
    }
    return Icons.attach_file;
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
        id: widget.exerciseId ?? _tempExerciseId,
        sessionId: widget.sessionId,
        title: _titleController.text.trim(),
        instructions: _instructionsController.text.trim(),
        orderIndex: orderIndex,
        targetBpm: int.tryParse(_bpmController.text),
        targetSeconds: () {
          final minutes = double.tryParse(_secondsController.text);
          return minutes != null && minutes > 0
              ? (minutes * 60).round()
              : null;
        }(),
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
                hintText: 'e.g. 2',
                suffixText: 'min',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            Text(
              'Attachments',
              style: Theme.of(context).textTheme.titleMedium,
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
              label: Text(_isSaving ? 'Uploading...' : 'Add File (Image/Video/Audio/PDF)'),
            ),
            const SizedBox(height: 8),
            if (_attachmentUrls.isNotEmpty) ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attachmentUrls.length,
                itemBuilder: (context, index) {
                  final url = _attachmentUrls[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      leading: Icon(_getFileIcon(url)),
                      title: Text(
                        url.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeFile(index),
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

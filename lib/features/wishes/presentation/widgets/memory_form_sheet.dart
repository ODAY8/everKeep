import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/pick_upload.dart';
import '../../../../models/document_upload.dart';
import '../../../../models/memory_item.dart';
import '../../../../models/memory_media_item.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../services/memory_service.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../../../widgets/glass/glass_sheet.dart';
import '../services/memory_media_picker.dart';
import 'audio_recorder_adapter.dart';
import 'memory_media_tray.dart';

/// A polished glass bottom sheet for creating or editing a Memory or Wish.
/// Validates required fields, provides saving/loading states, handles errors
/// gracefully, supports rich multi-media selection (photos, video, audio),
/// in-app audio recording, reordering, captions, and preserves legacy attachments.
class MemoryFormSheet extends StatefulWidget {
  final MemoryItem? initialItem;
  final String initialType;
  final DocumentUpload? initialUpload;
  final MemoryMediaPicker? mediaPicker;
  final AudioRecorderAdapterFactory? recorderFactory;

  const MemoryFormSheet({
    super.key,
    this.initialItem,
    this.initialType = 'memory',
    this.initialUpload,
    this.mediaPicker,
    this.recorderFactory,
  });

  /// Displays the form sheet in the current context.
  static Future<bool?> show(
    BuildContext context, {
    MemoryItem? item,
    String type = 'memory',
    DocumentUpload? initialUpload,
    MemoryMediaPicker? mediaPicker,
    AudioRecorderAdapterFactory? recorderFactory,
  }) {
    return showGlassSheet<bool>(
      context,
      builder: (_) => MemoryFormSheet(
        initialItem: item,
        initialType: item?.type ?? type,
        initialUpload: initialUpload,
        mediaPicker: mediaPicker,
        recorderFactory: recorderFactory,
      ),
    );
  }

  @override
  State<MemoryFormSheet> createState() => _MemoryFormSheetState();
}

class _MemoryFormSheetState extends State<MemoryFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _locationController;
  late final TextEditingController _tagsController;

  late final MemoryMediaPicker _mediaPicker;
  late final AudioRecorderAdapter _audioRecorder;

  DateTime? _selectedDate;
  DocumentUpload? _pendingLegacyUpload;
  bool _legacyAttachmentRemoved = false;

  final List<FormMediaItem> _mediaItems = [];
  bool _saving = false;
  String? _uploadStatus;
  String? _errorMessage;

  // Audio recording state
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  bool get _isEditing => widget.initialItem != null;
  String get _type => widget.initialType;
  bool get _isMemory => _type.toLowerCase() == 'memory';
  String get _label => _isMemory ? 'Memory' : 'Wish';

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _contentController = TextEditingController(text: item?.content ?? '');
    _locationController = TextEditingController(text: item?.location ?? '');
    _tagsController = TextEditingController(text: item?.tags ?? '');
    _selectedDate = item?.date;
    _pendingLegacyUpload = widget.initialUpload;

    _mediaPicker = widget.mediaPicker ?? DefaultMemoryMediaPicker();
    final factory = widget.recorderFactory ?? () => DefaultAudioRecorderAdapter();
    _audioRecorder = factory();

    // Populate existing media if editing
    if (item != null && item.media.isNotEmpty) {
      for (final m in item.media) {
        _mediaItems.add(FormMediaItem.existing(m));
      }
    }

    // Populate initial upload if provided
    if (widget.initialUpload != null) {
      final upload = widget.initialUpload!;
      final type =
          MemoryServiceImpl.detectMediaType(upload.mimeType, upload.fileName);
      _mediaItems.add(
        FormMediaItem.pending(
          pendingUpload: upload,
          mediaType: type,
          previewBytes: type == MemoryMediaType.photo ? upload.bytes : null,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _tagsController.dispose();
    _recordTimer?.cancel();
    if (_isRecording) {
      _audioRecorder.cancel();
    }
    _audioRecorder.dispose();
    super.dispose();
  }

  void _addPendingMedia(List<FormMediaItem> newItems) {
    var addedCount = 0;
    for (final item in newItems) {
      final isDuplicate = _mediaItems.any((existing) =>
          existing.fileName == item.fileName &&
          existing.fileSize == item.fileSize);
      if (!isDuplicate) {
        _mediaItems.add(item);
        addedCount++;
      }
    }
    if (addedCount < newItems.length && mounted) {
      showAppSnackBar(
        context,
        'Duplicate media items were skipped.',
      );
    }
    setState(() {});
  }

  Future<void> _pickPhotos() async {
    try {
      final uploads = await _mediaPicker.pickPhotos();
      if (uploads.isNotEmpty && mounted) {
        final items = uploads
            .map(
              (u) => FormMediaItem.pending(
                pendingUpload: u,
                mediaType: MemoryMediaType.photo,
                previewBytes: u.bytes,
              ),
            )
            .toList();
        _addPendingMedia(items);
      }
    } on PickedTooLarge catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Couldn\'t read the selected photo(s). Try another.',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final upload = await _mediaPicker.pickVideo();
      if (upload != null && mounted) {
        _addPendingMedia([
          FormMediaItem.pending(
            pendingUpload: upload,
            mediaType: MemoryMediaType.video,
          ),
        ]);
      }
    } on PickedTooLarge catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Couldn\'t read the selected video. Try another.',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickAudio() async {
    try {
      final upload = await _mediaPicker.pickAudio();
      if (upload != null && mounted) {
        _addPendingMedia([
          FormMediaItem.pending(
            pendingUpload: upload,
            mediaType: MemoryMediaType.audio,
          ),
        ]);
      }
    } on PickedTooLarge catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Couldn\'t read the audio file. Try another.',
          isError: true,
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          showAppSnackBar(
            context,
            'Microphone permission is required to record audio.',
            isError: true,
          );
        }
        return;
      }

      await _audioRecorder.start();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
      }

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordDuration++);
        }
      });
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not start audio recording.',
          isError: true,
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final duration = _recordDuration;
    try {
      final upload = await _audioRecorder.stop(durationSeconds: duration);
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordDuration = 0;
        });
      }

      if (upload != null && mounted) {
        _addPendingMedia([
          FormMediaItem.pending(
            pendingUpload: upload,
            mediaType: MemoryMediaType.audio,
            durationSeconds: duration > 0 ? duration : null,
          ),
        ]);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordDuration = 0;
        });
        showAppSnackBar(
          context,
          'Failed to complete audio recording.',
          isError: true,
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _audioRecorder.cancel();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });
    }
  }

  void _moveMediaUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _mediaItems.removeAt(index);
        _mediaItems.insert(index - 1, item);
      });
    }
  }

  void _moveMediaDown(int index) {
    if (index < _mediaItems.length - 1) {
      setState(() {
        final item = _mediaItems.removeAt(index);
        _mediaItems.insert(index + 1, item);
      });
    }
  }

  void _removeMediaItem(int index) {
    setState(() {
      _mediaItems.removeAt(index);
    });
  }

  void _onCaptionChanged(int index, String? caption) {
    if (index >= 0 && index < _mediaItems.length) {
      _mediaItems[index].caption = caption;
    }
  }

  Future<void> _pickLegacyFile() async {
    try {
      final upload = await pickDocument();
      if (upload != null && mounted) {
        setState(() {
          _pendingLegacyUpload = upload;
          _legacyAttachmentRemoved = false;
        });
      }
    } on PickedTooLarge catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Couldn\'t read that file. Try another one.',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 20),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.glassAccentPink,
              surface: AppColors.glassSurfaceRaised,
              onSurface: AppColors.glassOnSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
      _uploadStatus = 'Saving details...';
    });

    final memoryProv = context.read<MemoryProvider>();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final location = _locationController.text.trim();
    final tags = _tagsController.text.trim();

    try {
      bool success = false;
      if (_isEditing) {
        final updated = widget.initialItem!.copyWith(
          title: title,
          content: content,
          date: _selectedDate,
          location: location.isEmpty ? null : location,
          tags: tags.isEmpty ? null : tags,
        );
        success = await memoryProv.updateMemory(updated);

        if (!success) {
          if (mounted) {
            setState(() {
              _errorMessage = memoryProv.error ?? 'Could not update $_label.';
              _saving = false;
            });
          }
          return;
        }

        // 1. Legacy attachment handling
        if (_legacyAttachmentRemoved) {
          await memoryProv.removeAttachment(widget.initialItem!.id);
        } else if (_pendingLegacyUpload != null) {
          await memoryProv.uploadAttachment(
            widget.initialItem!.id,
            _pendingLegacyUpload!,
          );
        }

        // 2. Delete removed existing media
        final initialIds = widget.initialItem!.media.map((m) => m.id).toSet();
        final currentExistingIds = _mediaItems
            .where((item) => item.isExisting)
            .map((item) => item.existingItem!.id)
            .toSet();
        final toDeleteIds = initialIds.difference(currentExistingIds);
        for (final id in toDeleteIds) {
          if (mounted) {
            setState(() => _uploadStatus = 'Updating media...');
          }
          await memoryProv.deleteMedia(id);
        }

        // 3. Add newly picked pending media
        final pendingItems =
            _mediaItems.where((item) => item.isPending).toList();
        for (var i = 0; i < pendingItems.length; i++) {
          final item = pendingItems[i];
          if (mounted) {
            setState(() {
              _uploadStatus =
                  'Uploading media (${i + 1} of ${pendingItems.length})...';
            });
          }
          await memoryProv.addMedia(
            widget.initialItem!.id,
            item.pendingUpload!,
            caption: item.caption,
            displayOrder: _mediaItems.indexOf(item),
            durationSeconds: item.durationSeconds,
          );
        }

        // 4. Update reordering for remaining existing media
        final remainingExistingIds = _mediaItems
            .where((item) => item.isExisting)
            .map((item) => item.existingItem!.id)
            .toList();
        if (remainingExistingIds.isNotEmpty) {
          await memoryProv.reorderMedia(
            widget.initialItem!.id,
            remainingExistingIds,
          );
        }

        success = true;
      } else {
        // Create Mode
        final newItem = MemoryItem(
          id: '',
          title: title,
          content: content,
          type: _type,
          date: _selectedDate,
          location: location.isEmpty ? null : location,
          tags: tags.isEmpty ? null : tags,
        );

        final pendingItems =
            _mediaItems.where((item) => item.isPending).toList();
        if (pendingItems.isNotEmpty) {
          final uploads =
              pendingItems.map((item) => item.pendingUpload!).toList();
          final captions =
              pendingItems.map((item) => item.caption ?? '').toList();
          final durations =
              pendingItems.map((item) => item.durationSeconds).toList();

          if (mounted) {
            setState(() {
              _uploadStatus = 'Uploading ${uploads.length} media items...';
            });
          }
          success = await memoryProv.createMemoryWithMedia(
            newItem,
            uploads,
            captions: captions,
            durations: durations,
          );
        } else {
          success = await memoryProv.createMemory(
            newItem,
            upload: _pendingLegacyUpload,
          );
        }
      }

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = memoryProv.error ?? 'Could not save $_label.';
          _saving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPendingOrNewMedia =
        _mediaItems.any((m) => m.isPending) || _pendingLegacyUpload != null;
    final submitText = _isEditing
        ? 'Save Changes'
        : (hasPendingOrNewMedia ? 'Upload & Save' : 'Save');

    return PopScope(
      canPop: !_saving,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                _isEditing ? 'Edit $_label' : 'Add $_label',
                style: AppTextStyles.serifHeadline.copyWith(
                  color: AppColors.glassOnSurface,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isEditing
                    ? 'Update your details below.'
                    : (_isMemory
                        ? 'Keep a memory worth holding on to.'
                        : 'Write down a wish for the people you love.'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
              ),
              const SizedBox(height: 18),

              // Error Banner
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.glassDestructive.withValues(alpha: 0.15),
                    borderRadius: AppRadius.radiusMD,
                    border: Border.all(
                      color: AppColors.glassDestructive.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.glassDestructive,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.glassDestructive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Title field
              _FormFieldWrapper(
                label: 'Title',
                child: TextFormField(
                  controller: _titleController,
                  enabled: !_saving,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurface,
                  ),
                  decoration: _inputDecoration(
                    hintText: _isMemory
                        ? 'e.g. Our trip to the coast'
                        : 'e.g. For my daughter',
                  ),
                  validator: (v) {
                    final trimmed = (v ?? '').trim();
                    if (trimmed.isEmpty) return 'Title is required';
                    if (trimmed.length > 300) {
                      return 'Keep the title under 300 characters.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Story / Description field
              _FormFieldWrapper(
                label: _isMemory ? 'What happened' : 'Your wish',
                child: TextFormField(
                  controller: _contentController,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurface,
                  ),
                  decoration: _inputDecoration(
                    hintText: _isMemory
                        ? 'Write as much or as little as you like...'
                        : 'What you\'d like them to know...',
                  ),
                  validator: (v) {
                    if ((v ?? '').length > 10000) {
                      return 'Keep it under 10,000 characters.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Date Field
              _FormFieldWrapper(
                label: 'Date (optional)',
                child: GestureDetector(
                  onTap: _saving ? null : _pickDate,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurface,
                      borderRadius: AppRadius.radiusMD,
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedDate != null
                                ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                                : 'Select date...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: _selectedDate != null
                                  ? AppColors.glassOnSurface
                                  : AppColors.glassOnSurfaceFaint,
                            ),
                          ),
                        ),
                        if (_selectedDate != null && !_saving)
                          GestureDetector(
                            onTap: () => setState(() => _selectedDate = null),
                            child: const Icon(
                              Icons.clear_rounded,
                              size: 16,
                              color: AppColors.glassOnSurfaceMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Location (Memory only)
              if (_isMemory) ...[
                _FormFieldWrapper(
                  label: 'Location (optional)',
                  child: TextFormField(
                    controller: _locationController,
                    enabled: !_saving,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.glassOnSurface,
                    ),
                    decoration: _inputDecoration(
                      hintText: 'e.g. Kyoto, Japan',
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.glassOnSurfaceMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Tags (Memory only)
              if (_isMemory) ...[
                _FormFieldWrapper(
                  label: 'Tags (optional)',
                  child: TextFormField(
                    controller: _tagsController,
                    enabled: !_saving,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.glassOnSurface,
                    ),
                    decoration: _inputDecoration(
                      hintText: 'e.g. Travel, Family, Milestone',
                      prefixIcon: const Icon(
                        Icons.tag_rounded,
                        size: 18,
                        color: AppColors.glassOnSurfaceMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Legacy Attachment Card (if present)
              if (_isEditing &&
                  widget.initialItem?.hasAttachment == true &&
                  !_legacyAttachmentRemoved) ...[
                _FormFieldWrapper(
                  label: 'Legacy Attachment',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurfaceRaised,
                      borderRadius: AppRadius.radiusMD,
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.initialItem!.isPhotoAttachment
                              ? Icons.photo_outlined
                              : Icons.attach_file_rounded,
                          color: AppColors.glassAccentPink,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pendingLegacyUpload != null
                                ? 'Replacing with: ${_pendingLegacyUpload!.fileName}'
                                : 'Existing attachment preserved',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.glassOnSurfaceMuted,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _saving ? null : _pickLegacyFile,
                          child: const Text('Replace'),
                        ),
                        IconButton(
                          tooltip: 'Remove legacy attachment',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.glassDestructive,
                          ),
                          onPressed: _saving
                              ? null
                              : () => setState(
                                    () => _legacyAttachmentRemoved = true,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // MEDIA Section
              _FormFieldWrapper(
                label: 'MEDIA (Photos, Videos & Audio)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MediaActionButton(
                          icon: Icons.add_photo_alternate_outlined,
                          label: 'Add Photos',
                          onPressed: _saving ? null : _pickPhotos,
                        ),
                        _MediaActionButton(
                          icon: Icons.video_library_outlined,
                          label: 'Add Video',
                          onPressed: _saving ? null : _pickVideo,
                        ),
                        _MediaActionButton(
                          icon: Icons.audio_file_outlined,
                          label: 'Add Audio',
                          onPressed: _saving ? null : _pickAudio,
                        ),
                        _MediaActionButton(
                          icon: Icons.mic_none_rounded,
                          label: 'Record Audio',
                          onPressed:
                              _saving || _isRecording ? null : _startRecording,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Voice Recording Panel
                    if (_isRecording) ...[
                      VoiceRecordingPanel(
                        durationSeconds: _recordDuration,
                        onStop: _stopRecording,
                        onCancel: _cancelRecording,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Media Tray
                    MemoryMediaTray(
                      items: _mediaItems,
                      onMoveUp: _moveMediaUp,
                      onMoveDown: _moveMediaDown,
                      onRemove: _removeMediaItem,
                      onCaptionChanged: _onCaptionChanged,
                      enabled: !_saving,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Upload / Save Progress
              if (_saving && _uploadStatus != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurfaceRaised,
                    borderRadius: AppRadius.radiusMD,
                    border: Border.all(
                      color: AppColors.glassAccentPink.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.glassAccentPink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _uploadStatus!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.glassOnSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(
                        backgroundColor: AppColors.glassSurface,
                        color: AppColors.glassAccentPink,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit Button
              GlassPrimaryButton(
                text: _saving ? 'Saving...' : submitText,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.glassOnSurfaceFaint,
      ),
      filled: true,
      fillColor: AppColors.glassSurface,
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: const BorderSide(color: AppColors.glassAccentPink),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMD,
        borderSide: const BorderSide(color: AppColors.glassDestructive),
      ),
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _MediaActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: AppColors.glassAccentPink),
      label: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: onPressed != null
              ? AppColors.glassOnSurface
              : AppColors.glassOnSurfaceFaint,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.glassOnSurface,
        side: const BorderSide(color: AppColors.glassBorder),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FormFieldWrapper extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormFieldWrapper({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.glassOnSurfaceMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

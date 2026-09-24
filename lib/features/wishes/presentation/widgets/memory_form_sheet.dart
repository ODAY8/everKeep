import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/pick_upload.dart';
import '../../../../models/document_upload.dart';
import '../../../../models/memory_item.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../../../widgets/glass/glass_sheet.dart';

/// A polished glass bottom sheet for creating or editing a Memory or Wish.
/// Validates required fields, provides saving/loading states, handles errors
/// gracefully, and supports attaching/replacing media.
class MemoryFormSheet extends StatefulWidget {
  final MemoryItem? initialItem;
  final String initialType;
  final DocumentUpload? initialUpload;

  const MemoryFormSheet({
    super.key,
    this.initialItem,
    this.initialType = 'memory',
    this.initialUpload,
  });

  /// Displays the form sheet in the current context.
  static Future<bool?> show(
    BuildContext context, {
    MemoryItem? item,
    String type = 'memory',
    DocumentUpload? initialUpload,
  }) {
    return showGlassSheet<bool>(
      context,
      builder: (_) => MemoryFormSheet(
        initialItem: item,
        initialType: item?.type ?? type,
        initialUpload: initialUpload,
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

  DateTime? _selectedDate;
  DocumentUpload? _pendingUpload;
  bool _saving = false;
  String? _errorMessage;

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
    _pendingUpload = widget.initialUpload;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final upload = await pickDocument();
      if (upload != null && mounted) {
        setState(() {
          _pendingUpload = upload;
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
    });

    final memoryProv = context.read<MemoryProvider>();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final location = _locationController.text.trim();
    final tags = _tagsController.text.trim();

    try {
      bool success;
      if (_isEditing) {
        final updated = widget.initialItem!.copyWith(
          title: title,
          content: content,
          date: _selectedDate,
          location: location.isEmpty ? null : location,
          tags: tags.isEmpty ? null : tags,
        );
        success = await memoryProv.updateMemory(updated);

        // If a new attachment was picked while editing
        if (success && _pendingUpload != null) {
          success = await memoryProv.uploadAttachment(
            widget.initialItem!.id,
            _pendingUpload!,
          );
        }
      } else {
        final newItem = MemoryItem(
          id: '',
          title: title,
          content: content,
          type: _type,
          date: _selectedDate,
          location: location.isEmpty ? null : location,
          tags: tags.isEmpty ? null : tags,
        );
        success = await memoryProv.createMemory(
          newItem,
          upload: _pendingUpload,
        );
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
    final submitText = _isEditing
        ? 'Save Changes'
        : (_pendingUpload != null ? 'Upload & Save' : 'Save');

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

              // Title field (first TextField for tests)
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

              // Attachment / Photo section
              _FormFieldWrapper(
                label: 'Photo or Attachment (optional)',
                child: _buildAttachmentPicker(),
              ),
              const SizedBox(height: 24),

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

  Widget _buildAttachmentPicker() {
    if (_pendingUpload != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glassSurfaceRaised,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(
            color: AppColors.glassAccentPink.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.attach_file_rounded,
              color: AppColors.glassAccentPink,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pendingUpload!.fileName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${(_pendingUpload!.bytes.length / 1024).toStringAsFixed(1)} KB',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.glassOnSurfaceMuted,
                size: 18,
              ),
              onPressed: _saving
                  ? null
                  : () => setState(() => _pendingUpload = null),
            ),
          ],
        ),
      );
    }

    if (_isEditing && widget.initialItem?.hasAttachment == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                'Existing attachment preserved',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : _pickFile,
              child: const Text('Replace'),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _saving ? null : _pickFile,
      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
      label: const Text('Add photo or file'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.glassOnSurface,
        side: const BorderSide(color: AppColors.glassBorder),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

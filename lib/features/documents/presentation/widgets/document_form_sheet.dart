import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/document_expiration.dart';
import '../../../../core/utils/pick_upload.dart';
import '../../../../models/document_item.dart';
import '../../../../models/document_type.dart';
import '../../../../models/document_upload.dart';
import '../../../../providers/document_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_primary_button.dart';

/// Modal bottom sheet for creating or editing a document in the vault.
///
/// Features dynamic metadata adaptation per [DocumentType], inline file
/// selection/removal, date pickers, validation, and error recovery.
class DocumentFormSheet extends StatefulWidget {
  final DocumentItem? initialDocument;
  final DocumentUpload? initialUpload;

  const DocumentFormSheet({
    super.key,
    this.initialDocument,
    this.initialUpload,
  });

  /// Displays the document form in a modal bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    DocumentItem? document,
    DocumentUpload? initialUpload,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => DocumentFormSheet(
        initialDocument: document,
        initialUpload: initialUpload,
      ),
    );
  }

  @override
  State<DocumentFormSheet> createState() => _DocumentFormSheetState();
}

class _DocumentFormSheetState extends State<DocumentFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _numberController;
  late final TextEditingController _countryController;
  late final TextEditingController _institutionController;
  late final TextEditingController _notesController;

  late DocumentType _selectedType;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  DocumentUpload? _upload;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialDocument != null;

  @override
  void initState() {
    super.initState();
    final doc = widget.initialDocument;
    _upload = widget.initialUpload;

    _selectedType = doc != null
        ? doc.typeInfo
        : DocumentType.passport;

    _titleController = TextEditingController(
      text: doc?.title ?? (_upload?.fileName ?? ''),
    );
    _numberController = TextEditingController(text: doc?.documentNumber ?? '');
    _countryController = TextEditingController(text: doc?.country ?? '');
    _institutionController = TextEditingController(text: doc?.institution ?? '');
    _notesController = TextEditingController(text: doc?.notes ?? '');

    _issueDate = doc?.issueDate;
    _expiryDate = doc?.expiryDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    _countryController.dispose();
    _institutionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final picked = await pickDocument();
      if (picked != null && mounted) {
        setState(() {
          _upload = picked;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = picked.fileName;
          }
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

  Future<void> _pickDate({
    required BuildContext context,
    required bool isExpiry,
  }) async {
    final now = DateTime.now();
    final initialDate = isExpiry
        ? (_expiryDate ?? now.add(const Duration(days: 365)))
        : (_issueDate ?? now);

    final firstDate = isExpiry
        ? DateTime(now.year - 20)
        : DateTime(1900);
    final lastDate = isExpiry
        ? DateTime(now.year + 40)
        : DateTime(now.year + 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.glassAccentPink,
              onPrimary: AppColors.glassOnSurface,
              surface: AppColors.glassSurface,
              onSurface: AppColors.glassOnSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _issueDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Document name is required';
      });
      return;
    }
    final number = _numberController.text.trim();
    final country = _countryController.text.trim();
    final institution = _institutionController.text.trim();
    final notes = _notesController.text.trim();
    final docProv = context.read<DocumentProvider>();
    bool success = false;

    if (_isEditing) {
      final original = widget.initialDocument!;
      final updated = original.copyWith(
        title: title,
        category: _selectedType.defaultCategory,
        documentType: _selectedType.code,
        documentNumber: number.isNotEmpty ? number : null,
        country: country.isNotEmpty ? country : null,
        institution: institution.isNotEmpty ? institution : null,
        notes: notes.isNotEmpty ? notes : null,
        description: notes.isNotEmpty ? notes : null,
        issueDate: _issueDate,
        expiryDate: _expiryDate,
      );
      success = await docProv.updateDocument(updated);
    } else {
      final newDoc = DocumentItem(
        id: '',
        title: title,
        subtitle: '',
        category: _selectedType.defaultCategory,
        documentType: _selectedType.code,
        documentNumber: number.isNotEmpty ? number : null,
        country: country.isNotEmpty ? country : null,
        institution: institution.isNotEmpty ? institution : null,
        notes: notes.isNotEmpty ? notes : null,
        issueDate: _issueDate,
        expiryDate: _expiryDate,
      );
      success = await docProv.addDocument(newDoc, upload: _upload);
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = docProv.error ?? 'Could not save the document. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height - topPadding - 24,
      ),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.glassBorder,
                    borderRadius: AppRadius.radiusPill,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Sheet header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      _selectedType.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Document' : 'Add Document',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.glassOnSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _isEditing
                                ? 'Update document records & expiration'
                                : 'Store identity, legal, or personal records',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.glassOnSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.glassOnSurfaceMuted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.glassBorder, height: 20),

              // Scrollable form body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error message banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.glassDestructive.withValues(alpha: 0.12),
                              borderRadius: AppRadius.radiusMD,
                              border: Border.all(
                                color: AppColors.glassDestructive.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.glassDestructive,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.glassDestructive,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Document Type Dropdown
                        _buildSectionLabel('DOCUMENT TYPE'),
                        const SizedBox(height: 6),
                        _buildTypeDropdown(),
                        const SizedBox(height: 16),

                        // Document Title
                        _buildSectionLabel('TITLE *'),
                        const SizedBox(height: 6),
                        _buildTextFormField(
                          controller: _titleController,
                          hint: 'e.g. My Passport, Diploma, Health Policy',
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Document name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Document Number & Country (Row)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel(
                                    _selectedType.numberLabel.toUpperCase(),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildTextFormField(
                                    controller: _numberController,
                                    hint: _selectedType.numberHint,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel(
                                    _selectedType.countryLabel.toUpperCase(),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildTextFormField(
                                    controller: _countryController,
                                    hint: 'e.g. Somalia',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Institution / Authority
                        _buildSectionLabel(
                          _selectedType.institutionLabel.toUpperCase(),
                        ),
                        const SizedBox(height: 6),
                        _buildTextFormField(
                          controller: _institutionController,
                          hint: 'e.g. Government Agency, Oxford, Allianz',
                        ),
                        const SizedBox(height: 16),

                        // Dates Section
                        _buildSectionLabel('IMPORTANT DATES'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateTile(
                                label: 'Issue date',
                                date: _issueDate,
                                icon: Icons.event_available_outlined,
                                onTap: () => _pickDate(
                                  context: context,
                                  isExpiry: false,
                                ),
                                onClear: _issueDate != null
                                    ? () => setState(() => _issueDate = null)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateTile(
                                label: 'Expiry date',
                                date: _expiryDate,
                                icon: Icons.schedule_rounded,
                                onTap: () => _pickDate(
                                  context: context,
                                  isExpiry: true,
                                ),
                                onClear: _expiryDate != null
                                    ? () => setState(() => _expiryDate = null)
                                    : null,
                                isExpiry: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // File Attachment Section
                        _buildSectionLabel('ATTACHED FILE'),
                        const SizedBox(height: 6),
                        _buildFilePickerSection(),
                        const SizedBox(height: 16),

                        // Notes Section
                        _buildSectionLabel('NOTES (OPTIONAL)'),
                        const SizedBox(height: 6),
                        _buildTextFormField(
                          controller: _notesController,
                          hint: 'Add reminders, details, or recovery instructions...',
                          maxLines: 3,
                          minLines: 2,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),

              // Pinned Bottom Actions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.glassBorder, width: 1),
                  ),
                ),
                child: GlassPrimaryButton(
                  text: _isSubmitting
                      ? 'Saving...'
                      : (_isEditing
                          ? 'Save Changes'
                          : (_upload == null
                              ? 'Add Document'
                              : 'Upload & Add')),
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.glassOnSurfaceFaint,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DocumentType>(
          value: _selectedType,
          isExpanded: true,
          dropdownColor: AppColors.glassSurface,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.glassOnSurfaceMuted,
          ),
          onChanged: (newType) {
            if (newType == null) return;
            setState(() {
              _selectedType = newType;
              if (!_isEditing &&
                  (_titleController.text.trim().isEmpty ||
                      DocumentType.values.any((t) => t.label == _titleController.text.trim()))) {
                _titleController.text = newType.label;
              }
            });
          },
          items: DocumentType.values.map((type) {
            return DropdownMenuItem<DocumentType>(
              value: type,
              child: Row(
                children: [
                  Text(type.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(
                    type.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.glassOnSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.glassOnSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.glassOnSurfaceFaint,
        ),
        filled: true,
        fillColor: AppColors.glassSurface,
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
          borderSide: const BorderSide(color: AppColors.glassAccentPink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMD,
          borderSide: const BorderSide(color: AppColors.glassDestructive),
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool isExpiry = false,
  }) {
    final status = isExpiry && date != null
        ? DocumentExpirationHelper.statusFor(date)
        : null;

    final badgeColor = status != null
        ? DocumentExpirationHelper.colorFor(status)
        : AppColors.glassOnSurfaceMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusMD,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(
            color: status != null && (status.isExpired || status.isExpiringSoon)
                ? badgeColor.withValues(alpha: 0.5)
                : AppColors.glassBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: badgeColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (date != null && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.cancel_rounded,
                      size: 14,
                      color: AppColors.glassOnSurfaceFaint,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                  : 'Select date',
              style: AppTextStyles.bodySmall.copyWith(
                color: date != null
                    ? AppColors.glassOnSurface
                    : AppColors.glassOnSurfaceFaint,
                fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerSection() {
    final hasAttachedUpload = _upload != null;
    final hasExistingFile = widget.initialDocument?.filePath != null && !hasAttachedUpload;

    if (hasAttachedUpload) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glassAccentSecondaryBg,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(color: AppColors.glassAccentSecondary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.attach_file_rounded,
              color: AppColors.glassAccentSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _upload!.fileName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${(_upload!.bytes.length / 1024).toStringAsFixed(1)} KB (Ready to upload)',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassAccentSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.glassOnSurfaceMuted,
              onPressed: () => setState(() => _upload = null),
            ),
          ],
        ),
      );
    }

    if (hasExistingFile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.task_rounded,
              color: AppColors.glassAccentGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'File safely stored in vault',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.glassOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _pickFile,
              child: Text(
                'Replace',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.glassAccentPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _pickFile,
      borderRadius: AppRadius.radiusMD,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(
            color: AppColors.glassBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.upload_file_rounded,
              size: 18,
              color: AppColors.glassAccentPink,
            ),
            const SizedBox(width: 8),
            Text(
              'Upload file (PDF, image, document)',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.glassAccentPink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

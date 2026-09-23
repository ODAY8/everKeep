import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/core/utils/external_link.dart';
import 'package:everkeep/core/utils/pick_upload.dart';
import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/glass_filter_chips.dart';
import 'package:everkeep/widgets/glass/glass_item_row.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';
import 'package:everkeep/widgets/circular_icon_button.dart';

/// The Memories tab (routed as AppRouter.wishes): memories and wishes the
/// user has actually saved, backed by Supabase — nothing sample here.
class WishesScreen extends StatefulWidget {
  const WishesScreen({super.key});

  @override
  State<WishesScreen> createState() => _WishesScreenState();
}

class _WishesScreenState extends State<WishesScreen> {
  static const List<String> _tabs = ['Memories', 'Wishes'];
  static const List<String> _types = ['memory', 'wish'];
  // Singular forms, matched by index to _tabs/_types — "Memories" minus a
  // trailing "s" would read "Memorie", so this is spelled out instead.
  static const List<String> _singularLabels = ['Memory', 'Wish'];

  int _selectedTab = 0;

  String get _selectedType => _types[_selectedTab];
  String get _selectedLabel => _singularLabels[_selectedTab];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final memoryProv = context.read<MemoryProvider>();
      if (!memoryProv.hasFetched) memoryProv.fetchMemories();
    });
  }

  // ── Adding ──────────────────────────────────────────────────────────────────

  void _chooseHowToAdd() {
    final type = _selectedType;
    showGlassActionSheet(
      context,
      title: 'Add $_selectedLabel',
      subtitle: 'Attach a photo or file, or just keep a note of it.',
      actions: [
        GlassSheetAction(
          label: 'Choose a file',
          icon: Icons.upload_file_rounded,
          onTap: () => _pickThenAdd(type),
        ),
        GlassSheetAction(
          label: 'Add without a file',
          icon: Icons.edit_note_rounded,
          onTap: () => _showAddForm(type),
        ),
      ],
    );
  }

  Future<void> _pickThenAdd(String type) async {
    DocumentUpload? upload;
    try {
      upload = await pickDocument();
    } on PickedTooLarge catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
      return;
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Couldn\'t read that file. Try another one.', isError: true);
      }
      return;
    }
    if (upload == null || !mounted) return; // cancelled
    await _showAddForm(type, upload: upload);
  }

  Future<void> _showAddForm(String type, {DocumentUpload? upload}) async {
    final memoryProv = context.read<MemoryProvider>();
    final label = type == 'memory' ? 'Memory' : 'Wish';

    final saved = await showGlassFormSheet(
      context,
      title: 'Add $label',
      subtitle: upload == null
          ? (type == 'memory'
              ? 'Keep a memory worth holding on to.'
              : 'Write down a wish for the people you love.')
          : 'Attached: ${upload.fileName}',
      submitLabel: upload == null ? 'Save' : 'Upload & Save',
      fields: [
        GlassFormField(
          key: 'title',
          label: 'Title',
          hint: type == 'memory' ? 'e.g. Our trip to the coast' : 'e.g. For my daughter',
          validator: _titleValidator,
        ),
        GlassFormField(
          key: 'content',
          label: type == 'memory' ? 'What happened' : 'Your wish',
          hint: type == 'memory'
              ? 'Write as much or as little as you like...'
              : 'What you\'d like them to know...',
          required: false,
          minLines: 3,
          maxLines: 6,
          validator: _contentValidator,
        ),
      ],
      dateFields: const [GlassFormDateField(key: 'date', label: 'Date (optional)')],
      onSubmit: (values) async {
        final added = await memoryProv.createMemory(
          MemoryItem(
            id: '',
            title: values['title']!,
            content: values['content'] ?? '',
            type: type,
            date: _parseIsoDate(values['date']),
          ),
          upload: upload,
        );
        return added ? null : memoryProv.error ?? 'Could not save the $label.';
      },
    );

    if (saved && mounted) {
      showAppSnackBar(context, '$label added');
    }
  }

  // ── Editing & attachments ──────────────────────────────────────────────────

  Future<void> _showEditForm(MemoryItem item) async {
    final memoryProv = context.read<MemoryProvider>();
    final label = item.typeLabel;

    final saved = await showGlassFormSheet(
      context,
      title: 'Edit $label',
      fields: [
        GlassFormField(
          key: 'title',
          label: 'Title',
          hint: 'e.g. Our trip to the coast',
          initialValue: item.title,
          validator: _titleValidator,
        ),
        GlassFormField(
          key: 'content',
          label: item.isMemory ? 'What happened' : 'Your wish',
          hint: 'Write as much or as little as you like...',
          required: false,
          initialValue: item.content,
          minLines: 3,
          maxLines: 6,
          validator: _contentValidator,
        ),
      ],
      submitLabel: 'Save Changes',
      dateFields: [
        GlassFormDateField(key: 'date', label: 'Date (optional)', initialValue: item.date),
      ],
      onSubmit: (values) async {
        final ok = await memoryProv.updateMemory(
          item.copyWith(
            title: values['title']!,
            content: values['content'] ?? '',
            date: _parseIsoDate(values['date']),
          ),
        );
        return ok ? null : memoryProv.error ?? 'Could not save your changes.';
      },
    );

    if (saved && mounted) showAppSnackBar(context, '$label updated');
  }

  Future<void> _pickThenAttach(MemoryItem item) async {
    DocumentUpload? upload;
    try {
      upload = await pickDocument();
    } on PickedTooLarge catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
      return;
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Couldn\'t read that file. Try another one.', isError: true);
      }
      return;
    }
    if (upload == null || !mounted) return; // cancelled

    final memoryProv = context.read<MemoryProvider>();
    final ok = await memoryProv.uploadAttachment(item.id, upload);
    if (!mounted) return;
    showAppSnackBar(
      context,
      ok ? 'Attachment saved' : memoryProv.error ?? 'Could not upload the attachment.',
      isError: !ok,
    );
  }

  Future<void> _confirmRemoveAttachment(MemoryItem item) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove attachment?',
      message: 'The file attached to "${item.title}" will be permanently removed. '
          '${item.typeLabel} itself is kept.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    final memoryProv = context.read<MemoryProvider>();
    final ok = await memoryProv.removeAttachment(item.id);
    if (!mounted) return;
    showAppSnackBar(
      context,
      ok ? 'Attachment removed' : memoryProv.error ?? 'Could not remove the attachment.',
      isError: !ok,
    );
  }

  Future<void> _openAttachment(MemoryItem item) async {
    final memoryProv = context.read<MemoryProvider>();
    final url = await memoryProv.downloadUrlFor(item);
    if (!mounted) return;
    if (url == null) {
      showAppSnackBar(context, memoryProv.error ?? 'Could not open the file.', isError: true);
      return;
    }

    final opened = await openExternal(Uri.parse(url));
    if (!opened && mounted) {
      showAppSnackBar(context, 'No app on this device can open that file.', isError: true);
    }
  }

  // ── Deleting ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(MemoryItem item) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${item.typeLabel.toLowerCase()}?',
      message: '"${item.title}" will be permanently removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final memoryProv = context.read<MemoryProvider>();
    final deleted = await memoryProv.deleteMemory(item.id);
    if (!mounted) return;

    showAppSnackBar(
      context,
      deleted ? '${item.typeLabel} deleted' : memoryProv.error ?? 'Could not delete it.',
      isError: !deleted,
    );
  }

  // ── Details & actions ───────────────────────────────────────────────────────

  void _showDetails(MemoryItem item) {
    showGlassSheet<void>(
      context,
      builder: (sheetContext) => _MemoryDetailsSheet(item: item),
    );
  }

  void _showActions(MemoryItem item) {
    showGlassActionSheet(
      context,
      title: item.title,
      subtitle: item.subtitle,
      actions: [
        GlassSheetAction(
          label: 'View details',
          icon: Icons.visibility_outlined,
          onTap: () => _showDetails(item),
        ),
        GlassSheetAction(
          label: 'Edit',
          icon: Icons.edit_outlined,
          onTap: () => _showEditForm(item),
        ),
        if (item.hasAttachment)
          GlassSheetAction(
            label: 'Open attachment',
            icon: Icons.open_in_new_rounded,
            onTap: () => _openAttachment(item),
          ),
        GlassSheetAction(
          label: item.hasAttachment ? 'Replace attachment' : 'Add attachment',
          icon: Icons.attach_file_rounded,
          onTap: () => _pickThenAttach(item),
        ),
        if (item.hasAttachment)
          GlassSheetAction(
            label: 'Remove attachment',
            icon: Icons.attachment_outlined,
            onTap: () => _confirmRemoveAttachment(item),
          ),
        GlassSheetAction(
          label: 'Delete ${item.typeLabel.toLowerCase()}',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onTap: () => _confirmDelete(item),
        ),
      ],
    );
  }

  // ── Layout ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      onRefresh: () => context.read<MemoryProvider>().fetchMemories(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPageHeader(
            title: 'Memories',
            showBackButton: Navigator.of(context).canPop(),
            trailing: CircularIconButton(
              icon: Icons.add_rounded,
              background: AppColors.glassSurface,
              foreground: AppColors.glassOnSurface,
              size: 40,
              tooltip: 'Add $_selectedLabel',
              onPressed: _chooseHowToAdd,
            ),
          ),
          const SizedBox(height: 18),
          GlassFilterChips(
            labels: _tabs,
            selectedIndex: _selectedTab,
            onSelected: (index) => setState(() => _selectedTab = index),
          ),
          const SizedBox(height: 20),
          Consumer<MemoryProvider>(
            builder: (context, memoryProv, _) {
              // Only a failed *first load* replaces the list. A failed
              // add/edit/delete leaves the list alone and is reported in a
              // snackbar by whoever triggered it.
              if (!memoryProv.hasFetched) {
                final loadError = memoryProv.error;
                if (loadError != null && !memoryProv.isLoading) {
                  return ErrorRetryView(
                    message: loadError,
                    onRetry: memoryProv.fetchMemories,
                  );
                }
                return const LoadingView();
              }

              final displayed = memoryProv.filterByType(_selectedType);

              if (displayed.isEmpty) {
                return _EmptyState(
                  label: _tabs[_selectedTab],
                  singular: _selectedLabel,
                  onAdd: _chooseHowToAdd,
                );
              }

              return Column(
                children: [
                  for (final entry in displayed.asMap().entries) ...[
                    FadeSlideIn(
                      index: entry.key,
                      child: GlassItemRow(
                        icon: entry.value.icon,
                        iconColor: AppColors.glassAccentPink,
                        title: entry.value.title,
                        subtitle: entry.value.subtitle,
                        onTap: () => _showActions(entry.value),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

DateTime? _parseIsoDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _titleValidator(String value) =>
    value.length > 300 ? 'Keep the title under 300 characters.' : null;

String? _contentValidator(String value) =>
    value.length > 10000 ? 'Keep it under 10,000 characters.' : null;

class _EmptyState extends StatelessWidget {
  final String label;
  final String singular;
  final VoidCallback onAdd;

  const _EmptyState({required this.label, required this.singular, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(
            'No ${label.toLowerCase()} yet.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: 16),
          GlassPrimaryButton(text: 'Add $singular', onPressed: onAdd),
        ],
      ),
    );
  }
}

/// A read-only view of a memory or wish's full content, reached from its
/// action sheet ("View details"). Editing and deleting happen from there.
class _MemoryDetailsSheet extends StatelessWidget {
  final MemoryItem item;

  const _MemoryDetailsSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.glassAccentPink.withValues(alpha: 0.16),
                borderRadius: AppRadius.radiusLG,
              ),
              child: Icon(item.icon, color: AppColors.glassAccentPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: AppTextStyles.serifTitleSmall.copyWith(
                  color: AppColors.glassOnSurface,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          item.subtitle,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.glassOnSurfaceMuted),
        ),
        const SizedBox(height: 18),
        if (item.content.trim().isNotEmpty)
          Text(
            item.content,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.glassOnSurface),
          )
        else
          Text(
            'No details written.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.glassOnSurfaceFaint),
          ),
        if (item.hasAttachment) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.attach_file_rounded,
                color: AppColors.glassOnSurfaceMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Has an attached file',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.glassOnSurfaceMuted),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        GlassPrimaryButton(text: 'Close', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

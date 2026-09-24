import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/pick_upload.dart';
import '../../../../models/document_upload.dart';
import '../../../../models/memory_item.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../widgets/circular_icon_button.dart';
import '../../../../widgets/fade_slide_in.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_filter_chips.dart';
import '../../../../widgets/glass/glass_page_header.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../../../widgets/glass/glass_scaffold.dart';
import '../../../../widgets/glass/glass_search_bar.dart';
import '../../../../widgets/glass/glass_sheet.dart';
import '../widgets/memory_card.dart';
import '../widgets/memory_details_sheet.dart';
import '../widgets/memory_form_sheet.dart';

/// The Memories & Wishes screen (routed as AppRouter.wishes):
/// Production-quality personal archive for memories, stories, photos, and wishes.
class WishesScreen extends StatefulWidget {
  const WishesScreen({super.key});

  @override
  State<WishesScreen> createState() => _WishesScreenState();
}

class _WishesScreenState extends State<WishesScreen> {
  static const List<String> _tabs = ['Memories', 'Wishes'];
  static const List<String> _types = ['memory', 'wish'];
  static const List<String> _singularLabels = ['Memory', 'Wish'];

  int _selectedTab = 0;
  bool _searching = false;
  String _query = '';
  String? _selectedTag;
  MemorySortOption _sortOption = MemorySortOption.memoryDateDesc;

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

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _query = '';
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
        showAppSnackBar(
          context,
          'Couldn\'t read that file. Try another one.',
          isError: true,
        );
      }
      return;
    }
    if (upload == null || !mounted) return; // cancelled
    await _showAddForm(type, upload: upload);
  }

  Future<void> _showAddForm(String type, {DocumentUpload? upload}) async {
    final label = type == 'memory' ? 'Memory' : 'Wish';
    final saved = await MemoryFormSheet.show(
      context,
      type: type,
      initialUpload: upload,
    );
    if (saved == true && mounted) {
      showAppSnackBar(context, '$label added');
    }
  }

  // ── Editing & attachments ──────────────────────────────────────────────────

  Future<void> _showEditForm(MemoryItem item) async {
    final label = item.typeLabel;
    final saved = await MemoryFormSheet.show(context, item: item);
    if (saved == true && mounted) {
      showAppSnackBar(context, '$label updated');
    }
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
        showAppSnackBar(
          context,
          'Couldn\'t read that file. Try another one.',
          isError: true,
        );
      }
      return;
    }
    if (upload == null || !mounted) return; // cancelled

    final memoryProv = context.read<MemoryProvider>();
    final ok = await memoryProv.uploadAttachment(item.id, upload);
    if (!mounted) return;
    showAppSnackBar(
      context,
      ok
          ? 'Attachment saved'
          : memoryProv.error ?? 'Could not upload the attachment.',
      isError: !ok,
    );
  }

  Future<void> _confirmRemoveAttachment(MemoryItem item) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove attachment?',
      message:
          'The file attached to "${item.title}" will be permanently removed. '
          '${item.typeLabel} itself is kept.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    final memoryProv = context.read<MemoryProvider>();
    final ok = await memoryProv.removeAttachment(item.id);
    if (!mounted) return;
    showAppSnackBar(
      context,
      ok
          ? 'Attachment removed'
          : memoryProv.error ?? 'Could not remove the attachment.',
      isError: !ok,
    );
  }

  Future<void> _openAttachment(MemoryItem item) {
    final memoryProv = context.read<MemoryProvider>();
    return openRemoteFile(
      context,
      fetchUrl: () => memoryProv.downloadUrlFor(item),
      errorMessage: () => memoryProv.error,
    );
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
      deleted
          ? '${item.typeLabel} deleted'
          : memoryProv.error ?? 'Could not delete it.',
      isError: !deleted,
    );
  }

  // ── Details & actions ───────────────────────────────────────────────────────

  void _showDetails(MemoryItem item) {
    showGlassSheet<void>(
      context,
      builder: (sheetContext) => MemoryDetailsSheet(
        item: item,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _showEditForm(item);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _confirmDelete(item);
        },
        onOpenAttachment:
            item.hasAttachment ? () => _openAttachment(item) : null,
      ),
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

  void _cycleSortOption() {
    setState(() {
      _sortOption = switch (_sortOption) {
        MemorySortOption.memoryDateDesc => MemorySortOption.memoryDateAsc,
        MemorySortOption.memoryDateAsc => MemorySortOption.createdDateDesc,
        MemorySortOption.createdDateDesc => MemorySortOption.titleAsc,
        MemorySortOption.titleAsc => MemorySortOption.memoryDateDesc,
      };
    });
  }

  String _sortLabel(MemorySortOption option) => switch (option) {
    MemorySortOption.memoryDateDesc => 'Date (Newest)',
    MemorySortOption.memoryDateAsc => 'Date (Oldest)',
    MemorySortOption.createdDateDesc => 'Date Added',
    MemorySortOption.titleAsc => 'Title (A-Z)',
  };

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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularIconButton(
                  icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                  background: AppColors.glassSurface,
                  foreground: AppColors.glassOnSurface,
                  size: 40,
                  tooltip: _searching ? 'Close search' : 'Search memories',
                  onPressed: _toggleSearch,
                ),
                const SizedBox(width: 8),
                CircularIconButton(
                  icon: Icons.add_rounded,
                  background: AppColors.glassSurface,
                  foreground: AppColors.glassOnSurface,
                  size: 40,
                  tooltip: 'Add $_selectedLabel',
                  onPressed: _chooseHowToAdd,
                ),
              ],
            ),
          ),
          if (_searching) ...[
            const SizedBox(height: 14),
            GlassSearchBar(
              hintText: 'Search $_selectedLabel.toLowerCase()...',
              onChanged: (q) => setState(() => _query = q),
            ),
          ],
          const SizedBox(height: 18),
          GlassFilterChips(
            labels: _tabs,
            selectedIndex: _selectedTab,
            onSelected: (index) => setState(() {
              _selectedTab = index;
              _selectedTag = null;
            }),
          ),
          Consumer<MemoryProvider>(
            builder: (context, memoryProv, _) {
              if (!memoryProv.hasFetched) {
                final loadError = memoryProv.error;
                if (loadError != null && !memoryProv.isLoading) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: ErrorRetryView(
                      message: loadError,
                      onRetry: memoryProv.fetchMemories,
                    ),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: LoadingView(),
                );
              }

              final allForTab = memoryProv.filterByType(_selectedType);

              if (allForTab.isEmpty) {
                return _EmptyState(
                  label: _tabs[_selectedTab],
                  singular: _selectedLabel,
                  onAdd: _chooseHowToAdd,
                );
              }

              final displayed = memoryProv.getFilteredMemories(
                query: _query,
                tag: _selectedTag,
                sort: _sortOption,
                type: _selectedType,
              );

              final availableTags = memoryProv.allMemoryTags;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),

                  // Tag filters row (only when memories have tags)
                  if (_selectedTab == 0 && availableTags.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TagChip(
                            label: 'All tags',
                            isSelected:
                                _selectedTag == null || _selectedTag == 'all',
                            onTap: () => setState(() => _selectedTag = null),
                          ),
                          const SizedBox(width: 6),
                          for (final tag in availableTags) ...[
                            _TagChip(
                              label: '#$tag',
                              isSelected: _selectedTag == tag,
                              onTap: () => setState(() {
                                _selectedTag = _selectedTag == tag ? null : tag;
                              }),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Sort & Count Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${displayed.length} ${displayed.length == 1 ? _selectedLabel.toLowerCase() : _tabs[_selectedTab].toLowerCase()}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.glassOnSurfaceMuted,
                            fontSize: 12,
                          ),
                        ),
                        GestureDetector(
                          onTap: _cycleSortOption,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.sort_rounded,
                                size: 14,
                                color: AppColors.glassAccentPink,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortLabel(_sortOption),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.glassAccentPink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (displayed.isEmpty)
                    _SearchEmptyState(
                      query: _query,
                      tag: _selectedTag,
                      onClear: () => setState(() {
                        _query = '';
                        _selectedTag = null;
                      }),
                    )
                  else
                    Column(
                      children: [
                        for (final entry in displayed.asMap().entries) ...[
                          FadeSlideIn(
                            index: entry.key,
                            child: MemoryCard(
                              item: entry.value,
                              onTap: () => _showActions(entry.value),
                              onMore: () => _showActions(entry.value),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.glassAccentPink.withValues(alpha: 0.2)
              : AppColors.glassSurface,
          borderRadius: AppRadius.radiusPill,
          border: Border.all(
            color: isSelected
                ? AppColors.glassAccentPink
                : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected
                ? AppColors.glassAccentPink
                : AppColors.glassOnSurfaceMuted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  final String query;
  final String? tag;
  final VoidCallback onClear;

  const _SearchEmptyState({
    required this.query,
    this.tag,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: AppColors.glassOnSurfaceFaint,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'No memories found',
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.glassOnSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              query.isNotEmpty
                  ? 'No results matching "$query"'
                  : 'No items with tag #$tag',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.glassOnSurfaceMuted,
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onClear,
              child: const Text('Clear search & filter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  final String singular;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.label,
    required this.singular,
    required this.onAdd,
  });

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

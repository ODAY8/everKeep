import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/person_item.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../../../widgets/glass/glass_sheet.dart';

/// Modal bottom sheet allowing users to search, select, create, and edit people
/// tagged in memories or wishes.
class PeopleSelectorSheet extends StatefulWidget {
  final List<PersonItem> initiallySelected;

  const PeopleSelectorSheet({
    super.key,
    this.initiallySelected = const [],
  });

  /// Displays the people selector and returns the chosen [List<PersonItem>].
  static Future<List<PersonItem>?> show(
    BuildContext context, {
    List<PersonItem> selected = const [],
  }) {
    return showGlassSheet<List<PersonItem>>(
      context,
      builder: (_) => PeopleSelectorSheet(initiallySelected: selected),
    );
  }

  @override
  State<PeopleSelectorSheet> createState() => _PeopleSelectorSheetState();
}

class _PeopleSelectorSheetState extends State<PeopleSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  final Map<String, PersonItem> _selectedMap = {};
  String _query = '';
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    for (final p in widget.initiallySelected) {
      _selectedIds.add(p.id);
      _selectedMap[p.id] = p;
    }
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _togglePerson(PersonItem person) {
    setState(() {
      if (_selectedIds.contains(person.id)) {
        _selectedIds.remove(person.id);
        _selectedMap.remove(person.id);
      } else {
        _selectedIds.add(person.id);
        _selectedMap[person.id] = person;
      }
    });
  }

  Future<void> _handleCreatePerson(MemoryProvider memProv) async {
    final validation = PersonItem.validateName(_query);
    if (validation != null) {
      showAppSnackBar(context, validation, isError: true);
      return;
    }

    setState(() => _isCreating = true);
    final created = await memProv.createPerson(_query);
    if (!mounted) return;
    setState(() => _isCreating = false);

    if (created != null) {
      _togglePerson(created);
      _searchController.clear();
      showAppSnackBar(context, 'Added "${created.name}"');
    } else {
      showAppSnackBar(
        context,
        memProv.error ?? 'Could not add person.',
        isError: true,
      );
    }
  }

  Future<void> _handleEditPersonName(
    MemoryProvider memProv,
    PersonItem person,
  ) async {
    final editController = TextEditingController(text: person.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glassSurfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLG,
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: Text(
          'Edit Name',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.glassOnSurface,
          ),
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Enter name...',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceFaint,
            ),
            filled: true,
            fillColor: AppColors.glassSurface,
            border: OutlineInputBorder(
              borderRadius: AppRadius.radiusMD,
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.glassAccentPink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final newName = editController.text.trim();
      final validation = PersonItem.validateName(newName);
      if (validation != null) {
        if (!mounted) return;
        showAppSnackBar(context, validation, isError: true);
        return;
      }

      final updated = await memProv.updatePerson(person.id, newName);
      if (!mounted) return;
      if (updated != null) {
        if (_selectedIds.contains(updated.id)) {
          _selectedMap[updated.id] = updated;
        }
        showAppSnackBar(context, 'Name updated');
      } else {
        showAppSnackBar(
          context,
          memProv.error ?? 'Could not update name.',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleDeletePerson(
    MemoryProvider memProv,
    PersonItem person,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glassBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
        title: Text(
          'Delete Person',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.glassOnSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${person.name}"? This will detach them from all memories.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightError,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await memProv.deletePerson(person.id);
      if (!mounted) return;
      if (success) {
        setState(() {
          _selectedIds.remove(person.id);
          _selectedMap.remove(person.id);
        });
        showAppSnackBar(context, 'Person deleted');
      } else {
        showAppSnackBar(
          context,
          memProv.error ?? 'Could not delete person.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MemoryProvider>(
      builder: (context, memProv, _) {
        final allPeople = memProv.allPeople;
        final filteredPeople = allPeople.where((p) {
          if (_query.isEmpty) return true;
          return p.name.toLowerCase().contains(_query.toLowerCase());
        }).toList();

        final queryExactMatch = allPeople.any(
          (p) => p.name.trim().toLowerCase() == _query.toLowerCase(),
        );

        final canCreateNew = _query.isNotEmpty && !queryExactMatch;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.glassAccentPink.withValues(alpha: 0.16),
                          borderRadius: AppRadius.radiusMD,
                        ),
                        child: const Icon(
                          Icons.people_outline_rounded,
                          color: AppColors.glassAccentPink,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tag People',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.glassOnSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search or type name field
              Container(
                decoration: BoxDecoration(
                  color: AppColors.glassSurface,
                  borderRadius: AppRadius.radiusMD,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: TextField(
                  key: const ValueKey('people_search_input'),
                  controller: _searchController,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search or add someone...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.glassOnSurfaceFaint,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: AppColors.glassOnSurfaceMuted,
                            ),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Selected people preview count
              if (_selectedIds.isNotEmpty) ...[
                Text(
                  '${_selectedIds.length} ${_selectedIds.length == 1 ? 'person' : 'people'} selected',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.glassAccentPink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // People list
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Create new person option if not an exact match
                    if (canCreateNew) ...[
                      InkWell(
                        key: const ValueKey('add_new_person_tile'),
                        onTap: _isCreating ? null : () => _handleCreatePerson(memProv),
                        borderRadius: AppRadius.radiusMD,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glassAccentPink.withValues(alpha: 0.12),
                            borderRadius: AppRadius.radiusMD,
                            border: Border.all(
                              color: AppColors.glassAccentPink.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: AppColors.glassAccentPink,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Add "$_query"',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.glassAccentPink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_isCreating)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.glassAccentPink,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (filteredPeople.isEmpty && !canCreateNew) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.person_search_rounded,
                                size: 36,
                                color: AppColors.glassOnSurfaceFaint,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _query.isEmpty
                                    ? 'No people added yet.\nType a name above to add someone.'
                                    : 'No matches found.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.glassOnSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      for (final person in filteredPeople) ...[
                        _PersonListTile(
                          person: person,
                          isSelected: _selectedIds.contains(person.id),
                          onToggle: () => _togglePerson(person),
                          onEdit: () => _handleEditPersonName(
                            memProv,
                            person,
                          ),
                          onDelete: () => _handleDeletePerson(
                            memProv,
                            person,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Done Button
              GlassPrimaryButton(
                key: const ValueKey('people_done_button'),
                text: 'Done',
                onPressed: () {
                  final result = _selectedMap.values.toList();
                  Navigator.of(context).pop(result);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PersonListTile extends StatelessWidget {
  final PersonItem person;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PersonListTile({
    required this.person,
    required this.isSelected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.glassAccentPink.withValues(alpha: 0.15)
            : AppColors.glassSurface,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(
          color: isSelected
              ? AppColors.glassAccentPink.withValues(alpha: 0.45)
              : AppColors.glassBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onToggle,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: isSelected
                ? AppColors.glassAccentPink
                : AppColors.glassSurfaceRaised,
            child: Text(
              person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? Colors.white : AppColors.glassOnSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            person.name,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppColors.glassOnSurfaceMuted,
                ),
                tooltip: 'Edit name',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: AppColors.lightError,
                ),
                tooltip: 'Delete person',
                onPressed: onDelete,
              ),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? AppColors.glassAccentPink
                    : AppColors.glassOnSurfaceFaint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

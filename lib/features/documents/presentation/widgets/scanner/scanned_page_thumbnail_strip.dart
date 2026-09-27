import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../models/scanned_page.dart';

/// Horizontal reorderable thumbnail strip for multi-page documents.
///
/// Displays:
///   Page 1       Page 2       Page 3
///  [ image ]    [ image ]    [ image ]
///
/// Supports drag-and-drop reordering, active page selection, page deletion,
/// and adding a new page.
class ScannedPageThumbnailStrip extends StatelessWidget {
  final List<ScannedPage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelectPage;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onDeletePage;
  final VoidCallback onAddPage;

  const ScannedPageThumbnailStrip({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.onSelectPage,
    required this.onReorder,
    required this.onDeletePage,
    required this.onAddPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 125,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.black.withValues(alpha: 0.65),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Reorderable list for pages
          SizedBox(
            height: 110,
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: pages.length,
                // ignore: deprecated_member_use
                onReorder: onReorder,
                itemBuilder: (context, index) {
                  final page = pages[index];
                  final isSelected = index == selectedIndex;

                  return Container(
                    key: ValueKey(page.id),
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Page label (Page 1, Page 2, ...)
                        Text(
                          'Page ${index + 1}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isSelected
                                ? AppColors.glassAccentPink
                                : Colors.white70,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Thumbnail with delete overlay
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              onTap: () => onSelectPage(index),
                              child: Container(
                                width: 56,
                                height: 76,
                                decoration: BoxDecoration(
                                  borderRadius: AppRadius.radiusSM,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.glassAccentPink
                                        : Colors.white24,
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.glassAccentPink
                                                .withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: AppRadius.radiusSM,
                                  child: Image.memory(
                                    page.processedBytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),

                            // Delete button
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => onDeletePage(index),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.glassDestructive,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Add another page button
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: GestureDetector(
              onTap: onAddPage,
              child: Container(
                width: 56,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: AppRadius.radiusSM,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.glassAccentPink,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add Page',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

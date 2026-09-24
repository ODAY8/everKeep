import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/document_item.dart';
import '../../../../models/memory_item.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../widgets/fade_slide_in.dart';
import '../../../../widgets/glass/glass_card.dart';
import '../../../../widgets/glass/glass_page_header.dart';
import '../../../../widgets/glass/glass_scaffold.dart';

enum TimelineEventKind { memory, document }

class TimelineEvent {
  final String id;
  final String title;
  final String? subtitle;
  final DateTime date;
  final TimelineEventKind kind;
  final IconData icon;
  final Color tintColor;
  final Object item;

  const TimelineEvent({
    required this.id,
    required this.title,
    this.subtitle,
    required this.date,
    required this.kind,
    required this.icon,
    required this.tintColor,
    required this.item,
  });
}

/// The unified Life Timeline combining memories and documents across years.
class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  List<TimelineEvent> _buildTimelineEvents({
    required List<DocumentItem> documents,
    required List<MemoryItem> memories,
  }) {
    final events = <TimelineEvent>[];

    for (final doc in documents) {
      final date = doc.issueDate ?? doc.dateAdded;
      if (date != null) {
        events.add(
          TimelineEvent(
            id: doc.id,
            title: doc.title,
            subtitle: doc.category,
            date: date,
            kind: TimelineEventKind.document,
            icon: Icons.description_outlined,
            tintColor: AppColors.glassAccentSecondary,
            item: doc,
          ),
        );
      }
    }

    for (final mem in memories) {
      if (mem.isMemory) {
        final date = mem.date ?? mem.createdAt;
        if (date != null) {
          events.add(
            TimelineEvent(
              id: mem.id,
              title: mem.title,
              subtitle: mem.location != null && mem.location!.isNotEmpty
                  ? '📍 ${mem.location}'
                  : (mem.tagList.isNotEmpty ? '#${mem.tagList.first}' : null),
              date: date,
              kind: TimelineEventKind.memory,
              icon: Icons.favorite_rounded,
              tintColor: AppColors.glassAccentPink,
              item: mem,
            ),
          );
        }
      }
    }

    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  Map<int, List<TimelineEvent>> _groupByYear(List<TimelineEvent> events) {
    final map = <int, List<TimelineEvent>>{};
    for (final e in events) {
      map.putIfAbsent(e.date.year, () => []).add(e);
    }
    return map;
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final docProv = context.watch<DocumentProvider>();
    final memProv = context.watch<MemoryProvider>();

    final events = _buildTimelineEvents(
      documents: docProv.documents,
      memories: memProv.items,
    );
    final grouped = _groupByYear(events);
    final sortedYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return GlassScaffold(
      onRefresh: () async {
        await Future.wait([
          context.read<DocumentProvider>().fetchDocuments(),
          context.read<MemoryProvider>().fetchMemories(),
        ]);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPageHeader(
            title: 'Life Timeline',
            showBackButton: Navigator.of(context).canPop(),
          ),
          const SizedBox(height: 8),
          Text(
            'Your milestones, memories, and key documents through time.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: 24),
          if (events.isEmpty)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.history_edu_rounded,
                        color: AppColors.glassOnSurfaceFaint,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No timeline events yet.',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.glassOnSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add memories with dates or documents to build your life timeline.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            for (final year in sortedYears) ...[
              _YearHeader(year: year),
              const SizedBox(height: 12),
              for (int i = 0; i < grouped[year]!.length; i++) ...[
                FadeSlideIn(
                  index: i,
                  child: _TimelineRow(
                    event: grouped[year]![i],
                    isLast: i == grouped[year]!.length - 1,
                    monthLabel: _months[grouped[year]![i].date.month - 1],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
        ],
      ),
    );
  }
}

class _YearHeader extends StatelessWidget {
  final int year;

  const _YearHeader({required this.year});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.glassSurfaceRaised,
            borderRadius: AppRadius.radiusPill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            year.toString(),
            style: AppTextStyles.serifHeadline.copyWith(
              color: AppColors.glassOnSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: AppColors.glassBorder)),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineEvent event;
  final bool isLast;
  final String monthLabel;

  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  monthLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.glassOnSurfaceMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                Text(
                  event.date.day.toString(),
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: event.tintColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: event.tintColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(event.icon, color: event.tintColor, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.glassBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GlassCard(
                onTap: () {
                  if (event.kind == TimelineEventKind.document) {
                    Navigator.of(context).pushNamed(AppRouter.documents);
                  } else {
                    Navigator.of(context).pushNamed(AppRouter.wishes);
                  }
                },
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.glassOnSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (event.subtitle != null &&
                        event.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        event.subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

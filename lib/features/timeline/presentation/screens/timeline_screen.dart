import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/features/documents/presentation/widgets/document_details_sheet.dart';
import 'package:everkeep/features/documents/presentation/widgets/document_form_sheet.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_details_sheet.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_form_sheet.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:everkeep/widgets/fade_slide_in.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';

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
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  /// Builds a sorted list of timeline events from memories and documents.
  static List<TimelineEvent> buildTimelineEvents({
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

  /// Groups timeline events by year in a map.
  static Map<int, List<TimelineEvent>> groupByYear(List<TimelineEvent> events) {
    final map = <int, List<TimelineEvent>>{};
    for (final e in events) {
      map.putIfAbsent(e.date.year, () => []).add(e);
    }
    return map;
  }

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  bool _isOpening = false;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final docProv = context.read<DocumentProvider>();
      if (!docProv.hasFetched) {
        docProv.fetchDocuments();
      }
      final memProv = context.read<MemoryProvider>();
      if (!memProv.hasFetched) {
        memProv.fetchMemories();
      }
    });
  }

  void _onEventTap(TimelineEvent event) {
    if (_isOpening) return;

    switch (event.kind) {
      case TimelineEventKind.memory:
        _openMemoryDetails(event.id);
        break;
      case TimelineEventKind.document:
        _openDocumentDetails(event.id);
        break;
    }
  }

  void _openMemoryDetails(String memoryId) {
    final memProv = context.read<MemoryProvider>();
    final memory = memProv.items.where((m) => m.id == memoryId).firstOrNull;
    if (memory == null) {
      showAppSnackBar(context, 'That memory couldn\'t be found.', isError: true);
      return;
    }

    _isOpening = true;
    showGlassSheet<void>(
      context,
      builder: (sheetContext) => MemoryDetailsSheet(
        item: memory,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _showMemoryEditForm(memory);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _confirmDeleteMemory(memory);
        },
        onOpenAttachment:
            memory.hasAttachment ? () => _openMemoryAttachment(memory) : null,
      ),
    ).whenComplete(() {
      if (mounted) _isOpening = false;
    });
  }

  void _openDocumentDetails(String documentId) {
    final docProv = context.read<DocumentProvider>();
    final document =
        docProv.documents.where((d) => d.id == documentId).firstOrNull;
    if (document == null) {
      showAppSnackBar(context, 'That document couldn\'t be found.', isError: true);
      return;
    }

    _isOpening = true;
    showGlassSheet<void>(
      context,
      builder: (sheetContext) => DocumentDetailsSheet(
        document: document,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _showDocumentEditForm(document);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _confirmDeleteDocument(document);
        },
        onOpenFile:
            document.hasFile ? () => _openDocumentFile(document) : null,
      ),
    ).whenComplete(() {
      if (mounted) _isOpening = false;
    });
  }

  Future<void> _showMemoryEditForm(MemoryItem item) async {
    final label = item.typeLabel;
    final saved = await MemoryFormSheet.show(context, item: item);
    if (!mounted) return;
    if (saved == true) {
      showAppSnackBar(context, '$label updated');
    }
  }

  Future<void> _confirmDeleteMemory(MemoryItem item) async {
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

  Future<void> _openMemoryAttachment(MemoryItem item) {
    final memoryProv = context.read<MemoryProvider>();
    return openRemoteFile(
      context,
      fetchUrl: () => memoryProv.downloadUrlFor(item),
      errorMessage: () => memoryProv.error,
    );
  }

  Future<void> _showDocumentEditForm(DocumentItem document) async {
    final saved = await DocumentFormSheet.show(context, document: document);
    if (!mounted) return;
    if (saved == true) {
      showAppSnackBar(context, 'Document updated');
    }
  }

  Future<void> _confirmDeleteDocument(DocumentItem document) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete document?',
      message:
          '"${document.title}" will be permanently removed from your vault.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final docProv = context.read<DocumentProvider>();
    final deleted = await docProv.deleteDocument(document.id);
    if (!mounted) return;

    showAppSnackBar(
      context,
      deleted
          ? 'Document deleted'
          : docProv.error ?? 'Could not delete the document.',
      isError: !deleted,
    );
  }

  Future<void> _openDocumentFile(DocumentItem document) {
    final docProv = context.read<DocumentProvider>();
    return openRemoteFile(
      context,
      fetchUrl: () => docProv.downloadUrlFor(document),
      errorMessage: () => docProv.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final docProv = context.watch<DocumentProvider>();
    final memProv = context.watch<MemoryProvider>();

    final events = TimelineScreen.buildTimelineEvents(
      documents: docProv.documents,
      memories: memProv.items,
    );
    final grouped = TimelineScreen.groupByYear(events);
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
                    onTap: () => _onEventTap(grouped[year]![i]),
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
  final VoidCallback onTap;

  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.monthLabel,
    required this.onTap,
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
                onTap: onTap,
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

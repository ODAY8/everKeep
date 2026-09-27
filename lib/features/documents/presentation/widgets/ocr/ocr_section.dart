import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'ocr_text_viewer_sheet.dart';

/// Interactive OCR status and text preview section for [DocumentDetailsSheet].
class OcrSection extends StatelessWidget {
  final DocumentItem document;

  const OcrSection({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    if (!document.hasFile) {
      return const SizedBox.shrink();
    }

    DocumentProvider? docProv;
    try {
      docProv = Provider.of<DocumentProvider>(context, listen: true);
    } catch (_) {}

    final isProcessing = docProv?.isOcrProcessing(document.id) ?? false;
    final progress = docProv?.getOcrProgress(document.id) ?? 0.0;
    final statusMsg = docProv?.getOcrStatusMessage(document.id);
    final error = docProv?.getOcrError(document.id);
    final hasOcr = document.hasOcrText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EXTRACTED TEXT (OCR)',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.glassOnSurfaceFaint,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            if (hasOcr && !isProcessing && docProv != null)
              InkWell(
                onTap: () => _confirmReExtract(context, docProv!),
                borderRadius: AppRadius.radiusSM,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 13,
                        color: AppColors.glassAccentPink,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Re-extract',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.glassAccentPink,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (isProcessing) ...[
          _buildProcessingState(progress, statusMsg),
        ] else if (error != null && docProv != null) ...[
          _buildErrorState(context, docProv, error),
        ] else if (hasOcr) ...[
          _buildTextPreview(context, document),
        ] else if (docProv != null) ...[
          _buildExtractPrompt(context, docProv),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildExtractPrompt(BuildContext context, DocumentProvider docProv) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.glassAccentPink.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: AppColors.glassAccentPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Make this document searchable',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.glassOnSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Extract text on-device using private OCR',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.glassOnSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const ValueKey('extract_text_button'),
              onPressed: () => _startOcr(context, docProv),
              icon: const Icon(Icons.text_snippet_outlined, size: 18),
              label: const Text('Extract Text'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.glassAccentPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusMD,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingState(double progress, String? statusMsg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
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
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.glassAccentPink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusMsg ?? 'Extracting text...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.glassOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.glassAccentPink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.05, 1.0),
              backgroundColor: AppColors.glassBorder,
              color: AppColors.glassAccentPink,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    DocumentProvider docProv,
    String errorMessage,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Text extraction failed',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('ocr_retry_button'),
                onPressed: () {
                  docProv.clearOcrError(document.id);
                  _startOcr(context, docProv);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            errorMessage,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPreview(BuildContext context, DocumentItem document) {
    final previewSnippet = _createPreviewSnippet(document.ocrText!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            previewSnippet,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.glassOnSurface,
              fontFamily: 'monospace',
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.glassAccentSecondary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Searchable in vault',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassAccentSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                key: const ValueKey('view_ocr_text_button'),
                onPressed: () => showOcrTextViewer(context, document: document),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('View & Edit Text'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.glassAccentPink,
                  textStyle: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _createPreviewSnippet(String fullText) {
    final lines = fullText
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.startsWith('--- Page'))
        .take(3)
        .toList();
    if (lines.isEmpty) return 'Text available';
    return lines.join('\n');
  }

  Future<void> _startOcr(BuildContext context, DocumentProvider docProv) async {
    final result = await docProv.extractTextForDocument(document);
    if (result != null && context.mounted) {
      showAppSnackBar(context, 'Text extracted successfully.');
    }
  }

  Future<void> _confirmReExtract(
    BuildContext context,
    DocumentProvider docProv,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glassSurfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
        title: Text(
          'Re-run OCR?',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.glassOnSurface,
          ),
        ),
        content: Text(
          'Re-extracting text will overwrite your current extracted text and any manual corrections you saved.\n\nDo you want to continue?',
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
              backgroundColor: AppColors.glassAccentPink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Re-extract'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      _startOcr(context, docProv);
    }
  }
}

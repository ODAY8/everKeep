import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/features/documents/models/ocr_result.dart';

/// Opens the OCR Text Viewer and Editor bottom sheet.
Future<void> showOcrTextViewer(
  BuildContext context, {
  required DocumentItem document,
}) {
  DocumentProvider? docProv;
  try {
    docProv = Provider.of<DocumentProvider>(context, listen: false);
  } catch (_) {}

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.glassSurfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final sheet = OcrTextViewerSheet(document: document);
      if (docProv != null) {
        return ChangeNotifierProvider<DocumentProvider>.value(
          value: docProv,
          child: sheet,
        );
      }
      return sheet;
    },
  );
}

/// Full-featured OCR Text Viewer and Editor with page filtering, in-text search,
/// copy to clipboard, and manual correction saving.
class OcrTextViewerSheet extends StatefulWidget {
  final DocumentItem document;

  const OcrTextViewerSheet({
    super.key,
    required this.document,
  });

  @override
  State<OcrTextViewerSheet> createState() => _OcrTextViewerSheetState();
}

class _OcrTextViewerSheetState extends State<OcrTextViewerSheet> {
  late OcrDocumentResult _ocrResult;
  late TextEditingController _searchController;
  late TextEditingController _editController;
  int _selectedPageIndex = 0; // 0 means "All Pages"
  bool _isEditing = false;
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _editController = TextEditingController();
    _loadFromDocument(widget.document);
  }

  void _loadFromDocument(DocumentItem doc) {
    final text = doc.ocrText ?? '';
    _ocrResult = OcrDocumentResult.fromCombinedText(text);
    _editController.text = _ocrResult.combinedText;
  }

  @override
  void didUpdateWidget(covariant OcrTextViewerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document.ocrText != oldWidget.document.ocrText && !_isEditing) {
      _loadFromDocument(widget.document);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _editController.dispose();
    super.dispose();
  }

  String get _displayedText {
    if (_selectedPageIndex == 0 || _ocrResult.pages.isEmpty) {
      return _ocrResult.combinedText;
    }
    final pageNum = _selectedPageIndex;
    final match = _ocrResult.pages.firstWhere(
      (p) => p.pageNumber == pageNum,
      orElse: () => _ocrResult.pages.first,
    );
    return match.text;
  }

  @override
  Widget build(BuildContext context) {
    DocumentProvider? docProv;
    try {
      docProv = Provider.of<DocumentProvider>(context, listen: true);
    } catch (_) {}

    final currentDoc = (docProv != null)
        ? docProv.documents.firstWhere(
            (d) => d.id == widget.document.id,
            orElse: () => widget.document,
          )
        : widget.document;

    if (!_isEditing && currentDoc.ocrText != _ocrResult.combinedText) {
      _loadFromDocument(currentDoc);
    }

    final hasMultiplePages = _ocrResult.pages.length > 1;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Edit Extracted Text' : 'Extracted Text',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.glassOnSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.document.title,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!_isEditing) ...[
                  IconButton(
                    key: const ValueKey('ocr_copy_button'),
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: 'Copy text',
                    color: AppColors.glassOnSurfaceMuted,
                    onPressed: _copyToClipboard,
                  ),
                  IconButton(
                    key: const ValueKey('ocr_edit_button'),
                    icon: const Icon(Icons.edit_note_rounded, size: 22),
                    tooltip: 'Edit text',
                    color: AppColors.glassAccentPink,
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                        _editController.text = _ocrResult.combinedText;
                      });
                    },
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: AppColors.glassOnSurfaceMuted,
                  onPressed: () => _handleClose(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.glassBorder, height: 16),

          // Search or Page filter bar (View Mode)
          if (!_isEditing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const ValueKey('ocr_search_input'),
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search within extracted text...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.glassOnSurfaceFaint,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.glassOnSurfaceMuted,
                    size: 18,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          color: AppColors.glassOnSurfaceMuted,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.glassSurface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                    borderSide: const BorderSide(
                      color: AppColors.glassAccentPink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Page selector chips if multi-page
            if (hasMultiplePages) ...[
              SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _ocrResult.pages.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final isSelected = _selectedPageIndex == idx;
                    final label = idx == 0 ? 'All Pages' : 'Page $idx';
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedPageIndex = idx),
                      selectedColor: AppColors.glassAccentPink.withValues(alpha: 0.25),
                      backgroundColor: AppColors.glassSurface,
                      labelStyle: AppTextStyles.labelSmall.copyWith(
                        color: isSelected
                            ? AppColors.glassAccentPink
                            : AppColors.glassOnSurfaceMuted,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusSM,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.glassAccentPink
                              : AppColors.glassBorder,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],

          // Main Content View / Editor
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: AppRadius.radiusMD,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: _isEditing
                  ? _buildEditor()
                  : _buildTextViewer(_displayedText, _searchQuery),
            ),
          ),

          // Bottom Action Bar (Edit Mode Actions)
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('ocr_edit_cancel_button'),
                      onPressed: _isSaving ? null : () => _cancelEdit(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.glassOnSurfaceMuted,
                        side: const BorderSide(color: AppColors.glassBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusMD,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: const ValueKey('ocr_edit_save_button'),
                      onPressed: (_isSaving || docProv == null)
                          ? null
                          : () => _saveEdit(context, docProv!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.glassAccentPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusMD,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Corrections'),
                    ),
                  ),
                ],
              ),
            ),

          if (!_isEditing) const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTextViewer(String text, String query) {
    if (text.trim().isEmpty) {
      return Center(
        child: Text(
          'No text detected in this document.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
        ),
      );
    }

    if (query.isEmpty) {
      return SingleChildScrollView(
        key: const ValueKey('ocr_text_scroll_view'),
        child: SelectableText(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurface,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      );
    }

    // Highlight search matches
    return SingleChildScrollView(
      key: const ValueKey('ocr_text_scroll_view'),
      child: SelectableText.rich(
        _buildHighlightedTextSpan(text, query),
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.glassOnSurface,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }

  TextSpan _buildHighlightedTextSpan(String text, String query) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: AppColors.glassAccentPink,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return TextSpan(children: spans);
  }

  Widget _buildEditor() {
    return TextField(
      key: const ValueKey('ocr_edit_input'),
      controller: _editController,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.glassOnSurface,
        fontFamily: 'monospace',
        height: 1.5,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Edit extracted document text...',
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _displayedText));
    showAppSnackBar(context, 'Text copied to clipboard');
  }

  void _cancelEdit(BuildContext context) {
    if (_editController.text != _ocrResult.combinedText) {
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.glassSurfaceRaised,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
          title: const Text('Discard edits?'),
          content: const Text(
            'You have unsaved text corrections. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Discard'),
            ),
          ],
        ),
      ).then((discard) {
        if (discard == true && mounted) {
          setState(() {
            _isEditing = false;
            _editController.text = _ocrResult.combinedText;
          });
        }
      });
    } else {
      setState(() => _isEditing = false);
    }
  }

  Future<void> _saveEdit(BuildContext context, DocumentProvider docProv) async {
    setState(() => _isSaving = true);
    final newText = _editController.text.trim();

    try {
      final success = await docProv.saveOcrText(widget.document, newText);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (success) {
        setState(() {
          _isEditing = false;
          _loadFromDocument(widget.document.copyWith(ocrText: newText));
        });
        showAppSnackBar(this.context, 'Corrections saved successfully.');
      } else {
        showAppSnackBar(
          this.context,
          docProv.error ?? 'Failed to save corrections.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppSnackBar(this.context, 'Error saving text: $e', isError: true);
    }
  }

  void _handleClose(BuildContext context) {
    if (_isEditing && _editController.text != _ocrResult.combinedText) {
      _cancelEdit(context);
    } else {
      Navigator.of(context).pop();
    }
  }
}

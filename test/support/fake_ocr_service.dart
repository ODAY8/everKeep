import 'dart:typed_data';

import 'package:everkeep/features/documents/models/ocr_result.dart';
import 'package:everkeep/features/documents/services/ocr_service.dart';

/// Test double implementing [OcrService] for automated testing.
class FakeOcrService implements OcrService {
  OcrDocumentResult? nextResult;
  String defaultText = 'Sample extracted document text';
  bool shouldFail = false;
  String failureMessage = 'Simulated OCR engine failure';

  int processImageCallCount = 0;
  int processPdfCallCount = 0;
  int processMultiPageCallCount = 0;
  int disposeCallCount = 0;

  @override
  Future<OcrDocumentResult> processImageBytes(
    Uint8List bytes, {
    int pageNumber = 1,
    void Function(double progress, String status)? onProgress,
  }) async {
    processImageCallCount++;
    onProgress?.call(0.5, 'Processing...');
    if (shouldFail) {
      throw OcrException(failureMessage);
    }
    onProgress?.call(1.0, 'Done');
    return nextResult ??
        OcrDocumentResult.fromPages([
          OcrPageResult(
            pageNumber: pageNumber,
            text: defaultText,
            confidence: 0.95,
          ),
        ]);
  }

  @override
  Future<OcrDocumentResult> processMultiPageImageBytes(
    List<Uint8List> pagesBytes, {
    void Function(double progress, String status)? onProgress,
  }) async {
    processMultiPageCallCount++;
    onProgress?.call(0.5, 'Processing pages...');
    if (shouldFail) {
      throw OcrException(failureMessage);
    }
    onProgress?.call(1.0, 'Done');
    if (nextResult != null) return nextResult!;

    final pages = <OcrPageResult>[];
    for (var i = 0; i < pagesBytes.length; i++) {
      pages.add(OcrPageResult(
        pageNumber: i + 1,
        text: '$defaultText (Page ${i + 1})',
        confidence: 0.95,
      ));
    }
    return OcrDocumentResult.fromPages(pages);
  }

  @override
  Future<OcrDocumentResult> processPdfBytes(
    Uint8List pdfBytes, {
    void Function(double progress, String status)? onProgress,
  }) async {
    processPdfCallCount++;
    onProgress?.call(0.5, 'Processing PDF...');
    if (shouldFail) {
      throw OcrException(failureMessage);
    }
    onProgress?.call(1.0, 'Done');
    return nextResult ??
        OcrDocumentResult.fromPages([
          OcrPageResult(
            pageNumber: 1,
            text: '$defaultText from PDF',
            confidence: 0.92,
          ),
        ]);
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }
}

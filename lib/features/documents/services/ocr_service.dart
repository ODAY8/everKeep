import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/ocr_result.dart';

/// Exception thrown when OCR processing fails.
class OcrException implements Exception {
  final String message;
  final Object? cause;

  const OcrException(this.message, [this.cause]);

  @override
  String toString() =>
      'OcrException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Abstract contract for OCR extraction operations.
abstract class OcrService {
  /// Extracts text from raw image bytes (e.g. JPEG, PNG, WebP).
  Future<OcrDocumentResult> processImageBytes(
    Uint8List bytes, {
    int pageNumber = 1,
    void Function(double progress, String status)? onProgress,
  });

  /// Extracts text from a list of image byte buffers representing document pages.
  Future<OcrDocumentResult> processMultiPageImageBytes(
    List<Uint8List> pagesBytes, {
    void Function(double progress, String status)? onProgress,
  });

  /// Extracts text from PDF bytes by rendering individual pages to images
  /// and running OCR on each rendered page.
  Future<OcrDocumentResult> processPdfBytes(
    Uint8List pdfBytes, {
    void Function(double progress, String status)? onProgress,
  });

  /// Disposes any open native recognizers.
  Future<void> dispose();
}

/// Production implementation of [OcrService] powered by Google ML Kit on-device
/// Text Recognition. Runs completely locally and offline for user privacy.
class MlKitOcrService implements OcrService {
  TextRecognizer? _textRecognizer;

  /// Optional hook for headless tests where native ML Kit is unavailable.
  final Future<String> Function(String imagePath)? testRecognizer;

  MlKitOcrService({this.testRecognizer});

  TextRecognizer get _recognizer =>
      _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<OcrDocumentResult> processImageBytes(
    Uint8List bytes, {
    int pageNumber = 1,
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Optimizing image...');
    final optimizedBytes = _optimizeImageBytes(bytes);

    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/ocr_page_${DateTime.now().microsecondsSinceEpoch}_$pageNumber.jpg',
    );

    try {
      await tempFile.writeAsBytes(optimizedBytes, flush: true);
      onProgress?.call(0.4, 'Recognizing text...');

      String extractedText;
      double? confidence;

      if (testRecognizer != null) {
        extractedText = await testRecognizer!(tempFile.path);
      } else {
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final recognizedText = await _recognizer.processImage(inputImage);
        extractedText = recognizedText.text;

        // Calculate average confidence if blocks provide it
        final confidences = recognizedText.blocks
            .expand((b) => b.lines)
            .map((l) => l.confidence)
            .whereType<double>()
            .toList();

        if (confidences.isNotEmpty) {
          confidence =
              confidences.reduce((a, b) => a + b) / confidences.length;
        }
      }

      onProgress?.call(1.0, 'Extraction complete');
      final normalizedText = normalizeExtractedText(extractedText);

      final pageResult = OcrPageResult(
        pageNumber: pageNumber,
        text: normalizedText,
        confidence: confidence,
      );

      return OcrDocumentResult.fromPages([pageResult]);
    } catch (e) {
      if (e is OcrException) rethrow;
      throw OcrException('Failed to extract text from image: $e', e);
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<OcrDocumentResult> processMultiPageImageBytes(
    List<Uint8List> pagesBytes, {
    void Function(double progress, String status)? onProgress,
  }) async {
    if (pagesBytes.isEmpty) {
      return OcrDocumentResult.fromPages(const []);
    }

    final pageResults = <OcrPageResult>[];
    final total = pagesBytes.length;

    for (var i = 0; i < total; i++) {
      final pageNum = i + 1;
      final startProgress = i / total;
      final endProgress = (i + 1) / total;

      onProgress?.call(
        startProgress,
        'Processing page $pageNum of $total...',
      );

      final pageDoc = await processImageBytes(
        pagesBytes[i],
        pageNumber: pageNum,
        onProgress: (p, status) {
          final scaled = startProgress + (p * (endProgress - startProgress));
          onProgress?.call(scaled, 'Page $pageNum of $total: $status');
        },
      );

      if (pageDoc.pages.isNotEmpty) {
        pageResults.add(pageDoc.pages.first);
      }
    }

    onProgress?.call(1.0, 'All pages processed');
    return OcrDocumentResult.fromPages(pageResults);
  }

  @override
  Future<OcrDocumentResult> processPdfBytes(
    Uint8List pdfBytes, {
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.05, 'Opening PDF document...');
    PdfDocument? doc;

    try {
      doc = await PdfDocument.openData(pdfBytes);
      final pageCount = doc.pages.length;

      if (pageCount == 0) {
        return OcrDocumentResult.fromPages(const []);
      }

      final pageResults = <OcrPageResult>[];

      for (var i = 0; i < pageCount; i++) {
        final pageNum = i + 1;
        final startProgress = 0.1 + (0.85 * (i / pageCount));
        final endProgress = 0.1 + (0.85 * ((i + 1) / pageCount));

        onProgress?.call(
          startProgress,
          'Rendering PDF page $pageNum of $pageCount...',
        );

        final page = doc.pages[i];
        // Render at crisp resolution (target ~1400px width for accurate OCR)
        final scale = 1400.0 / math.max(1.0, page.width);
        final renderWidth = (page.width * scale).round();
        final renderHeight = (page.height * scale).round();

        final pageImage = await page.render(
          width: renderWidth,
          height: renderHeight,
        );

        if (pageImage == null) {
          pageResults.add(OcrPageResult(
            pageNumber: pageNum,
            text: '',
          ));
          continue;
        }

        try {
          final rawImage = pageImage.createImageNF();
          final pngBytes = Uint8List.fromList(img.encodePng(rawImage));

          final pageDoc = await processImageBytes(
            pngBytes,
            pageNumber: pageNum,
            onProgress: (p, status) {
              final scaled = startProgress + (p * (endProgress - startProgress));
              onProgress?.call(scaled, 'Page $pageNum of $pageCount: $status');
            },
          );

          if (pageDoc.pages.isNotEmpty) {
            pageResults.add(pageDoc.pages.first);
          }
        } finally {
          pageImage.dispose();
        }
      }

      onProgress?.call(1.0, 'PDF extraction complete');
      return OcrDocumentResult.fromPages(pageResults);
    } catch (e) {
      if (e is OcrException) rethrow;
      throw OcrException('Failed to process PDF pages for OCR: $e', e);
    } finally {
      if (doc != null) {
        await doc.dispose();
      }
    }
  }

  /// Scales down images larger than 2048px to prevent out-of-memory errors
  /// while preserving high-contrast text features.
  Uint8List _optimizeImageBytes(Uint8List original) {
    try {
      final decoded = img.decodeImage(original);
      if (decoded == null) return original;

      final maxDimension = math.max(decoded.width, decoded.height);
      if (maxDimension <= 2048) {
        return original;
      }

      final factor = 2048.0 / maxDimension;
      final targetWidth = (decoded.width * factor).round();
      final targetHeight = (decoded.height * factor).round();

      final resized = img.copyResize(
        decoded,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );

      return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
    } catch (_) {
      return original;
    }
  }

  /// Normalizes whitespace and line breaks in recognized OCR text.
  static String normalizeExtractedText(String input) {
    if (input.trim().isEmpty) return '';

    return input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        // Replace 3+ consecutive newlines with 2 newlines
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        // Trim each line
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n')
        .trim();
  }

  @override
  Future<void> dispose() async {
    if (_textRecognizer != null) {
      await _textRecognizer!.close();
      _textRecognizer = null;
    }
  }
}

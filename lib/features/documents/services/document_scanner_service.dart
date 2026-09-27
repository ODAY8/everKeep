import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/document_upload.dart';
import '../models/scanned_page.dart';

/// Exception thrown when generated scan exceeds allowed storage limit even
/// after progressive compression.
class ScanTooLargeException implements Exception {
  final int byteLength;
  final int maxBytes;

  const ScanTooLargeException({
    required this.byteLength,
    required this.maxBytes,
  });

  @override
  String toString() =>
      'Scanned document is too large (${(byteLength / (1024 * 1024)).toStringAsFixed(1)} MB). '
      'The maximum allowed size is ${(maxBytes / (1024 * 1024)).toStringAsFixed(0)} MB.';
}

/// Service responsible for image enhancements (cropping, rotation, filters),
/// multi-page PDF generation, size compression, and secure local cleanup.
class DocumentScannerService {
  /// Default storage limit for documents (25 MB).
  static const int defaultMaxDocumentBytes = 25 * 1024 * 1024;

  /// Enhances [rawBytes] by applying rotation, optional normalized crop rect,
  /// and the selected [PageFilter].
  Future<Uint8List> processPage({
    required Uint8List rawBytes,
    int rotationDegrees = 0,
    PageFilter filter = PageFilter.documentHighContrast,
    Rect? cropRect,
    int jpegQuality = 85,
  }) async {
    img.Image? image = img.decodeImage(rawBytes);
    if (image == null) {
      throw StateError('Unable to decode image bytes for processing.');
    }

    // 1. Crop if a valid normalized crop rect is specified.
    if (cropRect != null) {
      final normalized = _clampCropRect(cropRect);
      if (!_isFullRect(normalized)) {
        final x = (normalized.left * image.width).round().clamp(0, image.width - 1);
        final y = (normalized.top * image.height).round().clamp(0, image.height - 1);
        final width = (normalized.width * image.width).round().clamp(1, image.width - x);
        final height = (normalized.height * image.height).round().clamp(1, image.height - y);

        image = img.copyCrop(
          image,
          x: x,
          y: y,
          width: width,
          height: height,
        );
      }
    }

    // 2. Rotate if needed.
    final normalizedRotation = ((rotationDegrees % 360) + 360) % 360;
    if (normalizedRotation != 0) {
      image = img.copyRotate(image, angle: normalizedRotation);
    }

    // 3. Apply visual filter.
    switch (filter) {
      case PageFilter.original:
        // No filter modification
        break;
      case PageFilter.grayscale:
        image = img.grayscale(image);
        break;
      case PageFilter.documentHighContrast:
        image = img.grayscale(image);
        image = img.adjustColor(
          image,
          contrast: 1.5,
          brightness: 1.15,
        );
        break;
      case PageFilter.brighten:
        image = img.adjustColor(
          image,
          brightness: 1.25,
          contrast: 1.1,
        );
        break;
    }

    // 4. Encode as compressed JPEG.
    final encoded = img.encodeJpg(image, quality: jpegQuality);
    return Uint8List.fromList(encoded);
  }

  /// Compiles a list of processed page image bytes into a single standard PDF.
  ///
  /// Automatically applies progressive compression if the resulting PDF exceeds
  /// [maxSizeBytes].
  Future<Uint8List> generatePdf({
    required List<Uint8List> pageImagesBytes,
    int initialQuality = 85,
    int maxSizeBytes = defaultMaxDocumentBytes,
  }) async {
    if (pageImagesBytes.isEmpty) {
      throw ArgumentError('Cannot generate a PDF with zero pages.');
    }

    List<Uint8List> currentBytesList = List<Uint8List>.from(pageImagesBytes);
    int quality = initialQuality;

    while (true) {
      final doc = pw.Document();

      for (final pageBytes in currentBytesList) {
        final pdfImage = pw.MemoryImage(pageBytes);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Image(
                    pdfImage,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        );
      }

      final pdfBytes = await doc.save();
      if (pdfBytes.length <= maxSizeBytes || quality <= 35) {
        if (pdfBytes.length > maxSizeBytes) {
          throw ScanTooLargeException(
            byteLength: pdfBytes.length,
            maxBytes: maxSizeBytes,
          );
        }
        return Uint8List.fromList(pdfBytes);
      }

      // Progressive compression step: reduce JPEG quality and retry.
      quality = math.max(30, quality - 25);
      final compressedList = <Uint8List>[];
      for (final b in currentBytesList) {
        final decoded = img.decodeImage(b);
        if (decoded != null) {
          compressedList.add(Uint8List.fromList(img.encodeJpg(decoded, quality: quality)));
        } else {
          compressedList.add(b);
        }
      }
      currentBytesList = compressedList;
    }
  }

  /// Converts a list of [ScannedPage]s into a ready-to-upload [DocumentUpload].
  ///
  /// For single-page scans with [preferPdfForSinglePage] false, returns JPEG;
  /// otherwise returns a compiled PDF.
  Future<DocumentUpload> createDocumentUpload({
    required List<ScannedPage> pages,
    String? title,
    bool preferPdfForSinglePage = true,
  }) async {
    if (pages.isEmpty) {
      throw ArgumentError('Cannot create DocumentUpload with zero pages.');
    }

    final safeTitle = _sanitizeTitle(title);

    if (pages.length == 1 && !preferPdfForSinglePage) {
      final singlePage = pages.first;
      return DocumentUpload(
        fileName: '$safeTitle.jpg',
        bytes: singlePage.processedBytes,
        mimeType: 'image/jpeg',
      );
    }

    final pageImages = pages.map((p) => p.processedBytes).toList();
    final pdfBytes = await generatePdf(pageImagesBytes: pageImages);

    return DocumentUpload(
      fileName: '$safeTitle.pdf',
      bytes: pdfBytes,
      mimeType: 'application/pdf',
    );
  }

  /// Removes any temporary scan files stored on disk.
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final scannerDir = Directory('${tempDir.path}/scanner_cache');
      if (await scannerDir.exists()) {
        await scannerDir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup; ignore errors
    }
  }

  Rect _clampCropRect(Rect rect) {
    final left = rect.left.clamp(0.0, 0.95);
    final top = rect.top.clamp(0.0, 0.95);
    final right = rect.right.clamp(left + 0.05, 1.0);
    final bottom = rect.bottom.clamp(top + 0.05, 1.0);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _isFullRect(Rect rect) {
    return rect.left <= 0.01 &&
        rect.top <= 0.01 &&
        rect.right >= 0.99 &&
        rect.bottom >= 0.99;
  }

  String _sanitizeTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      final now = DateTime.now();
      return 'Scan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    }
    return title.trim().replaceAll(RegExp(r'[^\w\s\.-]'), '_');
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:everkeep/features/documents/models/scanned_page.dart';
import 'package:everkeep/features/documents/services/document_scanner_service.dart';

Uint8List createTestImageBytes({int width = 100, int height = 100, img.Color? color}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: color ?? img.ColorRgb8(200, 100, 50));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DocumentScannerService service;

  setUp(() {
    service = DocumentScannerService();
  });

  group('DocumentScannerService - Image Processing', () {
    test('processPage applies rotation correctly', () async {
      final inputBytes = createTestImageBytes(width: 80, height: 40);
      final processed = await service.processPage(
        rawBytes: inputBytes,
        rotationDegrees: 90,
        filter: PageFilter.original,
      );

      final decoded = img.decodeImage(processed);
      expect(decoded, isNotNull);
      final nonNullDecoded = decoded!;
      // 80x40 rotated 90 degrees becomes 40x80
      expect(nonNullDecoded.width, 40);
      expect(nonNullDecoded.height, 80);
    });

    test('processPage applies crop correctly', () async {
      final inputBytes = createTestImageBytes(width: 100, height: 100);
      final processed = await service.processPage(
        rawBytes: inputBytes,
        cropRect: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        filter: PageFilter.original,
      );

      final decoded = img.decodeImage(processed);
      expect(decoded, isNotNull);
      final nonNullDecoded = decoded!;
      // 50% of 100x100 is 50x50
      expect(nonNullDecoded.width, 50);
      expect(nonNullDecoded.height, 50);
    });

    test('processPage applies grayscale and document high contrast filters', () async {
      final inputBytes = createTestImageBytes(width: 50, height: 50);

      final grayscale = await service.processPage(
        rawBytes: inputBytes,
        filter: PageFilter.grayscale,
      );
      expect(grayscale, isNotEmpty);

      final highContrast = await service.processPage(
        rawBytes: inputBytes,
        filter: PageFilter.documentHighContrast,
      );
      expect(highContrast, isNotEmpty);

      final brighten = await service.processPage(
        rawBytes: inputBytes,
        filter: PageFilter.brighten,
      );
      expect(brighten, isNotEmpty);
    });

    test('processPage handles 180 and 270 degree rotations', () async {
      final inputBytes = createTestImageBytes(width: 80, height: 40);

      final rot180 = await service.processPage(
        rawBytes: inputBytes,
        rotationDegrees: 180,
      );
      final decoded180 = img.decodeImage(rot180)!;
      expect(decoded180.width, 80);
      expect(decoded180.height, 40);

      final rot270 = await service.processPage(
        rawBytes: inputBytes,
        rotationDegrees: 270,
      );
      final decoded270 = img.decodeImage(rot270)!;
      expect(decoded270.width, 40);
      expect(decoded270.height, 80);
    });
  });

  group('DocumentScannerService - PDF Generation & Upload', () {
    test('generatePdf compiles multiple pages into valid PDF bytes', () async {
      final page1 = createTestImageBytes(width: 100, height: 140);
      final page2 = createTestImageBytes(width: 100, height: 140);

      final pdfBytes = await service.generatePdf(pageImagesBytes: [page1, page2]);
      expect(pdfBytes, isNotEmpty);
      // PDF header magic bytes are %PDF-
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('generatePdf enforces max size check', () async {
      final page = createTestImageBytes(width: 100, height: 140);
      expect(
        () => service.generatePdf(
          pageImagesBytes: [page],
          maxSizeBytes: 10, // Unattainably small
        ),
        throwsA(isA<ScanTooLargeException>()),
      );
    });

    test('createDocumentUpload handles single page as PDF when preferred', () async {
      final imgBytes = createTestImageBytes();
      final page = ScannedPage(
        id: 'p1',
        originalBytes: imgBytes,
        processedBytes: imgBytes,
      );

      final upload = await service.createDocumentUpload(
        pages: [page],
        title: 'Passport Scan',
        preferPdfForSinglePage: true,
      );

      expect(upload.fileName, 'Passport Scan.pdf');
      expect(upload.mimeType, 'application/pdf');
      expect(upload.bytes, isNotEmpty);
      expect(String.fromCharCodes(upload.bytes.sublist(0, 5)), '%PDF-');
    });

    test('createDocumentUpload handles single page as JPEG when requested', () async {
      final imgBytes = createTestImageBytes();
      final page = ScannedPage(
        id: 'p1',
        originalBytes: imgBytes,
        processedBytes: imgBytes,
      );

      final upload = await service.createDocumentUpload(
        pages: [page],
        title: 'Receipt',
        preferPdfForSinglePage: false,
      );

      expect(upload.fileName, 'Receipt.jpg');
      expect(upload.mimeType, 'image/jpeg');
      expect(upload.bytes, imgBytes);
    });

    test('createDocumentUpload compiles multiple pages into PDF', () async {
      final img1 = createTestImageBytes();
      final img2 = createTestImageBytes();
      final pages = [
        ScannedPage(id: 'p1', originalBytes: img1, processedBytes: img1),
        ScannedPage(id: 'p2', originalBytes: img2, processedBytes: img2),
      ];

      final upload = await service.createDocumentUpload(
        pages: pages,
        title: 'Tax Document',
      );

      expect(upload.fileName, 'Tax Document.pdf');
      expect(upload.mimeType, 'application/pdf');
      expect(String.fromCharCodes(upload.bytes.sublist(0, 5)), '%PDF-');
    });
  });
}

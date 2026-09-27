import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/features/documents/models/ocr_result.dart';
import 'package:everkeep/features/documents/services/ocr_service.dart';
import 'support/fake_ocr_service.dart';

void main() {
  group('OCR Models', () {
    test('OcrPageResult holds page number, text, and confidence', () {
      const page = OcrPageResult(
        pageNumber: 1,
        text: 'Passport No: A12345678\nName: John Doe',
        confidence: 0.95,
      );

      expect(page.pageNumber, 1);
      expect(page.text, contains('Passport No'));
      expect(page.confidence, 0.95);

      final json = page.toJson();
      expect(json['pageNumber'], 1);
      expect(json['confidence'], 0.95);

      final restored = OcrPageResult.fromJson(json);
      expect(restored.pageNumber, page.pageNumber);
      expect(restored.text, page.text);
      expect(restored.confidence, page.confidence);
    });

    test('OcrDocumentResult combinedText formats single page cleanly', () {
      final docResult = OcrDocumentResult.fromPages(
        const [
          OcrPageResult(pageNumber: 1, text: 'Single page invoice content'),
        ],
        processedAt: DateTime(2026, 9, 27, 12, 0),
      );

      expect(docResult.combinedText, 'Single page invoice content');
      expect(docResult.hasText, isTrue);
      expect(docResult.pageCount, 1);
    });

    test('OcrDocumentResult combinedText orders and formats multiple pages with page headers', () {
      final docResult = OcrDocumentResult.fromPages(
        const [
          OcrPageResult(pageNumber: 1, text: 'Page one text'),
          OcrPageResult(pageNumber: 2, text: 'Page two text'),
          OcrPageResult(pageNumber: 3, text: 'Page three text'),
        ],
      );

      final formatted = docResult.combinedText;
      expect(formatted, contains('--- Page 1 ---'));
      expect(formatted, contains('Page one text'));
      expect(formatted, contains('--- Page 2 ---'));
      expect(formatted, contains('Page two text'));
      expect(formatted, contains('--- Page 3 ---'));
      expect(formatted, contains('Page three text'));

      // Check ordering
      final idx1 = formatted.indexOf('Page 1');
      final idx2 = formatted.indexOf('Page 2');
      final idx3 = formatted.indexOf('Page 3');
      expect(idx1 < idx2, isTrue);
      expect(idx2 < idx3, isTrue);
    });

    test('OcrDocumentResult.fromCombinedText parses multi-page text format', () {
      const combined = '''--- Page 1 ---
First page document text

--- Page 2 ---
Second page document text''';

      final parsed = OcrDocumentResult.fromCombinedText(combined);
      expect(parsed.pages.length, 2);
      expect(parsed.pages[0].pageNumber, 1);
      expect(parsed.pages[0].text, 'First page document text');
      expect(parsed.pages[1].pageNumber, 2);
      expect(parsed.pages[1].text, 'Second page document text');
    });

    test('OcrDocumentResult.fromCombinedText parses unstructured single page', () {
      const singlePage = 'Flat plain OCR text without page headers';
      final parsed = OcrDocumentResult.fromCombinedText(singlePage);

      expect(parsed.pages.length, 1);
      expect(parsed.pages[0].pageNumber, 1);
      expect(parsed.pages[0].text, singlePage);
      expect(parsed.combinedText, singlePage);
    });

    test('OcrDocumentResult serialization and copyWith', () {
      final now = DateTime.now();
      final original = OcrDocumentResult.fromPages(
        const [
          OcrPageResult(pageNumber: 1, text: 'Hello World', confidence: 0.9),
        ],
        processedAt: now,
      );

      final json = original.toJson();
      final restored = OcrDocumentResult.fromJson(json);

      expect(restored.pages.length, 1);
      expect(restored.pages[0].text, 'Hello World');
      expect(restored.combinedText, original.combinedText);

      final copied = original.copyWith(
        pages: const [
          OcrPageResult(pageNumber: 1, text: 'Modified text', confidence: 1.0),
        ],
      );
      expect(copied.combinedText, 'Modified text');
    });
  });

  group('OcrService Implementations', () {
    late FakeOcrService fakeService;

    setUp(() {
      fakeService = FakeOcrService();
    });

    test('FakeOcrService processes image bytes successfully with mock response', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      fakeService.nextResult = OcrDocumentResult.fromPages(
        const [
          OcrPageResult(
            pageNumber: 1,
            text: 'United States Passport\nSurname: DOE\nGiven: JOHN',
            confidence: 0.98,
          ),
        ],
      );

      final result = await fakeService.processImageBytes(dummyBytes);

      expect(result.pages.length, 1);
      expect(result.combinedText, contains('United States Passport'));
      expect(fakeService.processImageCallCount, 1);
    });

    test('FakeOcrService handles empty text result gracefully', () async {
      final dummyBytes = Uint8List.fromList([0, 0, 0]);
      fakeService.nextResult = OcrDocumentResult.fromPages(
        const [
          OcrPageResult(pageNumber: 1, text: '', confidence: 0.0),
        ],
      );

      final result = await fakeService.processImageBytes(dummyBytes);

      expect(result.hasText, isFalse);
      expect(result.combinedText, isEmpty);
    });

    test('FakeOcrService throws when error is configured', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3]);
      fakeService.shouldFail = true;
      fakeService.failureMessage = 'Image could not be parsed by OCR engine';

      expect(
        () => fakeService.processImageBytes(dummyBytes),
        throwsA(isA<OcrException>()),
      );
    });

    test('FakeOcrService handles multi-page document images', () async {
      final page1 = Uint8List.fromList([10, 20]);
      final page2 = Uint8List.fromList([30, 40]);

      final progressUpdates = <double>[];
      final statusUpdates = <String>[];

      final result = await fakeService.processMultiPageImageBytes(
        [page1, page2],
        onProgress: (p, msg) {
          progressUpdates.add(p);
          statusUpdates.add(msg);
        },
      );

      expect(result.pages.length, 2);
      expect(result.pages[0].pageNumber, 1);
      expect(result.pages[1].pageNumber, 2);
      expect(progressUpdates, isNotEmpty);
      expect(progressUpdates.last, 1.0);
    });

    test('FakeOcrService PDF page extraction combines text in correct page order', () async {
      final pdfBytes = Uint8List.fromList([37, 80, 68, 70]); // %PDF
      final progressList = <double>[];

      fakeService.nextResult = OcrDocumentResult.fromPages(
        const [
          OcrPageResult(pageNumber: 1, text: 'PDF page 1 text'),
          OcrPageResult(pageNumber: 2, text: 'PDF page 2 text'),
        ],
      );

      final result = await fakeService.processPdfBytes(
        pdfBytes,
        onProgress: (p, msg) => progressList.add(p),
      );

      expect(result.pages.length, 2);
      expect(result.combinedText, contains('--- Page 1 ---'));
      expect(result.combinedText, contains('--- Page 2 ---'));
      expect(progressList.last, 1.0);
    });

    test('MlKitOcrService normalizeExtractedText helper collapses consecutive blank lines and trims', () {
      const messyText = '  Line 1   \n\n\n\n   Line 2  \n\n  \n  Line 3  ';
      final cleaned = MlKitOcrService.normalizeExtractedText(messyText);

      expect(cleaned, 'Line 1\n\nLine 2\n\nLine 3');
    });

    test('MlKitOcrService isSupportedFile checks image and pdf extensions', () {
      expect(MlKitOcrService.isSupportedFile('document.jpg'), isTrue);
      expect(MlKitOcrService.isSupportedFile('document.jpeg'), isTrue);
      expect(MlKitOcrService.isSupportedFile('document.png'), isTrue);
      expect(MlKitOcrService.isSupportedFile('document.webp'), isTrue);
      expect(MlKitOcrService.isSupportedFile('document.pdf'), isTrue);
      expect(MlKitOcrService.isSupportedFile('document.PDF'), isTrue);
      expect(MlKitOcrService.isSupportedFile('document.txt'), isFalse);
      expect(MlKitOcrService.isSupportedFile('document.docx'), isFalse);
      expect(MlKitOcrService.isSupportedFile(null), isFalse);
    });
  });
}

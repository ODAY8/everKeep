import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/features/documents/models/ocr_result.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'fakes.dart';
import 'support/fake_ocr_service.dart';

void main() {
  group('DocumentProvider OCR integration', () {
    late FakeDocumentRepository fakeRepo;
    late FakeOcrService fakeOcr;
    late DocumentProvider provider;

    setUp(() {
      fakeRepo = FakeDocumentRepository([]);
      fakeOcr = FakeOcrService();
      provider = DocumentProvider(
        documentRepository: fakeRepo,
        ocrService: fakeOcr,
      );
    });

    test('extractTextForDocument successfully extracts text with rawBytes and saves to repository', () async {
      final doc = DocumentItem(
        id: 'doc-1',
        title: 'Medical Invoice',
        subtitle: 'Health · Added today',
        category: 'Health',
        filePath: 'user/doc-1.jpg',
      );
      await fakeRepo.addDocument(doc);
      await provider.fetchDocuments();

      fakeOcr.nextResult = OcrDocumentResult.fromPages(
        const [
          OcrPageResult(
            pageNumber: 1,
            text: 'Clinic Name: City Hospital\nTotal Due: \$150.00',
            confidence: 0.99,
          ),
        ],
      );

      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);
      final result = await provider.extractTextForDocument(
        doc,
        rawBytes: dummyBytes,
      );

      expect(result, isNotNull);
      expect(result!.combinedText, contains('City Hospital'));
      expect(result.combinedText, contains('\$150.00'));

      // Check document was updated in repository and provider
      final updated = provider.documents.firstWhere((d) => d.id == 'doc-1');
      expect(updated.ocrText, contains('City Hospital'));
      expect(updated.hasOcrText, isTrue);
      expect(provider.isOcrProcessing('doc-1'), isFalse);
      expect(provider.getOcrError('doc-1'), isNull);
    });

    test('extractTextForDocument prevents duplicate concurrent runs on same document', () async {
      final doc = DocumentItem(
        id: 'doc-2',
        title: 'Electric Bill',
        subtitle: 'Utility · Added today',
        category: 'Utility',
        filePath: 'user/doc-2.jpg',
      );
      await fakeRepo.addDocument(doc);
      await provider.fetchDocuments();

      final dummyBytes = Uint8List.fromList([5, 6, 7]);

      // Launch first run
      final future1 = provider.extractTextForDocument(doc, rawBytes: dummyBytes);

      // Attempt second concurrent run immediately
      final duplicateResult = await provider.extractTextForDocument(
        doc,
        rawBytes: dummyBytes,
      );

      expect(duplicateResult, isNull);

      final result1 = await future1;
      expect(result1, isNotNull);
    });

    test('extractTextForDocument handles and records OCR service errors', () async {
      final doc = DocumentItem(
        id: 'doc-3',
        title: 'Damaged Scan',
        subtitle: 'Other · Added today',
        category: 'Other',
        filePath: 'user/doc-3.png',
      );
      await fakeRepo.addDocument(doc);
      await provider.fetchDocuments();

      fakeOcr.shouldFail = true;
      fakeOcr.failureMessage = 'Corrupted image bytes';

      final dummyBytes = Uint8List.fromList([9, 9, 9]);
      final result = await provider.extractTextForDocument(
        doc,
        rawBytes: dummyBytes,
      );

      expect(result, isNull);
      expect(provider.isOcrProcessing('doc-3'), isFalse);
      expect(provider.getOcrError('doc-3'), contains('Corrupted image bytes'));

      // Clear error test
      provider.clearOcrError('doc-3');
      expect(provider.getOcrError('doc-3'), isNull);
    });

    test('extractTextForDocument fails gracefully if document has no file attached', () async {
      final docWithoutFile = DocumentItem(
        id: 'doc-no-file',
        title: 'Note Only',
        subtitle: 'Personal · Added today',
        category: 'Personal',
      );
      await fakeRepo.addDocument(docWithoutFile);
      await provider.fetchDocuments();

      final result = await provider.extractTextForDocument(docWithoutFile);

      expect(result, isNull);
      expect(
        provider.getOcrError('doc-no-file'),
        contains('no attached file'),
      );
    });

    test('saveOcrText persists manual corrections to document in repository', () async {
      final doc = DocumentItem(
        id: 'doc-edit',
        title: 'Contract',
        subtitle: 'Legal · Added today',
        category: 'Legal',
        filePath: 'user/doc-edit.pdf',
        ocrText: 'Original text with typos',
      );
      await fakeRepo.addDocument(doc);
      await provider.fetchDocuments();

      final success = await provider.saveOcrText(
        doc,
        'Corrected text without typos',
      );

      expect(success, isTrue);
      final updated = provider.documents.firstWhere((d) => d.id == 'doc-edit');
      expect(updated.ocrText, 'Corrected text without typos');
    });

    test('reset clears all OCR progress, status, and error maps on sign out', () async {
      final doc = DocumentItem(
        id: 'doc-reset',
        title: 'Temporary Doc',
        subtitle: 'Work · Added today',
        category: 'Work',
        filePath: 'user/temp.png',
      );
      await fakeRepo.addDocument(doc);
      await provider.fetchDocuments();

      fakeOcr.shouldFail = true;
      fakeOcr.failureMessage = 'Engine error';
      await provider.extractTextForDocument(
        doc,
        rawBytes: Uint8List.fromList([1]),
      );

      expect(provider.getOcrError('doc-reset'), isNotNull);

      // Sign out / reset
      provider.reset();

      expect(provider.getOcrError('doc-reset'), isNull);
      expect(provider.isOcrProcessing('doc-reset'), isFalse);
      expect(provider.getOcrProgress('doc-reset'), 0.0);
      expect(provider.getOcrStatusMessage('doc-reset'), isNull);
    });
  });
}

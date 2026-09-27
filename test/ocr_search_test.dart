import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/core/utils/search_helper.dart';
import 'package:everkeep/models/document_item.dart';

void main() {
  group('OCR Search Integration (SearchMatcher)', () {
    final docWithOcr1 = DocumentItem(
      id: 'doc-1',
      title: 'Scanned Document #101',
      subtitle: 'Health · Added today',
      category: 'Health',
      documentType: 'medical',
      filePath: 'vault/scan101.jpg',
      ocrText: 'Patient Name: Jane Doe\nDiagnosis: Acute Bronchitis\nPrescribed: Amoxicillin 500mg',
    );

    final docWithOcr2 = DocumentItem(
      id: 'doc-2',
      title: 'Receipt #882',
      subtitle: 'Finance · Added yesterday',
      category: 'Finance',
      documentType: 'receipt',
      filePath: 'vault/receipt882.png',
      ocrText: 'Store: Alpine Outdoor Gear\nItem: Waterproof Hiking Boots\nTotal: \$189.95',
    );

    final docWithoutOcr = DocumentItem(
      id: 'doc-3',
      title: 'Blank Identification Card',
      subtitle: 'Identity · Added today',
      category: 'Identity',
      documentType: 'id_card',
      filePath: 'vault/id.pdf',
      ocrText: null,
    );

    final docWithEmptyOcr = DocumentItem(
      id: 'doc-4',
      title: 'Empty Scanned Page',
      subtitle: 'Other · Added today',
      category: 'Other',
      filePath: 'vault/empty.png',
      ocrText: '   \n  ',
    );

    test('matches document when query matches word in OCR text exactly', () {
      final matches = SearchMatcher.matchesDocument(docWithOcr1, query: 'Amoxicillin');
      expect(matches, isTrue);

      final noMatch = SearchMatcher.matchesDocument(docWithOcr2, query: 'Amoxicillin');
      expect(noMatch, isFalse);
    });

    test('matches document case-insensitively in OCR text', () {
      expect(SearchMatcher.matchesDocument(docWithOcr1, query: 'bronchitis'), isTrue);
      expect(SearchMatcher.matchesDocument(docWithOcr1, query: 'BRONCHITIS'), isTrue);
      expect(SearchMatcher.matchesDocument(docWithOcr1, query: 'BrOnChItIs'), isTrue);
    });

    test('matches partial substrings in OCR text', () {
      // "Waterproof" in docWithOcr2
      expect(SearchMatcher.matchesDocument(docWithOcr2, query: 'water'), isTrue);
      expect(SearchMatcher.matchesDocument(docWithOcr2, query: 'proof'), isTrue);
      expect(SearchMatcher.matchesDocument(docWithOcr2, query: 'hiking'), isTrue);
    });

    test('matches multi-token queries combining document title and OCR text', () {
      // Title: "Receipt #882", OCR text: "Alpine Outdoor Gear"
      expect(
        SearchMatcher.matchesDocument(docWithOcr2, query: 'Receipt Alpine'),
        isTrue,
      );
      expect(
        SearchMatcher.matchesDocument(docWithOcr2, query: '882 boots'),
        isTrue,
      );
      // One token matches, other does not
      expect(
        SearchMatcher.matchesDocument(docWithOcr2, query: 'Receipt Hospital'),
        isFalse,
      );
    });

    test('null or whitespace-only OCR text does not throw and handles safely', () {
      expect(SearchMatcher.matchesDocument(docWithoutOcr, query: 'Amoxicillin'), isFalse);
      expect(SearchMatcher.matchesDocument(docWithEmptyOcr, query: 'Amoxicillin'), isFalse);

      // Blank query matches everything
      expect(SearchMatcher.matchesDocument(docWithoutOcr, query: ''), isTrue);
      expect(SearchMatcher.matchesDocument(docWithEmptyOcr, query: '   '), isTrue);
    });

    test('filters list of documents correctly based on OCR content', () {
      final allDocs = [docWithOcr1, docWithOcr2, docWithoutOcr, docWithEmptyOcr];

      final gearResults = allDocs.where(
        (d) => SearchMatcher.matchesDocument(d, query: 'Alpine'),
      ).toList();
      expect(gearResults.length, 1);
      expect(gearResults.first.id, 'doc-2');

      final patientResults = allDocs.where(
        (d) => SearchMatcher.matchesDocument(d, query: 'Patient'),
      ).toList();
      expect(patientResults.length, 1);
      expect(patientResults.first.id, 'doc-1');

      final nonExistentResults = allDocs.where(
        (d) => SearchMatcher.matchesDocument(d, query: 'NonExistentTermXYZ'),
      ).toList();
      expect(nonExistentResults, isEmpty);
    });

    test('multiple documents containing same term in OCR text are all returned', () {
      final sharedDocA = DocumentItem(
        id: 'share-1',
        title: 'Tax 2024',
        subtitle: 'Finance · Added today',
        category: 'Finance',
        ocrText: 'Internal Revenue Service W-2 Form',
      );
      final sharedDocB = DocumentItem(
        id: 'share-2',
        title: 'Tax 2025',
        subtitle: 'Finance · Added today',
        category: 'Finance',
        ocrText: 'Internal Revenue Service 1099-MISC Form',
      );

      final all = [sharedDocA, sharedDocB, docWithOcr1];
      final matches = all.where(
        (d) => SearchMatcher.matchesDocument(d, query: 'Internal Revenue'),
      ).toList();

      expect(matches.length, 2);
      expect(matches.map((m) => m.id), containsAll(['share-1', 'share-2']));
    });
  });
}

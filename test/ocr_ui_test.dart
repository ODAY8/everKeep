import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/features/documents/presentation/widgets/ocr/ocr_section.dart';
import 'package:everkeep/features/documents/presentation/widgets/ocr/ocr_text_viewer_sheet.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'fakes.dart';
import 'support/fake_ocr_service.dart';

void main() {
  group('OcrSection Widget Tests', () {
    late FakeDocumentRepository fakeRepo;
    late FakeOcrService fakeOcr;
    late DocumentProvider provider;

    final docWithoutOcr = DocumentItem(
      id: 'doc-no-ocr',
      title: 'Auto Insurance Policy',
      subtitle: 'Insurance · Added today',
      category: 'Insurance',
      filePath: 'vault/auto.pdf',
    );

    final docWithOcr = DocumentItem(
      id: 'doc-has-ocr',
      title: 'Rental Agreement',
      subtitle: 'Housing · Added today',
      category: 'Housing',
      filePath: 'vault/rental.png',
      ocrText: 'Landlord: Apex Properties LLC\nTenant: John Smith\nMonthly Rent: \$2,100',
    );

    final docNoFile = DocumentItem(
      id: 'doc-no-file',
      title: 'Notes only doc',
      subtitle: 'Personal · Added today',
      category: 'Personal',
      filePath: null,
    );

    setUp(() {
      fakeRepo = FakeDocumentRepository([docWithoutOcr, docWithOcr, docNoFile]);
      fakeOcr = FakeOcrService();
      provider = DocumentProvider(
        documentRepository: fakeRepo,
        ocrService: fakeOcr,
      );
    });

    testWidgets('renders prompt and Extract Text button when document has file but no OCR text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: OcrSection(document: docWithoutOcr),
            ),
          ),
        ),
      );

      expect(find.text('EXTRACTED TEXT (OCR)'), findsOneWidget);
      expect(find.text('Make this document searchable'), findsOneWidget);
      expect(find.byKey(const ValueKey('extract_text_button')), findsOneWidget);
      expect(find.text('Extract Text'), findsOneWidget);
    });

    testWidgets('does not render when document has no file attached', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: OcrSection(document: docNoFile),
            ),
          ),
        ),
      );

      expect(find.text('EXTRACTED TEXT (OCR)'), findsNothing);
      expect(find.text('Make this document searchable'), findsNothing);
    });

    testWidgets('renders text preview and view/edit button when document has OCR text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: OcrSection(document: docWithOcr),
            ),
          ),
        ),
      );

      expect(find.text('EXTRACTED TEXT (OCR)'), findsOneWidget);
      expect(find.textContaining('Apex Properties LLC'), findsOneWidget);
      expect(find.text('Searchable in vault'), findsOneWidget);
      expect(find.byKey(const ValueKey('view_ocr_text_button')), findsOneWidget);
      expect(find.text('Re-extract'), findsOneWidget);
    });

    testWidgets('tapping Re-extract displays confirmation dialog warning about overwrite', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: OcrSection(document: docWithOcr),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Re-extract'));
      await tester.pumpAndSettle();

      expect(find.text('Re-run OCR?'), findsOneWidget);
      expect(
        find.textContaining('will overwrite your current extracted text'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);

      // Cancel dismisses dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Re-run OCR?'), findsNothing);
    });
  });

  group('OcrTextViewerSheet Widget Tests', () {
    late FakeDocumentRepository fakeRepo;
    late FakeOcrService fakeOcr;
    late DocumentProvider provider;

    final singlePageDoc = DocumentItem(
      id: 'doc-single',
      title: 'Lab Report',
      subtitle: 'Health · Added today',
      category: 'Health',
      filePath: 'vault/lab.jpg',
      ocrText: 'Complete Blood Count\nWBC: 6.5\nRBC: 4.8\nHemoglobin: 15.2',
    );

    final multiPageDoc = DocumentItem(
      id: 'doc-multi',
      title: 'Lease Agreement Multi-page',
      subtitle: 'Legal · Added today',
      category: 'Legal',
      filePath: 'vault/lease.pdf',
      ocrText: '--- Page 1 ---\nLease Terms and Conditions\nParties: Landlord and Tenant\n\n--- Page 2 ---\nSecurity Deposit and Maintenance\nDeposit Amount: \$2000',
    );

    setUp(() async {
      fakeRepo = FakeDocumentRepository([singlePageDoc, multiPageDoc]);
      fakeOcr = FakeOcrService();
      provider = DocumentProvider(
        documentRepository: fakeRepo,
        ocrService: fakeOcr,
      );
      await provider.fetchDocuments();
    });

    testWidgets('renders extracted text viewer in view mode with copy and edit actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: OcrTextViewerSheet(document: singlePageDoc),
            ),
          ),
        ),
      );

      expect(find.text('Extracted Text'), findsOneWidget);
      expect(find.text('Lab Report'), findsOneWidget);
      expect(find.byKey(const ValueKey('ocr_copy_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('ocr_edit_button')), findsOneWidget);
      expect(find.textContaining('Complete Blood Count'), findsOneWidget);
      expect(find.byKey(const ValueKey('ocr_search_input')), findsOneWidget);
    });

    testWidgets('renders page choice chips for multi-page documents and switches pages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: OcrTextViewerSheet(document: multiPageDoc),
            ),
          ),
        ),
      );

      expect(find.text('All Pages'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);

      // Tap Page 1 chip
      await tester.tap(find.text('Page 1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Lease Terms and Conditions'), findsOneWidget);
      expect(find.textContaining('Security Deposit and Maintenance'), findsNothing);

      // Tap Page 2 chip
      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Security Deposit and Maintenance'), findsOneWidget);
      expect(find.textContaining('Lease Terms and Conditions'), findsNothing);
    });

    testWidgets('toggles into edit mode, modifies text, and saves corrections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: OcrTextViewerSheet(document: singlePageDoc),
            ),
          ),
        ),
      );

      // Enter edit mode
      await tester.tap(find.byKey(const ValueKey('ocr_edit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Extracted Text'), findsOneWidget);
      expect(find.byKey(const ValueKey('ocr_edit_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('ocr_edit_cancel_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('ocr_edit_save_button')), findsOneWidget);

      // Edit text in TextField
      await tester.enterText(
        find.byKey(const ValueKey('ocr_edit_input')),
        'Updated Blood Count: Normal',
      );
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.byKey(const ValueKey('ocr_edit_save_button')));
      await tester.pumpAndSettle();

      // Returns to view mode
      expect(find.text('Extracted Text'), findsOneWidget);
      expect(find.textContaining('Updated Blood Count: Normal'), findsOneWidget);
    });
  });
}

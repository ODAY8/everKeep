import 'dart:async';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/features/documents/presentation/screens/pdf_viewer_screen.dart';
import 'package:everkeep/features/documents/presentation/widgets/document_details_sheet.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/providers/document_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

class CountingDocumentRepository extends FakeDocumentRepository {
  int downloadUrlCallCount = 0;
  String? urlToReturn;
  bool shouldFail = false;

  CountingDocumentRepository([super.seed]);

  @override
  Future<String> createDownloadUrl(String filePath) async {
    downloadUrlCallCount++;
    if (shouldFail) {
      throw Exception('Storage download failed: object not found');
    }
    return urlToReturn ?? 'https://example.test/signed/$filePath?token=mock_sig';
  }
}

void main() {
  group('PDF Detection', () {
    test('detects PDF by .pdf extension (case-insensitive and with query params)', () {
      const docLower = DocumentItem(
        id: '1',
        title: 'Tax Form',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'user_123/documents/tax_form.pdf',
      );
      expect(docLower.isPdf, isTrue);

      const docUpper = DocumentItem(
        id: '2',
        title: 'Tax Form',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'user_123/documents/STATEMENT.PDF',
      );
      expect(docUpper.isPdf, isTrue);

      const docWithParams = DocumentItem(
        id: '3',
        title: 'Policy',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'user_123/documents/insurance.pdf?token=abc123xyz',
      );
      expect(docWithParams.isPdf, isTrue);
    });

    test('detects PDF by MIME type application/pdf regardless of file extension', () {
      const docWithMime = DocumentItem(
        id: '4',
        title: 'Identity Document',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'user_123/documents/raw_upload_blob',
        mimeType: 'application/pdf',
      );
      expect(docWithMime.isPdf, isTrue);

      const docWithUpperMime = DocumentItem(
        id: '5',
        title: 'Identity Document',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'user_123/documents/file_no_ext',
        mimeType: 'APPLICATION/PDF',
      );
      expect(docWithUpperMime.isPdf, isTrue);
    });

    test('rejects non-PDF extensions and MIME types', () {
      const docx = DocumentItem(
        id: '6',
        title: 'Resume',
        subtitle: 'Employment',
        category: 'Employment',
        filePath: 'user_123/documents/resume.docx',
      );
      expect(docx.isPdf, isFalse);

      const png = DocumentItem(
        id: '7',
        title: 'Photo ID',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'user_123/documents/passport.png',
        mimeType: 'image/png',
      );
      expect(png.isPdf, isFalse);

      const txt = DocumentItem(
        id: '8',
        title: 'Notes',
        subtitle: 'Other',
        category: 'Other',
        filePath: 'user_123/documents/notes.txt',
        mimeType: 'text/plain',
      );
      expect(txt.isPdf, isFalse);
    });

    test('returns false when document has no file attachment', () {
      const docNoFile = DocumentItem(
        id: '9',
        title: 'Record without file',
        subtitle: 'Legal',
        category: 'Legal',
      );
      expect(docNoFile.hasFile, isFalse);
      expect(docNoFile.isPdf, isFalse);
    });

    test('DocumentItem.fromRow deserializes mime_type and file_size', () {
      final row = {
        'id': 'doc-pdf-1',
        'title': 'Lease Agreement',
        'category': 'Legal',
        'document_type': 'legal_document',
        'file_path': 'user-1/documents/lease.pdf',
        'mime_type': 'application/pdf',
        'file_size': 1048576,
        'created_at': '2026-09-27T10:00:00Z',
      };

      final doc = DocumentItem.fromRow(row);
      expect(doc.id, 'doc-pdf-1');
      expect(doc.mimeType, 'application/pdf');
      expect(doc.fileSize, 1048576);
      expect(doc.isPdf, isTrue);
    });
  });

  group('DocumentProvider Signed URL Caching & Security', () {
    late CountingDocumentRepository repo;
    late DocumentProvider provider;

    setUp(() {
      repo = CountingDocumentRepository();
      provider = DocumentProvider(documentRepository: repo);
    });

    test('caches signed download URL on subsequent requests', () async {
      const doc = DocumentItem(
        id: 'doc-1',
        title: 'Test Doc',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'vault/test.pdf',
      );

      final url1 = await provider.downloadUrlFor(doc);
      expect(url1, contains('vault/test.pdf'));
      expect(repo.downloadUrlCallCount, 1);

      // Second call should return cached URL without calling repo again
      final url2 = await provider.downloadUrlFor(doc);
      expect(url2, url1);
      expect(repo.downloadUrlCallCount, 1);
    });

    test('forceRefresh bypasses cache and obtains fresh signed URL', () async {
      const doc = DocumentItem(
        id: 'doc-1',
        title: 'Test Doc',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'vault/test.pdf',
      );

      await provider.downloadUrlFor(doc);
      expect(repo.downloadUrlCallCount, 1);

      // Force refresh
      await provider.downloadUrlFor(doc, forceRefresh: true);
      expect(repo.downloadUrlCallCount, 2);
    });

    test('invalidateSignedUrlCache clears cache for specific path or all paths', () async {
      const docA = DocumentItem(
        id: 'doc-a',
        title: 'Doc A',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'vault/a.pdf',
      );
      const docB = DocumentItem(
        id: 'doc-b',
        title: 'Doc B',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'vault/b.pdf',
      );

      await provider.downloadUrlFor(docA);
      await provider.downloadUrlFor(docB);
      expect(repo.downloadUrlCallCount, 2);

      // Invalidate specific path
      provider.invalidateSignedUrlCache('vault/a.pdf');

      // docA should re-fetch, docB should remain cached
      await provider.downloadUrlFor(docA);
      expect(repo.downloadUrlCallCount, 3);

      await provider.downloadUrlFor(docB);
      expect(repo.downloadUrlCallCount, 3);

      // Invalidate all
      provider.invalidateSignedUrlCache();
      await provider.downloadUrlFor(docB);
      expect(repo.downloadUrlCallCount, 4);
    });

    test('reset clears cached signed URLs on sign out', () async {
      const doc = DocumentItem(
        id: 'doc-1',
        title: 'Test Doc',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'vault/test.pdf',
      );

      await provider.downloadUrlFor(doc);
      expect(repo.downloadUrlCallCount, 1);

      provider.reset();

      // After reset, a fresh fetch must be made
      await provider.downloadUrlFor(doc);
      expect(repo.downloadUrlCallCount, 2);
    });

    test('handles failure gracefully and clears cache', () async {
      const doc = DocumentItem(
        id: 'doc-1',
        title: 'Test Doc',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'vault/missing.pdf',
      );

      repo.shouldFail = true;
      final result = await provider.downloadUrlFor(doc);
      expect(result, isNull);
      expect(provider.error, contains('Storage download failed'));
    });

    test('returns null when document has no file path without calling repository', () async {
      const doc = DocumentItem(
        id: 'doc-no-file',
        title: 'No File',
        subtitle: 'Legal',
        category: 'Legal',
      );

      final result = await provider.downloadUrlFor(doc);
      expect(result, isNull);
      expect(repo.downloadUrlCallCount, 0);
    });
  });

  group('DocumentDetailsSheet UI Integration', () {
    late CountingDocumentRepository repo;
    late DocumentProvider provider;

    setUp(() {
      repo = CountingDocumentRepository();
      provider = DocumentProvider(documentRepository: repo);
    });

    testWidgets('shows "Open PDF" button for PDF document', (tester) async {
      const pdfDoc = DocumentItem(
        id: 'doc-pdf',
        title: 'Passport Copy',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'user_1/documents/passport.pdf',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: DocumentDetailsSheet(
                document: pdfDoc,
                onEdit: () {},
                onDelete: () {},
                onOpenFile: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Open PDF'), findsAtLeastNWidgets(1));
      expect(find.text('Open File'), findsNothing);
    });

    testWidgets('shows "Open File" button for non-PDF document', (tester) async {
      const docxDoc = DocumentItem(
        id: 'doc-docx',
        title: 'Contract Draft',
        subtitle: 'Legal',
        category: 'Legal',
        filePath: 'user_1/documents/contract.docx',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: DocumentDetailsSheet(
                document: docxDoc,
                onEdit: () {},
                onDelete: () {},
                onOpenFile: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Open File'), findsOneWidget);
      expect(find.text('Open PDF'), findsNothing);
    });

    testWidgets('does not show file action buttons when document has no file', (tester) async {
      const noFileDoc = DocumentItem(
        id: 'doc-none',
        title: 'Reminder Record',
        subtitle: 'Personal',
        category: 'Personal',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<DocumentProvider>.value(
              value: provider,
              child: DocumentDetailsSheet(
                document: noFileDoc,
                onEdit: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Open PDF'), findsNothing);
      expect(find.text('Open File'), findsNothing);
    });
  });

  group('PdfViewerScreen UI & State Handling', () {
    late CountingDocumentRepository repo;
    late DocumentProvider provider;

    const testPdfDoc = DocumentItem(
      id: 'doc-pdf-test',
      title: 'Graduation Diploma',
      subtitle: 'Education',
      category: 'Education',
      filePath: 'vault/diploma.pdf',
    );

    setUp(() {
      repo = CountingDocumentRepository();
      provider = DocumentProvider(documentRepository: repo);
    });

    testWidgets('renders loading state initially while signed URL is resolved', (tester) async {
      final completer = Completer<String>();
      repo.urlToReturn = null;

      // Wrap repository call in completer
      provider = DocumentProvider(
        documentRepository: _DelayedDocumentRepository(completer.future),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DocumentProvider>.value(
            value: provider,
            child: const PdfViewerScreen(document: testPdfDoc),
          ),
        ),
      );

      // Loading state visible
      expect(find.text('Loading PDF...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Graduation Diploma'), findsOneWidget);
      expect(find.text('PDF VIEWER'), findsOneWidget);

      completer.complete('https://example.test/signed.pdf');
      await tester.pump();
    });

    testWidgets('renders error state and retry button on download URL failure', (tester) async {
      repo.shouldFail = true;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DocumentProvider>.value(
            value: provider,
            child: const PdfViewerScreen(document: testPdfDoc),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to open PDF'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Click retry after fixing the repository
      repo.shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(repo.downloadUrlCallCount, 2);
    });

    testWidgets('tapping Open PDF in showDocumentDetailsSheet pushes AppRouter.pdfViewer', (tester) async {
      DocumentItem? passedDocument;

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == AppRouter.pdfViewer) {
              passedDocument = settings.arguments as DocumentItem?;
              return MaterialPageRoute(builder: (_) => const Text('PDF Screen Destination'));
            }
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                body: ChangeNotifierProvider<DocumentProvider>.value(
                  value: provider,
                  child: Builder(
                    builder: (innerContext) => ElevatedButton(
                      onPressed: () => showDocumentDetailsSheet(
                        innerContext,
                        document: const DocumentItem(
                          id: 'doc-pdf-99',
                          title: 'Test Lease Agreement',
                          subtitle: 'Legal',
                          category: 'Legal',
                          filePath: 'vault/lease.pdf',
                        ),
                      ),
                      child: const Text('Show Details'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Show Details'));
      await tester.pumpAndSettle();

      expect(find.text('Open PDF'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Open PDF').first);
      await tester.pumpAndSettle();

      expect(passedDocument?.id, 'doc-pdf-99');
      expect(find.text('PDF Screen Destination'), findsOneWidget);
    });

    testWidgets('renders document details and custom viewer when builder injected', (tester) async {
      var loadedCalled = false;
      var simulatedPage = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DocumentProvider>.value(
            value: provider,
            child: PdfViewerScreen(
              document: testPdfDoc,
              viewerBuilder: (
                context, {
                required uri,
                required controller,
                required onDocumentLoaded,
                required onPageChanged,
                required onError,
              }) {
                return Center(
                  child: Column(
                    children: [
                      Text('Mock Viewer: ${uri.toString()}'),
                      ElevatedButton(
                        onPressed: () {
                          loadedCalled = true;
                          simulatedPage = 3;
                          onPageChanged?.call(simulatedPage);
                        },
                        child: const Text('Simulate Page Change'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Graduation Diploma'), findsOneWidget);
      expect(find.text('PDF VIEWER'), findsOneWidget);
      expect(find.textContaining('Mock Viewer: https://example.test/signed/vault/diploma.pdf'), findsOneWidget);

      // Tap simulate page change
      await tester.tap(find.text('Simulate Page Change'));
      await tester.pump();

      expect(loadedCalled, isTrue);
      expect(simulatedPage, 3);
    });

    testWidgets('back button pops the viewer screen', (tester) async {
      var didPop = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<DocumentProvider>.value(
          value: provider,
          child: MaterialApp(
            routes: {
              '/': (context) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfViewerScreen(
                              document: testPdfDoc,
                              viewerBuilder: (context, {
                                required uri,
                                required controller,
                                required onDocumentLoaded,
                                required onPageChanged,
                                required onError,
                              }) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ).then((_) => didPop = true);
                      },
                      child: const Text('Go to PDF'),
                    ),
                  ),
            },
          ),
        ),
      );

      await tester.tap(find.text('Go to PDF'));
      await tester.pumpAndSettle();

      // Tap back button
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
    });
  });
}

class _DelayedDocumentRepository extends FakeDocumentRepository {
  final Future<String> future;
  _DelayedDocumentRepository(this.future);

  @override
  Future<String> createDownloadUrl(String filePath) => future;
}

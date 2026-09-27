import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:everkeep/features/documents/models/scanned_page.dart';
import 'package:everkeep/features/documents/presentation/screens/document_scanner_screen.dart';
import 'package:everkeep/features/documents/presentation/widgets/scanner/interactive_crop_view.dart';
import 'package:everkeep/features/documents/presentation/widgets/scanner/page_enhancement_controls.dart';
import 'package:everkeep/features/documents/presentation/widgets/scanner/scanned_page_thumbnail_strip.dart';
import 'package:everkeep/features/documents/presentation/widgets/scanner/scanner_controls_bar.dart';
import 'package:everkeep/features/documents/presentation/widgets/scanner/scanner_guidance_overlay.dart';
import 'package:everkeep/features/documents/services/document_scanner_service.dart';
import 'package:everkeep/features/documents/services/scanner_permission_service.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/providers/document_provider.dart';

import 'document_scanner_service_test.dart';
import 'fakes.dart';

class FakeScannerPermissionService implements ScannerPermissionService {
  ScannerPermissionStatus currentStatus;
  bool requested = false;
  bool openedSettings = false;

  FakeScannerPermissionService({
    this.currentStatus = ScannerPermissionStatus.granted,
  });

  @override
  Future<ScannerPermissionStatus> checkPermission() async => currentStatus;

  @override
  Future<ScannerPermissionStatus> requestPermission() async {
    requested = true;
    return currentStatus;
  }

  @override
  Future<bool> openSettings() async {
    openedSettings = true;
    return true;
  }
}

Widget buildTestableScanner({
  required ScannerPermissionService permissionService,
  DocumentScannerService? scannerService,
  DocumentProvider? documentProvider,
  bool returnUploadDirectly = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DocumentProvider>.value(
        value: documentProvider ?? DocumentProvider(documentRepository: FakeDocumentRepository()),
      ),
    ],
    child: MaterialApp(
      home: DocumentScannerScreen(
        permissionService: permissionService,
        scannerService: scannerService ?? DocumentScannerService(),
        returnUploadDirectly: returnUploadDirectly,
        testCameras: const [],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scanner Permission Handling UI', () {
    testWidgets('displays camera permission denied view and requests access', (tester) async {
      final fakePerm = FakeScannerPermissionService(
        currentStatus: ScannerPermissionStatus.denied,
      );

      await tester.pumpWidget(buildTestableScanner(permissionService: fakePerm));
      await tester.pumpAndSettle();

      expect(find.text('Camera Access Required'), findsOneWidget);
      expect(find.text('Grant Camera Permission'), findsOneWidget);

      await tester.tap(find.text('Grant Camera Permission'));
      await tester.pump();
      expect(fakePerm.requested, isTrue);
    });

    testWidgets('displays permanently denied view with open settings option', (tester) async {
      final fakePerm = FakeScannerPermissionService(
        currentStatus: ScannerPermissionStatus.permanentlyDenied,
      );

      await tester.pumpWidget(buildTestableScanner(permissionService: fakePerm));
      await tester.pumpAndSettle();

      expect(find.text('Camera Access Required'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);

      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      expect(fakePerm.openedSettings, isTrue);
    });
  });

  group('Scanner Guidance & Overlay UI', () {
    testWidgets('renders framing guidance text and corner reticles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScannerGuidanceOverlay(
              guidanceText: 'Position the document inside the frame',
            ),
          ),
        ),
      );

      expect(find.text('Position the document inside the frame'), findsOneWidget);
      expect(find.byType(ScannerGuidanceOverlay), findsOneWidget);
    });

    testWidgets('renders top bar and bottom control bars with icons', (tester) async {
      bool closed = false;
      bool captured = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScannerTopBar(
                  onClose: () => closed = true,
                  onToggleFlash: () {},
                ),
                ScannerBottomBar(
                  onCapture: () => captured = true,
                  onPickFromGallery: () {},
                  pageCount: 2,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(find.text('Review (2)'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded), warnIfMissed: false);
      expect(closed, isTrue);

      await tester.tap(find.byKey(const Key('scanner_shutter_button')));
      expect(captured, isTrue);
    });
  });

  group('Interactive Crop Widget', () {
    testWidgets('renders crop frame, reset button, and confirms crop rect', (tester) async {
      final testImage = createTestImageBytes(width: 80, height: 80);
      Rect? confirmedRect;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: InteractiveCropView(
            imageBytes: testImage,
            onCropConfirmed: (rect) => confirmedRect = rect,
            onCancel: () => cancelled = true,
          ),
        ),
      );

      expect(find.text('Crop Document'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply Crop'), findsOneWidget);

      await tester.tap(find.text('Apply Crop'));
      await tester.pump();

      expect(confirmedRect, isNotNull);
      expect(confirmedRect!.width, greaterThan(0.5));

      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);
    });
  });

  group('Thumbnail Strip & Page Management', () {
    testWidgets('renders multiple pages with page labels and delete actions', (tester) async {
      final imgBytes = createTestImageBytes();
      final pages = [
        ScannedPage(id: 'p1', originalBytes: imgBytes, processedBytes: imgBytes),
        ScannedPage(id: 'p2', originalBytes: imgBytes, processedBytes: imgBytes),
      ];

      int selectedIdx = 0;
      int? deletedIdx;
      bool addPageTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannedPageThumbnailStrip(
              pages: pages,
              selectedIndex: selectedIdx,
              onSelectPage: (idx) => selectedIdx = idx,
              onReorder: (oldIdx, newIdx) {},
              onDeletePage: (idx) => deletedIdx = idx,
              onAddPage: () => addPageTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Add Page'), findsOneWidget);

      await tester.tap(find.text('Add Page'));
      expect(addPageTapped, isTrue);

      // Tap delete on the first page
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      expect(deletedIdx, 0);
    });
  });

  group('Page Enhancement Controls', () {
    testWidgets('allows toggling filters, crop, rotate, and retake', (tester) async {
      PageFilter selectedFilter = PageFilter.documentHighContrast;
      bool cropTapped = false;
      bool rotateTapped = false;
      bool retakeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageEnhancementControls(
              activeFilter: selectedFilter,
              onRetake: () => retakeTapped = true,
              onCrop: () => cropTapped = true,
              onRotate: () => rotateTapped = true,
              onFilterSelected: (f) => selectedFilter = f,
            ),
          ),
        ),
      );

      expect(find.text('Document'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Grayscale'), findsOneWidget);
      expect(find.text('Brighten'), findsOneWidget);

      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Crop'), findsOneWidget);
      expect(find.text('Rotate'), findsOneWidget);

      await tester.tap(find.text('Rotate'));
      expect(rotateTapped, isTrue);

      await tester.tap(find.text('Crop'));
      expect(cropTapped, isTrue);

      await tester.tap(find.text('Retake'));
      expect(retakeTapped, isTrue);

      await tester.tap(find.text('Grayscale'));
      expect(selectedFilter, PageFilter.grayscale);
    });
  });

  group('Document Scanner Complete Flow & Vault Integration', () {
    testWidgets('captures document, enters preview, and continues with upload', (tester) async {
      final fakePerm = FakeScannerPermissionService(
        currentStatus: ScannerPermissionStatus.granted,
      );
      final fakeRepo = FakeDocumentRepository();
      final docProv = DocumentProvider(documentRepository: fakeRepo);

      DocumentUpload? capturedUpload;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DocumentProvider>.value(value: docProv),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        final upload = await Navigator.of(context).push<DocumentUpload>(
                          MaterialPageRoute(
                            builder: (_) => DocumentScannerScreen(
                              permissionService: fakePerm,
                              returnUploadDirectly: true,
                              testCameras: const [],
                            ),
                          ),
                        );
                        capturedUpload = upload;
                      },
                      child: const Text('Launch Scanner'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Launch scanner
      await tester.tap(find.text('Launch Scanner'));
      await tester.pumpAndSettle();

      // Camera fallback view is ready
      expect(find.text('Position the document inside the frame'), findsOneWidget);

      // Tap capture button
      await tester.tap(find.byKey(const Key('scanner_shutter_button')));
      await tester.pumpAndSettle();

      // Preview mode is active
      expect(find.text('Scan Preview'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Rotate'), findsOneWidget);
      expect(find.text('Crop'), findsOneWidget);

      // Tap Rotate
      await tester.tap(find.text('Rotate'));
      await tester.pumpAndSettle();

      // Tap Continue to finalize scan
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Confirm returned DocumentUpload is a valid PDF
      expect(capturedUpload, isNotNull);
      expect(capturedUpload!.fileName.endsWith('.pdf'), isTrue);
      expect(capturedUpload!.mimeType, 'application/pdf');
      expect(capturedUpload!.bytes, isNotEmpty);
      expect(String.fromCharCodes(capturedUpload!.bytes.sublist(0, 5)), '%PDF-');
    });

    testWidgets('multi-page capture combines into a single multi-page PDF', (tester) async {
      final fakePerm = FakeScannerPermissionService(
        currentStatus: ScannerPermissionStatus.granted,
      );
      DocumentUpload? multiPageUpload;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DocumentProvider>.value(
              value: DocumentProvider(documentRepository: FakeDocumentRepository()),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        final upload = await Navigator.of(context).push<DocumentUpload>(
                          MaterialPageRoute(
                            builder: (_) => DocumentScannerScreen(
                              permissionService: fakePerm,
                              returnUploadDirectly: true,
                              testCameras: const [],
                            ),
                          ),
                        );
                        multiPageUpload = upload;
                      },
                      child: const Text('Open Multi Scanner'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Multi Scanner'));
      await tester.pumpAndSettle();

      // 1. Capture Page 1
      await tester.tap(find.byKey(const Key('scanner_shutter_button')));
      await tester.pumpAndSettle();

      expect(find.text('Scan Preview'), findsOneWidget);

      // 2. Tap '+ Add Page' to capture Page 2
      await tester.tap(find.text('+ Add Page'));
      await tester.pumpAndSettle();

      // In camera view again; review count shows 1
      expect(find.text('Review (1)'), findsOneWidget);

      // Capture Page 2
      await tester.tap(find.byKey(const Key('scanner_shutter_button')));
      await tester.pumpAndSettle();

      // Now preview shows 2 pages
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Continue with 2 Pages'), findsOneWidget);

      // 3. Save multi-page scan
      await tester.tap(find.text('Continue with 2 Pages'));
      await tester.pumpAndSettle();

      expect(multiPageUpload, isNotNull);
      expect(multiPageUpload!.mimeType, 'application/pdf');
      expect(multiPageUpload!.fileName.endsWith('.pdf'), isTrue);
      expect(String.fromCharCodes(multiPageUpload!.bytes.sublist(0, 5)), '%PDF-');
    });

    testWidgets('scanned document saved through DocumentProvider stores in repository with upload bytes', (tester) async {
      final fakeRepo = FakeDocumentRepository();
      final docProv = DocumentProvider(documentRepository: fakeRepo);

      final service = DocumentScannerService();
      final page = ScannedPage(
        id: 'p1',
        originalBytes: createTestImageBytes(),
        processedBytes: createTestImageBytes(),
      );

      final upload = await service.createDocumentUpload(
        pages: [page],
        title: 'Driver License',
      );

      final newDoc = const DocumentItem(
        id: '',
        title: 'Driver License',
        subtitle: '',
        category: 'Legal',
        documentType: 'drivers_license',
      );

      final added = await docProv.addDocument(newDoc, upload: upload);
      expect(added, isTrue);
      expect(docProv.documents.length, 1);
      expect(docProv.documents.first.title, 'Driver License');
      expect(fakeRepo.lastUpload, isNotNull);
      expect(fakeRepo.lastUpload!.fileName, 'Driver License.pdf');
      expect(fakeRepo.lastUpload!.mimeType, 'application/pdf');
    });

    testWidgets('close button in scanner top bar pops scanner without returning an upload', (tester) async {
      final fakePerm = FakeScannerPermissionService(currentStatus: ScannerPermissionStatus.granted);
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DocumentScannerScreen(
                          permissionService: fakePerm,
                          testCameras: const [],
                        ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('Open Scanner'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.text('Open Scanner'), findsOneWidget);
    });

    testWidgets('single page scan can be uploaded as JPEG if preferred', (tester) async {
      final service = DocumentScannerService();
      final page = ScannedPage(
        id: 'p_single',
        originalBytes: createTestImageBytes(width: 50, height: 50),
        processedBytes: createTestImageBytes(width: 50, height: 50),
      );

      final upload = await service.createDocumentUpload(
        pages: [page],
        title: 'Receipt Scan',
        preferPdfForSinglePage: false,
      );

      expect(upload.fileName, 'Receipt Scan.jpg');
      expect(upload.mimeType, 'image/jpeg');
      expect(upload.bytes, isNotEmpty);
    });
  });
}

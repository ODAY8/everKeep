import 'package:everkeep/features/wishes/presentation/widgets/full_screen_photo_viewer.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_details_sheet.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/memory_media_item.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

void main() {
  late FakeMemoryRepository repo;
  late MemoryProvider provider;

  setUp(() {
    repo = FakeMemoryRepository();
    provider = MemoryProvider(memoryRepository: repo);
  });

  Widget buildTestWidget(MemoryItem item) {
    return MaterialApp(
      home: ChangeNotifierProvider<MemoryProvider>.value(
        value: provider,
        child: Scaffold(
          body: SingleChildScrollView(
            child: MemoryDetailsSheet(item: item),
          ),
        ),
      ),
    );
  }

  group('MemoryDetailsSheet — Rich Media Gallery', () {
    testWidgets('empty media renders title and content without media section', (tester) async {
      final plain = MemoryItem(
        id: 'plain-1',
        title: 'Reflections',
        content: 'Just text here.',
      );

      await tester.pumpWidget(buildTestWidget(plain));
      await tester.pumpAndSettle();

      expect(find.text('Reflections'), findsOneWidget);
      expect(find.text('Just text here.'), findsOneWidget);
      expect(find.text('MEDIA ARCHIVE'), findsNothing);
    });

    testWidgets('memory with one photo displays primary cover photo without strip or clutter', (tester) async {
      const singlePhoto = MemoryMediaItem(
        id: 'p1',
        memoryId: 'mem-1',
        filePath: 'user/memories/m1/single.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 1024,
        caption: 'First Day at University',
      );

      final memory = MemoryItem(
        id: 'mem-1',
        title: 'University',
        content: 'Great start.',
        media: const [singlePhoto],
      );

      await tester.pumpWidget(buildTestWidget(memory));
      await tester.pumpAndSettle();

      expect(find.text('MEDIA ARCHIVE'), findsOneWidget);
      // Single photo: no "1 media" clutter badge
      expect(find.text('1 media'), findsNothing);
      // Caption displayed
      expect(find.text('First Day at University'), findsOneWidget);
      // Expand icon present
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    });

    testWidgets('memory with multiple photos displays primary photo, counter, and thumbnail strip', (tester) async {
      const p1 = MemoryMediaItem(
        id: 'p1',
        memoryId: 'mem-2',
        filePath: 'user/memories/m2/photo1.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 1024,
        displayOrder: 0,
        caption: 'Cover Photo',
      );
      const p2 = MemoryMediaItem(
        id: 'p2',
        memoryId: 'mem-2',
        filePath: 'user/memories/m2/photo2.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 2048,
        displayOrder: 1,
        caption: 'Second Photo',
      );

      final memory = MemoryItem(
        id: 'mem-2',
        title: 'Kyoto Tour',
        content: 'Photos from Kyoto.',
        media: const [p1, p2],
      );

      await tester.pumpWidget(buildTestWidget(memory));
      await tester.pumpAndSettle();

      expect(find.text('MEDIA ARCHIVE'), findsOneWidget);
      expect(find.text('2 media'), findsOneWidget);
      expect(find.text('Cover Photo'), findsOneWidget);
      // Thumbnail list view
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('photo ordering respects display_order', (tester) async {
      const pSecond = MemoryMediaItem(
        id: 'p2',
        memoryId: 'mem-order',
        filePath: 'user/memories/order/p2.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 1000,
        displayOrder: 1,
        caption: 'Second In Order',
      );
      const pFirst = MemoryMediaItem(
        id: 'p1',
        memoryId: 'mem-order',
        filePath: 'user/memories/order/p1.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 1000,
        displayOrder: 0,
        caption: 'First In Order',
      );

      // Supplied out of order
      final memory = MemoryItem(
        id: 'mem-order',
        title: 'Ordered',
        content: 'Testing order.',
        media: const [pSecond, pFirst],
      );

      await tester.pumpWidget(buildTestWidget(memory));
      await tester.pumpAndSettle();

      // Primary photo should be pFirst because of displayOrder sorting in MemoryItem
      expect(memory.primaryCoverPhoto?.id, 'p1');
    });

    testWidgets('mixed photo, video, and audio renders respective cards and badges', (tester) async {
      const photo = MemoryMediaItem(
        id: 'p1',
        memoryId: 'mem-mix',
        filePath: 'u/m/p.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 1000,
        displayOrder: 0,
      );
      const video = MemoryMediaItem(
        id: 'v1',
        memoryId: 'mem-mix',
        filePath: 'u/m/v.mp4',
        mediaType: MemoryMediaType.video,
        mimeType: 'video/mp4',
        fileSize: 10485760, // 10.0 MB
        displayOrder: 1,
        caption: 'Campus Tour Clip',
        durationSeconds: 95,
      );
      const audio = MemoryMediaItem(
        id: 'a1',
        memoryId: 'mem-mix',
        filePath: 'u/m/a.m4a',
        mediaType: MemoryMediaType.audio,
        mimeType: 'audio/m4a',
        fileSize: 2097152, // 2.0 MB
        displayOrder: 2,
        caption: 'Orientation Speech',
        durationSeconds: 180,
      );

      final memory = MemoryItem(
        id: 'mem-mix',
        title: 'First Day at KIIT',
        content: 'Orientation events.',
        media: const [photo, video, audio],
      );

      await tester.pumpWidget(buildTestWidget(memory));
      await tester.pumpAndSettle();

      expect(find.text('3 media'), findsOneWidget);
      // Video card and badge
      expect(find.text('Campus Tour Clip'), findsOneWidget);
      expect(find.text('VIDEO'), findsOneWidget);
      expect(find.text('1:35 · 10.0 MB'), findsOneWidget);

      // Audio card and badge
      expect(find.text('Orientation Speech'), findsOneWidget);
      expect(find.text('AUDIO'), findsOneWidget);
      expect(find.text('3:00 · 2.0 MB'), findsOneWidget);
    });

    testWidgets('legacy attachment fallback renders as photo when mimeType is image', (tester) async {
      final legacy = MemoryItem(
        id: 'leg-1',
        title: 'Legacy Photo',
        content: 'Old memory.',
        filePath: 'user/memories/legacy_photo.jpg',
        fileSize: 2048,
        mimeType: 'image/jpeg',
      );

      await tester.pumpWidget(buildTestWidget(legacy));
      await tester.pumpAndSettle();

      expect(find.text('MEDIA ARCHIVE'), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    });

    testWidgets('legacy non-photo attachment renders fallback document card with Open button', (tester) async {
      bool openCalled = false;
      final legacyDoc = MemoryItem(
        id: 'leg-doc-1',
        title: 'Legacy Document',
        content: 'PDF attachment.',
        filePath: 'user/memories/document.pdf',
        fileSize: 5000,
        mimeType: 'application/pdf',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MemoryProvider>.value(
            value: provider,
            child: Scaffold(
              body: MemoryDetailsSheet(
                item: legacyDoc,
                onOpenAttachment: () => openCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attached File'), findsOneWidget);
      expect(find.text('document.pdf'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);

      await tester.tap(find.text('Open'));
      expect(openCalled, isTrue);
    });

    testWidgets('failed signed URL displays clean fallback container', (tester) async {
      repo.failWith = 'Storage permission error';
      const failingPhoto = MemoryMediaItem(
        id: 'p-fail',
        memoryId: 'mem-f',
        filePath: 'broken/path.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 100,
      );

      final memory = MemoryItem(
        id: 'mem-f',
        title: 'Broken Photo',
        content: 'Will fail signed URL',
        media: const [failingPhoto],
      );

      await tester.pumpWidget(buildTestWidget(memory));
      await tester.pumpAndSettle();

      expect(find.text('Photo unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('tapping primary photo opens FullScreenPhotoViewer', (tester) async {
      const photo = MemoryMediaItem(
        id: 'p1',
        memoryId: 'mem-tap',
        filePath: 'user/memories/tap.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 1000,
        caption: 'Tap to view test',
      );

      final memory = MemoryItem(
        id: 'mem-tap',
        title: 'Tap Photo',
        content: 'Tapping opens viewer',
        media: const [photo],
      );

      await tester.pumpWidget(buildTestWidget(memory));
      await tester.pumpAndSettle();

      // Tap primary photo container
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // FullScreenPhotoViewer is pushed
      expect(find.byType(FullScreenPhotoViewer), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FullScreenPhotoViewer),
          matching: find.text('Tap to view test'),
        ),
        findsOneWidget,
      );

      // Close button closes viewer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenPhotoViewer), findsNothing);
    });

    testWidgets('FullScreenPhotoViewer swiping between photos updates index counter', (tester) async {
      const photos = [
        MemoryMediaItem(
          id: 'p1',
          memoryId: 'm',
          filePath: 'f1.jpg',
          mediaType: MemoryMediaType.photo,
          mimeType: 'image/jpeg',
          fileSize: 100,
          caption: 'First photo',
        ),
        MemoryMediaItem(
          id: 'p2',
          memoryId: 'm',
          filePath: 'f2.jpg',
          mediaType: MemoryMediaType.photo,
          mimeType: 'image/jpeg',
          fileSize: 100,
          caption: 'Second photo',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenPhotoViewer(
            photos: photos,
            initialIndex: 0,
            signedUrls: const {'f1.jpg': 'url1', 'f2.jpg': 'url2'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('First photo'), findsOneWidget);

      // Swipe to page 2
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Second photo'), findsOneWidget);
    });
  });
}

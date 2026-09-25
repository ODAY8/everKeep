import 'dart:typed_data';

import 'package:everkeep/core/utils/pick_upload.dart';
import 'package:everkeep/features/wishes/presentation/services/memory_media_picker.dart';
import 'package:everkeep/features/wishes/presentation/widgets/audio_recorder_adapter.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_form_sheet.dart';
import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/memory_media_item.dart';
import 'package:everkeep/providers/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

class FakeTestMediaPicker implements MemoryMediaPicker {
  List<DocumentUpload> Function()? onPickPhotos;
  DocumentUpload? Function()? onPickVideo;
  DocumentUpload? Function()? onPickAudio;

  @override
  Future<List<DocumentUpload>> pickPhotos() async {
    return onPickPhotos != null ? onPickPhotos!() : const [];
  }

  @override
  Future<DocumentUpload?> pickVideo() async {
    return onPickVideo != null ? onPickVideo!() : null;
  }

  @override
  Future<DocumentUpload?> pickAudio() async {
    return onPickAudio != null ? onPickAudio!() : null;
  }
}

class FakeTestAudioRecorder implements AudioRecorderAdapter {
  bool permissionGranted = true;
  bool isRecordingState = false;
  DocumentUpload? Function(int? duration)? onStopCallback;
  bool cancelled = false;
  bool disposed = false;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start() async {
    isRecordingState = true;
  }

  @override
  Future<DocumentUpload?> stop({int? durationSeconds}) async {
    isRecordingState = false;
    if (onStopCallback != null) {
      return onStopCallback!(durationSeconds);
    }
    return DocumentUpload(
      fileName: 'recorded_voice.m4a',
      bytes: Uint8List.fromList([10, 20, 30]),
      mimeType: 'audio/mp4',
    );
  }

  @override
  Future<void> cancel() async {
    isRecordingState = false;
    cancelled = true;
  }

  @override
  Future<bool> isRecording() async => isRecordingState;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  late FakeMemoryRepository repo;
  late MemoryProvider provider;
  late FakeTestMediaPicker picker;
  late FakeTestAudioRecorder recorder;

  setUp(() {
    repo = FakeMemoryRepository([]);
    provider = MemoryProvider(memoryRepository: repo);
    picker = FakeTestMediaPicker();
    recorder = FakeTestAudioRecorder();
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    MemoryItem? item,
    String type = 'memory',
    DocumentUpload? initialUpload,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<MemoryProvider>.value(
          value: provider,
          child: Scaffold(
            body: MemoryFormSheet(
              initialItem: item,
              initialType: type,
              initialUpload: initialUpload,
              mediaPicker: picker,
              recorderFactory: () => recorder,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Step 5C — Media Selection & Preview', () {
    testWidgets('selecting one photo displays photo item and primary cover photo badge',
        (tester) async {
      picker.onPickPhotos = () => [
            DocumentUpload(
              fileName: 'vacation.jpg',
              bytes: Uint8List.fromList([1, 2, 3, 4]),
              mimeType: 'image/jpeg',
            ),
          ];

      await pumpForm(tester);

      expect(find.text('Add Photos'), findsOneWidget);
      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();

      expect(find.text('vacation.jpg'), findsOneWidget);
      expect(find.text('PHOTO'), findsOneWidget);
      expect(find.text('Primary Cover Photo'), findsOneWidget);
    });

    testWidgets('selecting multiple photos displays all items in preview tray',
        (tester) async {
      picker.onPickPhotos = () => [
            DocumentUpload(
              fileName: 'photo1.jpg',
              bytes: Uint8List.fromList([1, 2]),
              mimeType: 'image/jpeg',
            ),
            DocumentUpload(
              fileName: 'photo2.png',
              bytes: Uint8List.fromList([3, 4, 5]),
              mimeType: 'image/png',
            ),
          ];

      await pumpForm(tester);

      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();

      expect(find.text('photo1.jpg'), findsOneWidget);
      expect(find.text('photo2.png'), findsOneWidget);
      expect(find.text('Primary Cover Photo'), findsOneWidget);
    });

    testWidgets('selecting video and audio adds respective media cards',
        (tester) async {
      picker.onPickVideo = () => DocumentUpload(
            fileName: 'clip.mp4',
            bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
            mimeType: 'video/mp4',
          );
      picker.onPickAudio = () => DocumentUpload(
            fileName: 'song.mp3',
            bytes: Uint8List.fromList([6, 7, 8]),
            mimeType: 'audio/mpeg',
          );

      await pumpForm(tester);

      await tester.tap(find.text('Add Video'));
      await tester.pumpAndSettle();
      expect(find.text('clip.mp4'), findsOneWidget);
      expect(find.text('VIDEO'), findsOneWidget);

      await tester.tap(find.text('Add Audio'));
      await tester.pumpAndSettle();
      expect(find.text('song.mp3'), findsOneWidget);
      expect(find.text('AUDIO'), findsOneWidget);
    });

    testWidgets('duplicate media selection is skipped cleanly',
        (tester) async {
      picker.onPickPhotos = () => [
            DocumentUpload(
              fileName: 'same.jpg',
              bytes: Uint8List.fromList([1, 2, 3]),
              mimeType: 'image/jpeg',
            ),
          ];

      await pumpForm(tester);

      // Pick once
      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();
      expect(find.text('same.jpg'), findsOneWidget);

      // Pick identical item again
      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();

      expect(find.text('same.jpg'), findsOneWidget);
      expect(find.text('Duplicate media items were skipped.'), findsOneWidget);
    });

    testWidgets('removing item removes it from the preview list',
        (tester) async {
      picker.onPickPhotos = () => [
            DocumentUpload(
              fileName: 'remove_me.jpg',
              bytes: Uint8List.fromList([1, 2, 3]),
              mimeType: 'image/jpeg',
            ),
          ];

      await pumpForm(tester);

      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();
      expect(find.text('remove_me.jpg'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove media'));
      await tester.pumpAndSettle();

      expect(find.text('remove_me.jpg'), findsNothing);
    });
  });

  group('Step 5C — Reordering & Captions', () {
    testWidgets('reordering items updates order and primary cover photo indicator',
        (tester) async {
      picker.onPickPhotos = () => [
            DocumentUpload(
              fileName: 'first.jpg',
              bytes: Uint8List.fromList([1]),
              mimeType: 'image/jpeg',
            ),
            DocumentUpload(
              fileName: 'second.jpg',
              bytes: Uint8List.fromList([2]),
              mimeType: 'image/jpeg',
            ),
          ];

      await pumpForm(tester);

      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Move down'), findsNWidgets(2));

      // Move the first item down
      await tester.tap(find.byTooltip('Move down').first);
      await tester.pumpAndSettle();

      // Now second.jpg is first and becomes the primary cover photo
      expect(find.text('Primary Cover Photo'), findsOneWidget);
    });

    testWidgets('adding optional caption to media item', (tester) async {
      picker.onPickPhotos = () => [
            DocumentUpload(
              fileName: 'sunset.jpg',
              bytes: Uint8List.fromList([1, 2]),
              mimeType: 'image/jpeg',
            ),
          ];

      await pumpForm(tester);

      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();

      final captionFinder =
          find.widgetWithText(TextField, 'Add a caption (optional)...');
      expect(captionFinder, findsOneWidget);

      await tester.enterText(captionFinder, 'Golden hour in Santorini');
      await tester.pumpAndSettle();

      expect(find.text('Golden hour in Santorini'), findsOneWidget);
    });
  });

  group('Step 5C — Audio Recording', () {
    testWidgets('recording audio starts, stops, and adds audio card with duration',
        (tester) async {
      recorder.onStopCallback = (dur) => DocumentUpload(
            fileName: 'recorded_memo.m4a',
            bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
            mimeType: 'audio/mp4',
          );

      await pumpForm(tester);

      await tester.tap(find.text('Record Audio'));
      await tester.pumpAndSettle();

      expect(find.text('Recording Audio...'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      expect(find.text('recorded_memo.m4a'), findsOneWidget);
      expect(find.text('AUDIO'), findsOneWidget);
    });

    testWidgets('permission denial shows friendly notification without crashing',
        (tester) async {
      recorder.permissionGranted = false;

      await pumpForm(tester);

      await tester.tap(find.text('Record Audio'));
      await tester.pumpAndSettle();

      expect(
        find.text('Microphone permission is required to record audio.'),
        findsOneWidget,
      );
      expect(find.text('Recording Audio...'), findsNothing);
    });

    testWidgets('cancelling audio recording discards recording',
        (tester) async {
      await pumpForm(tester);

      await tester.tap(find.text('Record Audio'));
      await tester.pumpAndSettle();
      expect(find.text('Recording Audio...'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel recording'));
      await tester.pumpAndSettle();

      expect(find.text('Recording Audio...'), findsNothing);
      expect(recorder.cancelled, isTrue);
    });
  });

  group('Step 5C — Create & Edit Memory with Media', () {
    testWidgets('create memory with multiple media calls Provider.createMemoryWithMedia',
        (tester) async {
      picker.onPickPhotos = () => [
            DocumentUpload(
              fileName: 'photo1.jpg',
              bytes: Uint8List.fromList([1, 2]),
              mimeType: 'image/jpeg',
            ),
          ];
      picker.onPickVideo = () => DocumentUpload(
            fileName: 'clip.mp4',
            bytes: Uint8List.fromList([3, 4, 5]),
            mimeType: 'video/mp4',
          );

      await pumpForm(tester);

      // Enter Title
      await tester.enterText(
        find.byType(TextFormField).first,
        'Trip to Kyoto',
      );
      await tester.pumpAndSettle();

      // Pick photo and video
      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Video'));
      await tester.pumpAndSettle();

      // Add caption to the photo
      final captionFields =
          find.widgetWithText(TextField, 'Add a caption (optional)...');
      await tester.enterText(captionFields.first, 'Shrine visit');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Upload & Save'));
      await tester.pumpAndSettle();

      // Saved in repo
      expect(repo.items.length, 1);
      final created = repo.items.first;
      expect(created.title, 'Trip to Kyoto');
      expect(created.media.length, 2);
      expect(created.media.first.caption, 'Shrine visit');
    });

    testWidgets('editing memory displays existing media and preserves legacy attachment',
        (tester) async {
      const existingMedia = MemoryMediaItem(
        id: 'med-existing-1',
        memoryId: 'mem-100',
        filePath: 'user/memories/m100/existing.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 2048,
        caption: 'Existing photo caption',
      );

      final legacyMemory = MemoryItem(
        id: 'mem-100',
        title: 'Legacy Family Memory',
        content: 'Preserving old memories',
        filePath: 'user/memories/legacy_doc.pdf',
        fileSize: 4096,
        mimeType: 'application/pdf',
        media: const [existingMedia],
      );
      repo.items.add(legacyMemory);

      await pumpForm(tester, item: legacyMemory);

      // Existing attachment preserved card
      expect(find.text('Existing attachment preserved'), findsOneWidget);
      // Existing rich media
      expect(find.text('existing.jpg'), findsOneWidget);
      expect(find.text('Existing photo caption'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('editing memory allows adding new media while existing media is deleted',
        (tester) async {
      const existingMedia = MemoryMediaItem(
        id: 'med-to-delete',
        memoryId: 'mem-200',
        filePath: 'user/memories/m200/old.jpg',
        mediaType: MemoryMediaType.photo,
        mimeType: 'image/jpeg',
        fileSize: 1024,
      );

      final memory = MemoryItem(
        id: 'mem-200',
        title: 'Graduation',
        content: 'College days',
        media: const [existingMedia],
      );
      repo.items.add(memory);

      picker.onPickAudio = () => DocumentUpload(
            fileName: 'speech.mp3',
            bytes: Uint8List.fromList([7, 8, 9]),
            mimeType: 'audio/mpeg',
          );

      await pumpForm(tester, item: memory);

      expect(find.text('old.jpg'), findsOneWidget);

      // Remove existing photo
      await tester.tap(find.byTooltip('Remove media'));
      await tester.pumpAndSettle();
      expect(find.text('old.jpg'), findsNothing);

      // Add new audio
      await tester.tap(find.text('Add Audio'));
      await tester.pumpAndSettle();
      expect(find.text('speech.mp3'), findsOneWidget);

      // Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verified: deleteMedia and addMedia were called
      expect(
          repo.items.first.media.any((m) => m.id == 'med-to-delete'), isFalse);
      expect(
          repo.items.first.media
              .any((m) => m.filePath.contains('speech.mp3')),
          isTrue);
    });
  });

  group('Step 5C — Error & Rollback Handling', () {
    testWidgets('oversized file throws PickedTooLarge and displays error snackbar',
        (tester) async {
      picker.onPickPhotos = () => throw const PickedTooLarge(maxDocumentBytes);

      await pumpForm(tester);

      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();

      expect(
        find.text('That file is too large. The limit is 25 MB.'),
        findsOneWidget,
      );
    });

    testWidgets('failed save keeps user input intact for retry',
        (tester) async {
      repo.failWith = 'Database error occurred';

      picker.onPickPhotos = () => [
            DocumentUpload(
              fileName: 'photo_retry.jpg',
              bytes: Uint8List.fromList([1, 2]),
              mimeType: 'image/jpeg',
            ),
          ];

      await pumpForm(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Retry memory title',
      );
      await tester.tap(find.text('Add Photos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload & Save'));
      await tester.pumpAndSettle();

      // Error banner is visible
      expect(find.textContaining('Database error occurred'), findsOneWidget);
      // Title and picked media are preserved
      expect(find.text('Retry memory title'), findsOneWidget);
      expect(find.text('photo_retry.jpg'), findsOneWidget);
    });
  });
}

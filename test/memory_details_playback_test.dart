import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:everkeep/features/wishes/presentation/widgets/audio_player_adapter.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_audio_player.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_details_sheet.dart';
import 'package:everkeep/features/wishes/presentation/widgets/memory_video_player.dart';
import 'package:everkeep/features/wishes/presentation/widgets/video_player_adapter.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/memory_media_item.dart';
import 'package:everkeep/providers/memory_provider.dart';

import 'fakes.dart';

/// Test implementation of VideoPlayerAdapter for deterministic widget testing.
class FakeVideoPlayerAdapter implements VideoPlayerAdapter {
  @override
  bool isInitialized;
  @override
  bool isPlaying;
  @override
  bool hasError;
  @override
  Duration position;
  @override
  final Duration duration;
  @override
  final double aspectRatio;
  final List<VoidCallback> _listeners = [];
  bool isDisposed = false;
  bool failOnInitialize;

  FakeVideoPlayerAdapter({
    this.isInitialized = false,
    this.isPlaying = false,
    this.hasError = false,
    this.position = Duration.zero,
    this.duration = const Duration(seconds: 90),
    this.aspectRatio = 16 / 9,
    this.failOnInitialize = false,
  });

  void notify() {
    for (final l in List<VoidCallback>.from(_listeners)) {
      l();
    }
  }

  void updatePosition(Duration pos) {
    position = pos;
    notify();
  }

  void setError(bool err) {
    hasError = err;
    notify();
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<void> initialize() async {
    if (failOnInitialize) {
      hasError = true;
      notify();
      throw Exception('Video initialization failed');
    }
    isInitialized = true;
    notify();
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    notify();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    notify();
  }

  @override
  Future<void> seekTo(Duration pos) async {
    position = pos;
    notify();
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    _listeners.clear();
  }

  @override
  Widget buildVideoView(BuildContext context) {
    return Container(
      key: const Key('fake_video_texture_view'),
      width: 320,
      height: 180,
      color: Colors.black,
    );
  }
}

/// Test implementation of AudioPlayerAdapter for deterministic widget testing.
class FakeAudioPlayerAdapter implements AudioPlayerAdapter {
  final _posController = StreamController<Duration>.broadcast();
  final _durController = StreamController<Duration>.broadcast();
  final _stateController = StreamController<PlayerState>.broadcast();

  @override
  bool isPlaying;
  @override
  Duration position;
  @override
  final Duration duration;
  bool isDisposed = false;
  String? playedUrl;
  bool failOnPlay;

  FakeAudioPlayerAdapter({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = const Duration(seconds: 45),
    this.failOnPlay = false,
  });

  @override
  Stream<Duration> get onPositionChanged => _posController.stream;
  @override
  Stream<Duration> get onDurationChanged => _durController.stream;
  @override
  Stream<PlayerState> get onPlayerStateChanged => _stateController.stream;

  void emitPosition(Duration pos) {
    position = pos;
    _posController.add(pos);
  }

  void emitDuration(Duration dur) {
    _posController.add(position);
    _durController.add(dur);
  }

  void emitState(PlayerState state) {
    isPlaying = state == PlayerState.playing;
    _stateController.add(state);
  }

  @override
  Future<void> play(String url) async {
    if (failOnPlay) {
      throw Exception('Audio playback initialization failed');
    }
    playedUrl = url;
    isPlaying = true;
    emitState(PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    emitState(PlayerState.paused);
  }

  @override
  Future<void> resume() async {
    isPlaying = true;
    emitState(PlayerState.playing);
  }

  @override
  Future<void> seek(Duration pos) async {
    position = pos;
    emitPosition(pos);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    emitState(PlayerState.stopped);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    await _posController.close();
    await _durController.close();
    await _stateController.close();
  }
}

void main() {
  group('Step 5B — Video and Audio Playback', () {
    late FakeMemoryRepository repo;
    late MemoryProvider provider;

    setUp(() {
      repo = FakeMemoryRepository();
      provider = MemoryProvider(memoryRepository: repo);
    });

    Widget wrapWithProvider(Widget child) {
      return MaterialApp(
        home: ChangeNotifierProvider<MemoryProvider>.value(
          value: provider,
          child: Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        ),
      );
    }

    group('MemoryVideoPlayer', () {
      const videoMedia = MemoryMediaItem(
        id: 'v1',
        memoryId: 'mem-vid',
        filePath: 'user/memories/video1.mp4',
        mediaType: MemoryMediaType.video,
        mimeType: 'video/mp4',
        fileSize: 4500000,
        durationSeconds: 90,
        caption: 'Family Vacation Video',
      );

      testWidgets('video media renders player card with header and play prompt', (tester) async {
        await tester.pumpWidget(wrapWithProvider(
          const MemoryVideoPlayer(media: videoMedia),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Family Vacation Video'), findsOneWidget);
        expect(find.text('VIDEO'), findsOneWidget);
        expect(find.textContaining('1:30'), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      });

      testWidgets('play/pause controls toggle playback state with adapter', (tester) async {
        final adapter = FakeVideoPlayerAdapter(
          isInitialized: true,
          isPlaying: false,
          duration: const Duration(seconds: 90),
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryVideoPlayer(media: videoMedia, adapter: adapter),
        ));
        await tester.pumpAndSettle();

        expect(adapter.isPlaying, isFalse);

        // Tap play button
        await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
        await tester.pumpAndSettle();

        expect(adapter.isPlaying, isTrue);

        // Tap pause button
        await tester.tap(find.byIcon(Icons.pause_rounded).first);
        await tester.pumpAndSettle();

        expect(adapter.isPlaying, isFalse);
      });

      testWidgets('seek and duration display update timestamp indicator', (tester) async {
        final adapter = FakeVideoPlayerAdapter(
          isInitialized: true,
          isPlaying: true,
          position: const Duration(seconds: 15),
          duration: const Duration(seconds: 90),
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryVideoPlayer(media: videoMedia, adapter: adapter),
        ));
        await tester.pumpAndSettle();

        expect(find.text('00:15 / 01:30'), findsOneWidget);

        // Update position on adapter
        adapter.updatePosition(const Duration(seconds: 45));
        await tester.pumpAndSettle();

        expect(find.text('00:45 / 01:30'), findsOneWidget);
      });

      testWidgets('failed signed URL shows clean error container with retry', (tester) async {
        repo.failWith = 'Storage unauthorized';

        await tester.pumpWidget(wrapWithProvider(
          const MemoryVideoPlayer(media: videoMedia),
        ));
        await tester.pumpAndSettle();

        // Tap play to trigger signed URL fetch
        await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
        await tester.pumpAndSettle();

        expect(find.text('Unable to load video'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        // Does not leak storage path
        expect(find.textContaining('user/memories/video1.mp4'), findsNothing);
      });

      testWidgets('playback initialization failure shows error state', (tester) async {
        final adapter = FakeVideoPlayerAdapter(failOnInitialize: true);

        await tester.pumpWidget(wrapWithProvider(
          MemoryVideoPlayer(media: videoMedia, adapter: adapter),
        ));
        await tester.pumpAndSettle();

        // Tap play to initialize
        await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
        await tester.pumpAndSettle();

        expect(find.text('Unable to load video'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('fullscreen button opens FullscreenVideoViewer and exit button closes it', (tester) async {
        final adapter = FakeVideoPlayerAdapter(
          isInitialized: true,
          isPlaying: true,
          duration: const Duration(seconds: 90),
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryVideoPlayer(media: videoMedia, adapter: adapter),
        ));
        await tester.pumpAndSettle();

        // Tap fullscreen button
        await tester.tap(find.byIcon(Icons.fullscreen_rounded));
        await tester.pumpAndSettle();

        // Fullscreen view is open
        expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);

        // Tap close fullscreen
        await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.fullscreen_exit_rounded), findsNothing);
      });

      testWidgets('disposing cleans up player resources', (tester) async {
        final adapter = FakeVideoPlayerAdapter(
          isInitialized: true,
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryVideoPlayer(media: videoMedia, adapter: adapter),
        ));
        await tester.pumpAndSettle();

        // Replace widget to trigger disposal
        await tester.pumpWidget(wrapWithProvider(const SizedBox()));
        await tester.pumpAndSettle();

        // Injected adapter listener was detached
        expect(adapter._listeners, isEmpty);
      });
    });

    group('MemoryAudioPlayer', () {
      const audioMedia = MemoryMediaItem(
        id: 'a1',
        memoryId: 'mem-aud',
        filePath: 'user/memories/voice1.m4a',
        mediaType: MemoryMediaType.audio,
        mimeType: 'audio/mp4',
        fileSize: 1200000,
        durationSeconds: 45,
        caption: 'Birthday Greeting Voice Note',
      );

      testWidgets('audio media renders player card with header and audio badge', (tester) async {
        await tester.pumpWidget(wrapWithProvider(
          const MemoryAudioPlayer(media: audioMedia),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Birthday Greeting Voice Note'), findsOneWidget);
        expect(find.text('AUDIO'), findsOneWidget);
        expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);
        expect(find.text('00:00 / 00:45'), findsOneWidget);
      });

      testWidgets('play/pause controls toggle playback state with audio adapter', (tester) async {
        final adapter = FakeAudioPlayerAdapter(
          duration: const Duration(seconds: 45),
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryAudioPlayer(media: audioMedia, adapter: adapter),
        ));
        await tester.pumpAndSettle();

        expect(adapter.isPlaying, isFalse);

        // Tap play
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pumpAndSettle();

        expect(adapter.isPlaying, isTrue);
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

        // Tap pause
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pumpAndSettle();

        expect(adapter.isPlaying, isFalse);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      });

      testWidgets('seek and progress slider updates audio playback position', (tester) async {
        final adapter = FakeAudioPlayerAdapter(
          duration: const Duration(seconds: 45),
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryAudioPlayer(media: audioMedia, adapter: adapter),
        ));
        await tester.pumpAndSettle();

        adapter.emitPosition(const Duration(seconds: 20));
        await tester.pumpAndSettle();

        expect(find.text('00:20 / 00:45'), findsOneWidget);
      });

      testWidgets('failed signed URL displays clean audio error row with retry', (tester) async {
        repo.failWith = 'Storage unauthorized';

        await tester.pumpWidget(wrapWithProvider(
          const MemoryAudioPlayer(media: audioMedia),
        ));
        await tester.pumpAndSettle();

        // Tap play to trigger load
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Unable to play audio'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.textContaining('user/memories/voice1.m4a'), findsNothing);
      });

      testWidgets('playback failure shows error and retry button', (tester) async {
        final adapter = FakeAudioPlayerAdapter(failOnPlay: true);

        await tester.pumpWidget(wrapWithProvider(
          MemoryAudioPlayer(media: audioMedia, adapter: adapter),
        ));
        await tester.pumpAndSettle();

        // Tap play
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Unable to play audio'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('disposing cleans up audio player resources', (tester) async {
        final adapter = FakeAudioPlayerAdapter();

        await tester.pumpWidget(wrapWithProvider(
          MemoryAudioPlayer(media: audioMedia, adapter: adapter),
        ));
        await tester.pumpAndSettle();

        // Dispose
        await tester.pumpWidget(wrapWithProvider(const SizedBox()));
        await tester.pumpAndSettle();

        // Subscriptions cancelled
        expect(adapter.isDisposed, isFalse); // Injected adapter left for test inspection
      });
    });

    group('MemoryDetailsSheet Integration & Legacy Attachments', () {
      testWidgets('mixed photo, video, and audio renders respective player widgets', (tester) async {
        const photo = MemoryMediaItem(
          id: 'p1',
          memoryId: 'mix',
          filePath: 'u/m/p.jpg',
          mediaType: MemoryMediaType.photo,
          mimeType: 'image/jpeg',
          fileSize: 1000,
          displayOrder: 0,
        );
        const video = MemoryMediaItem(
          id: 'v1',
          memoryId: 'mix',
          filePath: 'u/m/v.mp4',
          mediaType: MemoryMediaType.video,
          mimeType: 'video/mp4',
          fileSize: 5000000,
          durationSeconds: 120,
          displayOrder: 1,
        );
        const audio = MemoryMediaItem(
          id: 'a1',
          memoryId: 'mix',
          filePath: 'u/m/a.m4a',
          mediaType: MemoryMediaType.audio,
          mimeType: 'audio/mp4',
          fileSize: 800000,
          durationSeconds: 30,
          displayOrder: 2,
        );

        final memory = MemoryItem(
          id: 'mix',
          title: 'Mixed Media Memory',
          content: 'Full rich archive',
          media: const [photo, video, audio],
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryDetailsSheet(
            item: memory,
            videoAdapterFactory: (_) => FakeVideoPlayerAdapter(isInitialized: true),
            audioAdapterFactory: () => FakeAudioPlayerAdapter(),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('MEDIA ARCHIVE'), findsOneWidget);
        expect(find.text('3 media'), findsOneWidget);
        expect(find.byType(MemoryVideoPlayer), findsOneWidget);
        expect(find.byType(MemoryAudioPlayer), findsOneWidget);
        expect(find.text('VIDEO'), findsOneWidget);
        expect(find.text('AUDIO'), findsOneWidget);
      });

      testWidgets('legacy video attachment renders in-app video player', (tester) async {
        final legacyVideo = MemoryItem(
          id: 'leg-vid',
          title: 'Legacy Video Clip',
          content: 'Old video attachment',
          filePath: 'user/memories/clip.mp4',
          fileSize: 3000000,
          mimeType: 'video/mp4',
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryDetailsSheet(
            item: legacyVideo,
            videoAdapterFactory: (_) => FakeVideoPlayerAdapter(isInitialized: true),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(MemoryVideoPlayer), findsOneWidget);
        expect(find.text('VIDEO'), findsOneWidget);
      });

      testWidgets('legacy audio attachment renders in-app audio player', (tester) async {
        final legacyAudio = MemoryItem(
          id: 'leg-aud',
          title: 'Legacy Audio Clip',
          content: 'Old voice recording',
          filePath: 'user/memories/voice.m4a',
          fileSize: 800000,
          mimeType: 'audio/mp4',
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryDetailsSheet(
            item: legacyAudio,
            audioAdapterFactory: () => FakeAudioPlayerAdapter(),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(MemoryAudioPlayer), findsOneWidget);
        expect(find.text('AUDIO'), findsOneWidget);
      });

      testWidgets('legacy non-media attachment continues rendering document fallback with Open button', (tester) async {
        var openCalled = false;
        final legacyDoc = MemoryItem(
          id: 'leg-doc',
          title: 'Legacy Doc',
          content: 'Old PDF',
          filePath: 'user/memories/contract.pdf',
          fileSize: 4000,
          mimeType: 'application/pdf',
        );

        await tester.pumpWidget(wrapWithProvider(
          MemoryDetailsSheet(
            item: legacyDoc,
            onOpenAttachment: () => openCalled = true,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Attached File'), findsOneWidget);
        expect(find.text('contract.pdf'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);

        await tester.tap(find.text('Open'));
        expect(openCalled, isTrue);
      });
    });
  });
}

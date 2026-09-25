import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Abstract adapter interface for video playback to allow clean decoupling
/// and deterministic testing without platform channel dependencies.
abstract class VideoPlayerAdapter {
  bool get isInitialized;
  bool get isPlaying;
  bool get hasError;
  Duration get position;
  Duration get duration;
  double get aspectRatio;

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);

  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> dispose();

  Widget buildVideoView(BuildContext context);
}

/// Production video playback adapter using the official `video_player` package.
class DefaultVideoPlayerAdapter implements VideoPlayerAdapter {
  final VideoPlayerController controller;

  DefaultVideoPlayerAdapter({required String url})
      : controller = VideoPlayerController.networkUrl(Uri.parse(url));

  DefaultVideoPlayerAdapter.fromController(this.controller);

  @override
  bool get isInitialized => controller.value.isInitialized;

  @override
  bool get isPlaying => controller.value.isPlaying;

  @override
  bool get hasError => controller.value.hasError;

  @override
  Duration get position => controller.value.position;

  @override
  Duration get duration => controller.value.duration;

  @override
  double get aspectRatio =>
      controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9;

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      controller.removeListener(listener);

  @override
  Future<void> initialize() => controller.initialize();

  @override
  Future<void> play() => controller.play();

  @override
  Future<void> pause() => controller.pause();

  @override
  Future<void> seekTo(Duration position) => controller.seekTo(position);

  @override
  Future<void> dispose() => controller.dispose();

  @override
  Widget buildVideoView(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: VideoPlayer(controller),
    );
  }
}

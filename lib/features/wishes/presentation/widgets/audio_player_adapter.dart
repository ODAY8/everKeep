import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Abstract adapter interface for audio playback to allow clean decoupling
/// and deterministic testing.
abstract class AudioPlayerAdapter {
  bool get isPlaying;
  Duration get position;
  Duration get duration;

  Stream<Duration> get onPositionChanged;
  Stream<Duration> get onDurationChanged;
  Stream<PlayerState> get onPlayerStateChanged;

  Future<void> play(String url);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

/// Production audio playback adapter using the `audioplayers` package.
class DefaultAudioPlayerAdapter implements AudioPlayerAdapter {
  final AudioPlayer _player;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  DefaultAudioPlayerAdapter([AudioPlayer? player])
      : _player = player ?? AudioPlayer() {
    _stateSub = _player.onPlayerStateChanged.listen((s) => _state = s);
    _posSub = _player.onPositionChanged.listen((p) => _position = p);
    _durSub = _player.onDurationChanged.listen((d) => _duration = d);
  }

  @override
  bool get isPlaying => _state == PlayerState.playing;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  @override
  Future<void> play(String url) => _player.play(UrlSource(url));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _player.stop();
    await _player.dispose();
  }
}

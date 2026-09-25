import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/memory_media_item.dart';
import '../../../../providers/memory_provider.dart';
import 'audio_player_adapter.dart';

/// In-app audio player widget for [MemoryMediaType.audio] assets.
/// Provides voice-recording card UI, play/pause, seekable scrubber,
/// timestamp indicators, loading state, and per-item error recovery with retry.
class MemoryAudioPlayer extends StatefulWidget {
  final MemoryMediaItem media;
  final AudioPlayerAdapter? adapter;
  final bool autoPlay;

  const MemoryAudioPlayer({
    super.key,
    required this.media,
    this.adapter,
    this.autoPlay = false,
  });

  @override
  State<MemoryAudioPlayer> createState() => _MemoryAudioPlayerState();
}

class _MemoryAudioPlayerState extends State<MemoryAudioPlayer> {
  AudioPlayerAdapter? _adapter;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    if (widget.media.durationSeconds != null &&
        widget.media.durationSeconds! > 0) {
      _totalDuration = Duration(seconds: widget.media.durationSeconds!);
    }

    if (widget.adapter != null) {
      _adapter = widget.adapter;
      _subscribeAdapter();
      if (widget.autoPlay) {
        _togglePlayPause();
      }
    } else if (widget.autoPlay) {
      _initializeAndPlay();
    }
  }

  void _subscribeAdapter() {
    if (_adapter == null) return;
    _posSub = _adapter!.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
    });
    _durSub = _adapter!.onDurationChanged.listen((dur) {
      if (!mounted) return;
      if (dur > Duration.zero) {
        setState(() => _totalDuration = dur);
      }
    });
    _stateSub = _adapter!.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = _adapter!.isPlaying);
    });
  }

  Future<void> _initializeAndPlay() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final provider = context.read<MemoryProvider>();
      final signedUrl = await provider.createSignedUrl(widget.media.filePath);

      if (!mounted) return;

      if (signedUrl == null || signedUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      if (_adapter == null) {
        _adapter = DefaultAudioPlayerAdapter();
        _subscribeAdapter();
      }

      await _adapter!.play(signedUrl);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_adapter == null) {
      await _initializeAndPlay();
      return;
    }

    if (_isPlaying) {
      await _adapter!.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      if (_currentPosition == Duration.zero) {
        await _initializeAndPlay();
      } else {
        await _adapter!.resume();
        if (mounted) setState(() => _isPlaying = true);
      }
    }
  }

  Future<void> _seekTo(Duration target) async {
    if (_adapter == null) return;
    await _adapter!.seek(target);
    if (mounted) {
      setState(() => _currentPosition = target);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    if (widget.adapter == null) {
      _adapter?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metaText = [
      if (widget.media.formattedDuration != null)
        widget.media.formattedDuration!,
      widget.media.formattedFileSize,
    ].join(' · ');

    final caption = widget.media.caption?.isNotEmpty == true
        ? widget.media.caption!
        : 'Voice Recording';

    return Semantics(
      label: 'Voice recording attachment: $caption, $metaText',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.glassSurfaceRaised,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Waveform icon, Caption, Metadata, and AUDIO pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.glassAccentPink.withValues(alpha: 0.15),
                    borderRadius: AppRadius.radiusSM,
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.glassAccentPink,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.glassOnSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        metaText,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurface,
                    borderRadius: AppRadius.radiusSM,
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    'AUDIO',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassAccentPink,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Bottom Audio Controls Row
            if (_hasError)
              _buildErrorRow()
            else
              _buildControlsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsRow() {
    final maxMs = _totalDuration.inMilliseconds > 0
        ? _totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final valMs = _currentPosition.inMilliseconds
        .clamp(0, _totalDuration.inMilliseconds)
        .toDouble();

    return Row(
      children: [
        // Play / Pause / Loading button
        Semantics(
          label: _isPlaying
              ? 'Pause voice recording: ${widget.media.caption ?? "Voice recording"}'
              : 'Play voice recording: ${widget.media.caption ?? "Voice recording"}',
          button: true,
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassAccentPink.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.glassAccentPink.withValues(alpha: 0.4),
                ),
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.glassAccentPink,
                        ),
                      )
                    : Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.glassAccentPink,
                        size: 22,
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Scrubbable Audio Slider
        Expanded(
          child: Semantics(
            label:
                'Audio playback position: ${_formatDuration(_currentPosition)} of ${_formatDuration(_totalDuration)}',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: AppColors.glassAccentPink,
                inactiveTrackColor: AppColors.glassBorder,
                thumbColor: AppColors.glassAccentPink,
                overlayColor: AppColors.glassAccentPink.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: valMs,
                min: 0.0,
                max: maxMs,
                onChanged: (val) {
                  _seekTo(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Position / Duration Indicator
        Text(
          '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.glassOnSurfaceMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorRow() {
    return Row(
      children: [
        const Icon(
          Icons.music_off_outlined,
          color: AppColors.glassDestructive,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Unable to play audio',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.glassOnSurfaceMuted,
              fontSize: 11,
            ),
          ),
        ),
        Semantics(
          label: 'Retry audio loading',
          button: true,
          child: TextButton.icon(
            onPressed: _initializeAndPlay,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.glassAccentPink,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

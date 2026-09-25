import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/memory_media_item.dart';
import '../../../../providers/memory_provider.dart';
import 'video_player_adapter.dart';

/// In-app video player widget for [MemoryMediaType.video] assets.
/// Provides inline playback, play/pause, scrubbable progress bar,
/// current position and duration indicators, full-screen expansion,
/// loading state, and per-item error recovery with retry.
class MemoryVideoPlayer extends StatefulWidget {
  final MemoryMediaItem media;
  final VideoPlayerAdapter? adapter;
  final bool autoPlay;

  const MemoryVideoPlayer({
    super.key,
    required this.media,
    this.adapter,
    this.autoPlay = false,
  });

  @override
  State<MemoryVideoPlayer> createState() => _MemoryVideoPlayerState();
}

class _MemoryVideoPlayerState extends State<MemoryVideoPlayer> {
  VideoPlayerAdapter? _adapter;
  bool _isLoading = false;
  bool _hasError = false;
  bool _showControls = true;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.adapter != null) {
      _adapter = widget.adapter;
      _currentPosition = _adapter!.position;
      _adapter!.addListener(_onAdapterUpdate);
      if (widget.autoPlay && !_adapter!.isPlaying) {
        _adapter!.play();
      }
    } else if (widget.autoPlay) {
      _initializePlayer();
    }
  }

  @override
  void didUpdateWidget(covariant MemoryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.adapter != null && widget.adapter != _adapter) {
      _adapter?.removeListener(_onAdapterUpdate);
      _adapter = widget.adapter;
      _currentPosition = _adapter!.position;
      _adapter!.addListener(_onAdapterUpdate);
    }
  }

  void _onAdapterUpdate() {
    if (!mounted || _adapter == null) return;
    setState(() {
      _currentPosition = _adapter!.position;
      if (_adapter!.hasError) {
        _hasError = true;
      }
    });
  }

  Future<void> _initializePlayer() async {
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

      final adapter = DefaultVideoPlayerAdapter(url: signedUrl);
      await adapter.initialize();

      if (!mounted) {
        await adapter.dispose();
        return;
      }

      _adapter?.removeListener(_onAdapterUpdate);
      _adapter?.dispose();

      _adapter = adapter;
      _adapter!.addListener(_onAdapterUpdate);
      await _adapter!.play();

      setState(() {
        _isLoading = false;
        _hasError = false;
      });
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
    if (_adapter == null || !_adapter!.isInitialized) {
      await _initializePlayer();
      return;
    }

    if (_adapter!.isPlaying) {
      await _adapter!.pause();
    } else {
      await _adapter!.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _seekTo(Duration target) async {
    if (_adapter == null) return;
    await _adapter!.seekTo(target);
    if (mounted) {
      setState(() => _currentPosition = target);
    }
  }

  Duration get _totalDuration {
    if (_adapter != null && _adapter!.duration > Duration.zero) {
      return _adapter!.duration;
    }
    if (widget.media.durationSeconds != null &&
        widget.media.durationSeconds! > 0) {
      return Duration(seconds: widget.media.durationSeconds!);
    }
    return Duration.zero;
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

  void _openFullscreen() {
    if (_adapter == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenVideoViewer(
          adapter: _adapter!,
          media: widget.media,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _adapter?.removeListener(_onAdapterUpdate);
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
        : 'Video Clip';

    return Semantics(
      label: 'Video attachment: $caption, $metaText',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.glassSurfaceRaised,
          borderRadius: AppRadius.radiusMD,
          border: Border.all(color: AppColors.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Icon badge, Caption, Meta, and VIDEO pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.glassAccentBlue.withValues(alpha: 0.15),
                      borderRadius: AppRadius.radiusSM,
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: AppColors.glassAccentBlue,
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
                      'VIDEO',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.glassAccentBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Video Player Viewport / Controls Area
            _buildPlayerBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBody() {
    if (_hasError) {
      return _buildErrorState();
    }

    if (_isLoading) {
      return Container(
        height: 180,
        width: double.infinity,
        color: AppColors.glassSurface,
        alignment: Alignment.center,
        child: Semantics(
          label: 'Loading video',
          child: const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.glassAccentBlue,
            ),
          ),
        ),
      );
    }

    if (_adapter == null || !_adapter!.isInitialized) {
      // Lazy placeholder with prominent Play button
      return GestureDetector(
        onTap: _togglePlayPause,
        child: Container(
          height: 180,
          width: double.infinity,
          color: Colors.black.withValues(alpha: 0.4),
          child: Center(
            child: Semantics(
              label: 'Play video: ${widget.media.caption ?? "Video clip"}',
              button: true,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.glassAccentBlue.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.glassAccentBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isPlaying = _adapter!.isPlaying;
    final total = _totalDuration;
    final pos = _currentPosition;
    final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
    final valMs = pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble();

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Video View
          _adapter!.buildVideoView(context),

          // Controls Overlay
          if (_showControls) ...[
            // Center Play / Pause button
            Positioned.fill(
              child: Center(
                child: Semantics(
                  label: isPlaying ? 'Pause video' : 'Play video',
                  button: true,
                  child: IconButton(
                    iconSize: 48,
                    onPressed: _togglePlayPause,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Bar: Progress slider, Timestamps, Fullscreen
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label:
                            'Video playback position: ${_formatDuration(pos)} of ${_formatDuration(total)}',
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10),
                            activeTrackColor: AppColors.glassAccentBlue,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppColors.glassAccentBlue,
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
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDuration(pos)} / ${_formatDuration(total)}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                    Semantics(
                      label: 'Enter fullscreen',
                      button: true,
                      child: IconButton(
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Fullscreen',
                        onPressed: _openFullscreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      width: double.infinity,
      color: AppColors.glassSurface,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: AppColors.glassDestructive,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            'Unable to load video',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            label: 'Retry video loading',
            button: true,
            child: TextButton.icon(
              onPressed: _initializePlayer,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.glassAccentBlue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fullscreen view for in-app video playback.
class _FullscreenVideoViewer extends StatefulWidget {
  final VideoPlayerAdapter adapter;
  final MemoryMediaItem media;

  const _FullscreenVideoViewer({
    required this.adapter,
    required this.media,
  });

  @override
  State<_FullscreenVideoViewer> createState() => _FullscreenVideoViewerState();
}

class _FullscreenVideoViewerState extends State<_FullscreenVideoViewer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.adapter.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.adapter.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
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
  Widget build(BuildContext context) {
    final adapter = widget.adapter;
    final isPlaying = adapter.isPlaying;
    final pos = adapter.position;
    final total = adapter.duration > Duration.zero
        ? adapter.duration
        : Duration(seconds: widget.media.durationSeconds ?? 0);
    final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
    final valMs = pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            children: [
              // Center Video
              Center(child: adapter.buildVideoView(context)),

              // Top Bar
              if (_showControls)
                Positioned(
                  top: 10,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Semantics(
                        label: 'Close fullscreen',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.fullscreen_exit_rounded,
                              color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      if (widget.media.caption != null)
                        Expanded(
                          child: Text(
                            widget.media.caption!,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

              // Center Play/Pause button
              if (_showControls)
                Center(
                  child: IconButton(
                    iconSize: 56,
                    icon: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () async {
                      if (isPlaying) {
                        await adapter.pause();
                      } else {
                        await adapter.play();
                      }
                      setState(() {});
                    },
                  ),
                ),

              // Bottom Bar
              if (_showControls)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: AppRadius.radiusMD,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8),
                            activeTrackColor: AppColors.glassAccentBlue,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppColors.glassAccentBlue,
                          ),
                          child: Slider(
                            value: valMs,
                            min: 0.0,
                            max: maxMs,
                            onChanged: (val) {
                              adapter.seekTo(Duration(milliseconds: val.toInt()));
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_formatDuration(pos)} / ${_formatDuration(total)}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

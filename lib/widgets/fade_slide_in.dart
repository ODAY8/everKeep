import 'package:flutter/material.dart';

/// A lightweight staggered entrance: fades and slides [child] up into place
/// once, on first build. Used for grids and lists (Home's dashboard,
/// Documents, Trusted People, the Memories masonry) so content settles in
/// rather than popping in all at once — cheap (opacity + translate only),
/// so safe to use across several items without jank.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration stagger;
  final Duration duration;

  /// Only the first few items are staggered. Past this, items animate together:
  /// otherwise item 100 would wait 4 seconds (100 x 40ms) before appearing, and
  /// long lists would feel slow to fill in.
  static const int maxStaggeredItems = 6;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.stagger = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);

    final delay =
        widget.stagger * widget.index.clamp(0, FadeSlideIn.maxStaggeredItems);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

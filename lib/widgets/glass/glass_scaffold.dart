import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// The shared page shell for the glass theme: a flat near-black background
/// and a SafeArea around the scrollable content — matches the Figma
/// reference's flat editorial canvas (no ambient glow).
class GlassScaffold extends StatelessWidget {
  final Widget child;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  /// When given, the content can be pulled down to refresh (e.g. reloading a
  /// list from the backend). Requires [scrollable] (the default).
  final Future<void> Function()? onRefresh;

  const GlassScaffold({
    super.key,
    required this.child,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 110),
    this.scrollable = true,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final content = scrollable
        ? SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: padding,
            child: child,
          )
        : Padding(padding: padding, child: child);

    final refreshable = onRefresh == null
        ? content
        : RefreshIndicator(
            onRefresh: onRefresh!,
            color: AppColors.glassAccentPink,
            backgroundColor: AppColors.glassSurfaceRaised,
            child: content,
          );

    final hasParentScaffold = Scaffold.maybeOf(context) != null &&
        bottomNavigationBar == null &&
        floatingActionButton == null;

    if (hasParentScaffold) {
      return SafeArea(bottom: false, child: refreshable);
    }

    return Scaffold(
      backgroundColor: AppColors.glassBackground,
      body: SafeArea(bottom: bottomNavigationBar == null, child: refreshable),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

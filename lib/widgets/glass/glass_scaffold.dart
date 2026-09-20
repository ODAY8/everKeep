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

  const GlassScaffold({
    super.key,
    required this.child,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 110),
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = scrollable
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: padding,
            child: child,
          )
        : Padding(padding: padding, child: child);

    return Scaffold(
      backgroundColor: AppColors.glassBackground,
      body: SafeArea(bottom: bottomNavigationBar == null, child: content),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

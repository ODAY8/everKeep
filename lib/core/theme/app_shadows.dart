import 'package:flutter/material.dart';

class AppShadows {
  static const List<BoxShadow> softCardShadow = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> selectedShadow = [
    BoxShadow(
      color: Color(0x22000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> floatingCardShadow = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> floatingNavShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// The dual-layer soft shadow used on every gradient button, FAB, and
  /// nav-add button in the Figma reference.
  static const List<BoxShadow> accentButtonShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x3D000000),
      blurRadius: 5,
      offset: Offset(0, 4),
    ),
  ];

  /// Dual-layer shadow specifically for masonry/photo cards (Memories grid).
  static const List<BoxShadow> photoCardShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x3D000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> onboardingCardShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 40,
      offset: Offset(0, 16),
    ),
  ];

  static const List<BoxShadow> dialogShadow = [
    BoxShadow(
      color: Color(0x22000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> tooltipShadow = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> bottomSheetShadow = [
    BoxShadow(
      color: Color(0x22000000),
      blurRadius: 40,
      offset: Offset(0, -8),
    ),
  ];

  static const List<BoxShadow> elevation1 = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> elevation2 = [
    BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> elevation4 = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> elevation8 = [
    BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, 8)),
  ];

  static List<BoxShadow> cardShadowLight(BuildContext context) => cardShadow;
  static List<BoxShadow> cardShadowDark(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> floatingCardShadowLight(BuildContext context) =>
      floatingCardShadow;
  static List<BoxShadow> floatingCardShadowDark(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> accentGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

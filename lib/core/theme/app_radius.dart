import 'package:flutter/material.dart';

class AppRadius {
  // Border radius constants for existing components.
  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double xxl = 20.0;
  static const double xxxl = 24.0;

  // Larger radii used by the warm, editorial dashboard surfaces.
  static const double cardXL = 28.0;
  static const double cardXXL = 32.0;
  static const double shell = 38.0;
  static const double pill = 999.0;

  // Border radius geometries.
  static const BorderRadius radiusXS = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSM = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMD = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLG = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXL = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusXXL = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius radiusXXXL = BorderRadius.all(Radius.circular(xxxl));
  static const BorderRadius radiusCardXL = BorderRadius.all(Radius.circular(cardXL));
  static const BorderRadius radiusCardXXL = BorderRadius.all(Radius.circular(cardXXL));
  static const BorderRadius radiusShell = BorderRadius.all(Radius.circular(shell));
  static const BorderRadius radiusPill = BorderRadius.all(Radius.circular(pill));

  // Specific radii for different UI elements.
  static const BorderRadius buttonSmall = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius buttonMedium = BorderRadius.all(Radius.circular(md));
  static const BorderRadius buttonLarge = BorderRadius.all(Radius.circular(lg));

  static const BorderRadius cardSmall = BorderRadius.all(Radius.circular(md));
  static const BorderRadius cardMedium = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius cardLarge = BorderRadius.all(Radius.circular(xl));

  static const BorderRadius avatarSmall = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius avatarMedium = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius avatarLarge = BorderRadius.all(Radius.circular(md));

  static const BorderRadius inputField = BorderRadius.all(Radius.circular(md));
  static const BorderRadius inputFieldFocused = BorderRadius.all(Radius.circular(lg));
}

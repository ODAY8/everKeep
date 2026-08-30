import 'package:flutter/material.dart';

class AppSpacing {
  // Base spacing unit
  static const double base = 8.0;

  // Multiples of base spacing
  static const double xs = base * 0.5;   // 4.0
  static const double sm = base * 0.75;  // 6.0
  static const double md = base * 1.0;   // 8.0
  static const double lg = base * 1.5;   // 12.0
  static const double xl = base * 2.0;   // 16.0
  static const double xxl = base * 2.5;  // 20.0
  static const double xxxl = base * 3.0; // 24.0

  // Padding constants
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);
  static const EdgeInsets paddingXXL = EdgeInsets.all(xxl);
  static const EdgeInsets paddingXXXL = EdgeInsets.all(xxxl);

  // Horizontal padding
  static const EdgeInsets paddingHorizontalXS = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets paddingHorizontalSM = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMD = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLG = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXL = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets paddingHorizontalXXL = EdgeInsets.symmetric(horizontal: xxl);
  static const EdgeInsets paddingHorizontalXXXL = EdgeInsets.symmetric(horizontal: xxxl);

  // Vertical padding
  static const EdgeInsets paddingVerticalXS = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets paddingVerticalSM = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMD = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLG = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVerticalXL = EdgeInsets.symmetric(vertical: xl);
  static const EdgeInsets paddingVerticalXXL = EdgeInsets.symmetric(vertical: xxl);
  static const EdgeInsets paddingVerticalXXXL = EdgeInsets.symmetric(vertical: xxxl);

  // Margin constants
  static const EdgeInsets marginXS = EdgeInsets.all(xs);
  static const EdgeInsets marginSM = EdgeInsets.all(sm);
  static const EdgeInsets marginMD = EdgeInsets.all(md);
  static const EdgeInsets marginLG = EdgeInsets.all(lg);
  static const EdgeInsets marginXL = EdgeInsets.all(xl);
  static const EdgeInsets marginXXL = EdgeInsets.all(xxl);
  static const EdgeInsets marginXXXL = EdgeInsets.all(xxxl);

  // Radius constants
  static const double radiusXS = xs;
  static const double radiusSM = sm;
  static const double radiusMD = md;
  static const double radiusLG = lg;
  static const double radiusXL = xl;
  static const double radiusXXL = xxl;
  static const double radiusXXXL = xxxl;

  // Icon sizes
  static const double iconSizeXS = 16.0;
  static const double iconSizeSM = 20.0;
  static const double iconSizeMD = 24.0;
  static const double iconSizeLG = 28.0;
  static const double iconSizeXL = 32.0;
  static const double iconSizeXXL = 36.0;
  static const double iconSizeXXXL = 40.0;

  // Text sizes
  static const double textSizeXS = 10.0;
  static const double textSizeSM = 12.0;
  static const double textSizeMD = 14.0;
  static const double textSizeLG = 16.0;
  static const double textSizeXL = 18.0;
  static const double textSizeXXL = 20.0;
  static const double textSizeXXXL = 24.0;
}
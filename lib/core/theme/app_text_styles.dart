import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // ── Sans-serif (Figtree) — authenticated app ────────────────────────────────
  static TextStyle get displayLarge => GoogleFonts.figtree(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.5,
      );

  static TextStyle get displayMedium => GoogleFonts.figtree(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -1.0,
      );

  static TextStyle get displaySmall => GoogleFonts.figtree(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.8,
      );

  static TextStyle get headlineLarge => GoogleFonts.figtree(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineMedium => GoogleFonts.figtree(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.3,
      );

  static TextStyle get headlineSmall => GoogleFonts.figtree(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
      );

  static TextStyle get titleLarge => GoogleFonts.figtree(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get titleMedium => GoogleFonts.figtree(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
      );

  static TextStyle get titleSmall => GoogleFonts.figtree(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  static TextStyle get bodyLarge => GoogleFonts.figtree(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
      );

  static TextStyle get bodyMedium => GoogleFonts.figtree(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.55,
      );

  static TextStyle get bodySmall => GoogleFonts.figtree(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get labelLarge => GoogleFonts.figtree(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  static TextStyle get labelMedium => GoogleFonts.figtree(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  static TextStyle get labelSmall => GoogleFonts.figtree(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.2,
      );

  /// Uppercase section labels and input labels (e.g. "ACCOUNT", "EMAIL
  /// ADDRESS"). Apply `.toUpperCase()` to the string — this style only sets
  /// weight/tracking, not a text transform.
  static TextStyle get overline => GoogleFonts.figtree(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.4,
      );

  // ── Serif (Young Serif) — editorial headings ────────────────────────────────
  // Young Serif ships as a single (Regular) weight, so every serif style is
  // w400 — never bolded.
  static TextStyle get serifDisplayLarge => GoogleFonts.youngSerif(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 1.22,
      );

  static TextStyle get serifDisplayMedium => GoogleFonts.youngSerif(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        height: 1.2,
      );

  static TextStyle get serifHeadline => GoogleFonts.youngSerif(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        height: 1.25,
      );

  /// Onboarding card titles.
  static TextStyle get serifTitleMedium => GoogleFonts.youngSerif(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        height: 1.25,
      );

  /// Hero-card titles (home dashboard, profile name, vault-score headline).
  static TextStyle get serifTitleSmall => GoogleFonts.youngSerif(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        height: 1.3,
      );

  /// Section labels set in serif (e.g. "Vault Chapters").
  static TextStyle get serifLabel => GoogleFonts.youngSerif(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.3,
      );

  // ── Adaptive helpers ───────────────────────────────────────────────────────
  static TextStyle displayLargeLight(BuildContext context) =>
      displayLarge.copyWith(color: AppColors.lightOnBackground);

  static TextStyle displayLargeDark(BuildContext context) =>
      displayLarge.copyWith(color: AppColors.darkOnBackground);

  static TextStyle headlineLargeLight(BuildContext context) =>
      headlineLarge.copyWith(color: AppColors.lightOnBackground);

  static TextStyle headlineLargeDark(BuildContext context) =>
      headlineLarge.copyWith(color: AppColors.darkOnBackground);

  static TextStyle titleLargeLight(BuildContext context) =>
      titleLarge.copyWith(color: AppColors.lightOnBackground);

  static TextStyle titleLargeDark(BuildContext context) =>
      titleLarge.copyWith(color: AppColors.darkOnBackground);

  static TextStyle bodyLargeLight(BuildContext context) =>
      bodyLarge.copyWith(color: AppColors.lightOnBackground);

  static TextStyle bodyLargeDark(BuildContext context) =>
      bodyLarge.copyWith(color: AppColors.darkOnBackground);

  static TextStyle bodyMediumLight(BuildContext context) =>
      bodyMedium.copyWith(color: AppColors.lightOnBackground);

  static TextStyle bodyMediumDark(BuildContext context) =>
      bodyMedium.copyWith(color: AppColors.darkOnBackground);

  static TextStyle bodySmallLight(BuildContext context) =>
      bodySmall.copyWith(color: AppColors.lightOnBackground);

  static TextStyle bodySmallDark(BuildContext context) =>
      bodySmall.copyWith(color: AppColors.darkOnBackground);

  static TextStyle labelLargeLight(BuildContext context) =>
      labelLarge.copyWith(color: AppColors.lightOnBackground);

  static TextStyle labelLargeDark(BuildContext context) =>
      labelLarge.copyWith(color: AppColors.darkOnBackground);
}

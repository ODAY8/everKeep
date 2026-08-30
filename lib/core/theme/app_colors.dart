import 'package:flutter/material.dart';

class AppColors {
  // ── Authenticated app accent (pink / crimson / coral) ──────────────────────
  static const Color accentPink = Color(0xFFE8445A);
  static const Color accentCoral = Color(0xFFFF6B6B);
  static const Color accentCrimson = Color(0xFFC0392B);
  static const Color accentBurgundy = Color(0xFF1A0A0E);
  static const Color accentPinkLight = Color(0xFFFFE8EC);
  static const Color accentPinkMid = Color(0xFFFFC2CB);

  // ── Onboarding accent (deep navy / royal blue) ─────────────────────────────
  static const Color navyDeep = Color(0xFF0A0E2A);
  static const Color navyMid = Color(0xFF0D1B4B);
  static const Color royalBlue = Color(0xFF1E3A8A);
  static const Color skyBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFF93C5FD);

  // ── Light theme ────────────────────────────────────────────────────────────
  static const Color lightPrimary = Color(0xFF121212);
  static const Color lightSecondary = Color(0xFFE8445A);
  static const Color lightBackground = Color(0xFFF7F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF2F2F5);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightOnBackground = Color(0xFF121212);
  static const Color lightOnSurface = Color(0xFF121212);
  static const Color lightOutline = Color(0xFFE8E8EE);

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static const Color darkPrimary = Color(0xFFF7F2E7);
  static const Color darkSecondary = Color(0xFFE8445A);
  static const Color darkBackground = Color(0xFF0F0F12);
  static const Color darkSurface = Color(0xFF1A1A20);
  static const Color darkSurfaceVariant = Color(0xFF252530);
  static const Color darkOnPrimary = Color(0xFF0F0F12);
  static const Color darkOnSecondary = Color(0xFFFFFFFF);
  static const Color darkOnBackground = Color(0xFFF7F2E7);
  static const Color darkOnSurface = Color(0xFFF7F2E7);
  static const Color darkOutline = Color(0xFF2E2E3A);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color lightSuccess = Color(0xFF22C55E);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightInfo = Color(0xFF3B82F6);

  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkInfo = Color(0xFF60A5FA);

  // ── Soft tinted surfaces ───────────────────────────────────────────────────
  static const Color lightLavender = Color(0xFFEDE9FE);
  static const Color lightPeach = Color(0xFFFEE2E2);
  static const Color lightMint = Color(0xFFD1FAE5);
  static const Color lightGold = Color(0xFFFEF3C7);
  static const Color darkLavender = Color(0xFF2D2040);
  static const Color darkPeach = Color(0xFF3D1515);
  static const Color darkMint = Color(0xFF0D2E1E);
  static const Color darkGold = Color(0xFF2D2000);

  // ── Gradients ──────────────────────────────────────────────────────────────

  /// Primary CTA gradient: coral → crimson → near-black
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFE8445A), Color(0xFF8B0000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Header gradient: warm glow top, dark bottom
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFFE8445A), Color(0xFFB91C3A), Color(0xFF1A0A0E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
  );

  /// Vault header gradient
  static const LinearGradient vaultHeaderGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFE8445A), Color(0xFFC0392B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Onboarding deep navy gradient
  static const LinearGradient onboardingGradient = LinearGradient(
    colors: [Color(0xFF0A0E2A), Color(0xFF0D1B4B), Color(0xFF0A1628)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Onboarding blue glow
  static const RadialGradient onboardingGlow = RadialGradient(
    colors: [Color(0x553B82F6), Color(0x001E3A8A)],
    radius: 0.8,
    center: Alignment(0.0, -0.3),
  );

  /// Text gradient for "digital legacy" headline
  static const LinearGradient textAccentGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFE8445A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Glass / dark editorial theme (Figma "Everkeep" reference) ──────────────
  // The primary visual system for the authenticated app: a flat near-black
  // canvas, bordered (not shadowed) surface cards, and a warm coral→crimson
  // accent used sparingly for CTAs, active states, and emphasis.

  /// App-wide near-black canvas.
  static const Color glassBackground = Color(0xFF111113);

  /// Default glass card fill.
  static const Color glassSurface = Color(0xFF1F1F24);

  /// The bottom-nav bar fill — darker than a card, not lighter.
  static const Color glassSurfaceRaised = Color(0xFF18181C);

  /// Alias for [glassSurfaceRaised], named for its one dedicated use.
  static const Color glassNavBarBg = glassSurfaceRaised;

  /// Hairline border used on all glass cards.
  static const Color glassBorder = Color(0xFF2A2A30);

  /// Primary text on the glass theme.
  static const Color glassOnSurface = Color(0xFFFFFFFF);

  /// Secondary/muted text on the glass theme.
  static const Color glassOnSurfaceMuted = Color(0xFFA1A1AA);

  /// Faint section-label text (e.g. "ACCOUNT", "QUICK ACCESS").
  static const Color glassOnSurfaceFaint = Color(0xFF71717A);

  /// Coral accent used for CTAs, active nav, links, glows.
  static const Color glassAccentPink = Color(0xFFE85C6C);

  /// Deep crimson accent, the far end of the accent gradient.
  static const Color glassAccentCrimson = Color(0xFFD84C72);

  /// Blue accent reserved for legacy security/trust callouts.
  static const Color glassAccentBlue = Color(0xFF3B82F6);

  /// Green accent reserved for "secured / verified" status dots and badges.
  static const Color glassAccentGreen = Color(0xFF34C759);

  /// Peach/secondary accent for trust badges and secondary emphasis.
  static const Color glassAccentSecondary = Color(0xFFFA9B7C);

  /// Tinted background behind [glassAccentSecondary] badges.
  static const Color glassAccentSecondaryBg = Color(0xFF34221A);

  /// Tinted background behind [glassAccentGreen] success badges/icons.
  static const Color glassSuccessBg = Color(0xFF14321A);

  /// Gold warning accent (e.g. PREMIUM badge).
  static const Color glassWarningColor = Color(0xFFF5C045);

  /// Tinted background behind [glassWarningColor] badges.
  static const Color glassWarningBg = Color(0x26F5C045);

  /// Destructive red (delete/sign-out affordances).
  static const Color glassDestructive = Color(0xFFFF453A);

  /// Dark-maroon tint behind feature/category icon-chip containers.
  static const Color glassIconChipBg = Color(0xFF341A23);

  /// CTA / active-state gradient: coral → deep crimson.
  static const LinearGradient glassAccentGradient = LinearGradient(
    colors: [glassAccentPink, glassAccentCrimson],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// No longer used — the Figma reference uses flat solid backgrounds with
  /// no ambient glow. Kept as a transparent no-op so any remaining call
  /// sites render correctly without needing an edit.
  static const RadialGradient glassAmbientGlow = RadialGradient(
    colors: [Colors.transparent, Colors.transparent],
    radius: 0.9,
    center: Alignment(0.0, -0.6),
  );

  /// Tinted glass fill for pink-emphasis cards.
  static const LinearGradient glassPinkTint = LinearGradient(
    colors: [Color(0xFF2A1620), Color(0xFF1B121A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Tinted glass fill for the blue security-score callout.
  static const LinearGradient glassBlueTint = LinearGradient(
    colors: [Color(0xFF13223D), Color(0xFF161425)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

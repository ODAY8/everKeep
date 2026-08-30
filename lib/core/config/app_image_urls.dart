/// Centralized registry of image sources — bundled Figma-sourced assets
/// where available, temporary Unsplash URLs elsewhere (pending Figma API
/// quota to fetch the remainder — see `assets/images/` for what's already
/// local).
///
/// Every photographic placeholder in the app should be referenced through
/// this file rather than hardcoded inline, so the whole set can be swapped
/// out in one place.
class AppImageUrls {
  AppImageUrls._();

  /// Welcome screen hero: premium parent-child lifestyle moment.
  static const String welcomeHero = 'assets/images/welcome_hero.png';

  /// Sign In screen background photo.
  static const String loginBackground = 'assets/images/login_background.png';

  /// Onboarding page 1, front card: candid family/memory snapshot.
  static const String onboardingFamilyPrimary =
      'assets/images/onboarding_hero.png';

  /// Onboarding page 1, back card: family memory, warm/nostalgic tone.
  static const String onboardingFamilySecondary =
      'https://images.unsplash.com/photo-1511895426328-dc8714191300?w=800&q=80&auto=format&fit=crop';

  /// Onboarding page 2: identity/biometric scan subject portrait.
  static const String onboardingSecurityFace =
      'https://images.unsplash.com/photo-1607746882042-944635dfe10e?w=800&q=80&auto=format&fit=crop';

  /// Default mock user avatar (dashboard, profile).
  static const String mockUserAvatar = 'assets/images/home_avatar.png';

  // ── Memories grid (temporary warm/candid lifestyle photography) ──────────
  static const String memoryFamilySummer =
      'https://images.unsplash.com/photo-1511895426328-dc8714191300?w=600&q=80&auto=format&fit=crop';
  static const String memoryOurFirstHome =
      'https://images.unsplash.com/photo-1509062522246-3755977927d7?w=600&q=80&auto=format&fit=crop';
  static const String memoryMorningWalks =
      'https://images.unsplash.com/photo-1476703993599-0035a21b17a9?w=600&q=80&auto=format&fit=crop';
  static const String memoryDadsBirthday =
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600&q=80&auto=format&fit=crop';
  static const String memoryChristmasTogether =
      'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=600&q=80&auto=format&fit=crop';

  /// Home dashboard hero card background.
  static const String homeHeroCard = 'assets/images/home_hero_card.png';

  // ── Trusted People avatars ────────────────────────────────────────────────
  static const String trustedContact1 = 'assets/images/trusted_1.png';
  static const String trustedContact2 = 'assets/images/trusted_2.png';
  static const String trustedContact3 = 'assets/images/trusted_3.png';
  static const String trustedContact4 = 'assets/images/trusted_4.png';

  // ── Future Messages sender avatars ────────────────────────────────────────
  static const String futureMessageAvatar1 =
      'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&q=80&auto=format&fit=crop';
  static const String futureMessageAvatar2 =
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&q=80&auto=format&fit=crop';
  static const String futureMessageAvatar3 =
      'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=150&q=80&auto=format&fit=crop';
}

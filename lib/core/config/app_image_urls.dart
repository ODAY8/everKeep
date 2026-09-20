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

  static const String welcomeHero = 'assets/images/welcome_hero.png';
  static const String loginBackground = 'assets/images/login_background.png';
  static const String onboardingFamilyPrimary = 'assets/images/onboarding_hero.png';
  static const String onboardingFamilySecondary = 'assets/images/welcome_hero.png';
  static const String onboardingSecurityFace = 'assets/images/login_background.png';
  static const String mockUserAvatar = 'assets/images/home_avatar.png';
  static const String homeHeroCard = 'assets/images/home_hero_card.png';

  // ── Memories grid ────────────────────────────────────────────────────────
  static const String memoryFamilySummer = 'assets/images/trusted_1.png';
  static const String memoryChristmasTogether = 'assets/images/trusted_2.png';
  static const String memoryOurFirstHome = 'assets/images/trusted_3.png';
  static const String memoryMorningWalks = 'assets/images/trusted_4.png';
  static const String memoryDadsBirthday = 'assets/images/home_avatar.png';

  // ── Trusted People avatars ────────────────────────────────────────────────
  static const String trustedContact1 = 'assets/images/trusted_1.png';
  static const String trustedContact2 = 'assets/images/trusted_2.png';
  static const String trustedContact3 = 'assets/images/trusted_3.png';
  static const String trustedContact4 = 'assets/images/trusted_4.png';

  // ── Future Messages sender avatars ───────────────────────────────────────
  static const String futureMessageAvatar1 = 'assets/images/trusted_1.png';
  static const String futureMessageAvatar2 = 'assets/images/trusted_2.png';
  static const String futureMessageAvatar3 = 'assets/images/trusted_3.png';
}

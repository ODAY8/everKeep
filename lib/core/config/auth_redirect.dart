/// The address Supabase's emails send people back to — the "confirm your email"
/// and "reset your password" links. It is a custom URL scheme that Android and
/// iOS route to this app (declared in AndroidManifest.xml and Info.plist).
///
/// This exact value must also be listed under Authentication → URL Configuration
/// → Redirect URLs in your Supabase project, or Supabase will refuse to use it.
/// Override it at build time with `--dart-define=AUTH_REDIRECT_URL=...` (and
/// change the manifest to match) if you change the app's package id.
class AuthRedirect {
  AuthRedirect._();

  static const String scheme = 'com.example.everkeep';
  static const String host = 'login-callback';

  static const String url = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: '$scheme://$host/',
  );
}

/// Where Everkeep sends people for help and legal text. Supplied at build time
/// (see `.env.example`); anything left empty is simply not shown in the app, so
/// there are never links that go nowhere.
///
///     SUPPORT_EMAIL=help@yourdomain.com
///     HELP_URL=https://yourdomain.com/help
///     TERMS_URL=https://yourdomain.com/terms
///     PRIVACY_URL=https://yourdomain.com/privacy
class AppLinks {
  AppLinks._();

  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const String helpUrl = String.fromEnvironment('HELP_URL');
  static const String termsUrl = String.fromEnvironment('TERMS_URL');
  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL');

  static bool get hasHelp => helpUrl.isNotEmpty;
  static bool get hasContact => supportEmail.isNotEmpty;
  static bool get hasSupport => hasHelp || hasContact;
  static bool get hasLegal => termsUrl.isNotEmpty || privacyUrl.isNotEmpty;

  /// A `mailto:` link that opens the user's mail app addressed to support.
  static Uri? get contactUri => hasContact
      ? Uri(
          scheme: 'mailto',
          path: supportEmail,
          queryParameters: {'subject': 'Everkeep support'},
        )
      : null;

  /// Parses [url], accepting only web links (http/https). Anything else —
  /// empty, malformed, or a non-web scheme — is rejected.
  static Uri? webUri(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return (uri.scheme == 'https' || uri.scheme == 'http') ? uri : null;
  }
}

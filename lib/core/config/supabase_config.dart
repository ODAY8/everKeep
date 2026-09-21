import 'dart:convert';

/// Supabase connection settings, supplied at build/run time:
///
///     flutter run --dart-define-from-file=.env
///
/// (see `.env.example`). Only the project URL and the *publishable* key belong
/// here. The publishable key is designed to ship inside client apps; what it
/// can do is limited by Row Level Security. A secret / service-role key must
/// never be placed in the app — [validate] refuses to start if one is found.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// What is wrong with the supplied settings, or null if they are usable.
  static String? get problem =>
      validate(url: url, publishableKey: publishableKey);

  static bool get isConfigured => problem == null;

  /// Checks a URL/key pair. Returns a message for the developer describing the
  /// first problem found, or null when both look usable.
  static String? validate({
    required String url,
    required String publishableKey,
  }) {
    if (url.trim().isEmpty || publishableKey.trim().isEmpty) {
      return 'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are not set.';
    }
    if (_isPlaceholder(url) || _isPlaceholder(publishableKey)) {
      return 'SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY still contain the '
          'placeholder values from .env.example.';
    }

    final uri = Uri.tryParse(url.trim());
    final validScheme = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    if (!validScheme || uri.host.isEmpty) {
      return 'SUPABASE_URL must be a full URL such as '
          'https://<project-ref>.supabase.co.';
    }

    if (_looksLikeSecretKey(publishableKey.trim())) {
      return 'SUPABASE_PUBLISHABLE_KEY looks like a secret / service-role key. '
          'Never put one in the app — use the publishable (anon) key instead.';
    }
    return null;
  }

  static bool _isPlaceholder(String value) {
    final v = value.toLowerCase();
    return v.contains('xxxxx') ||
        v.contains('your-') ||
        v.contains('<') ||
        v.contains('changeme');
  }

  /// True for the new-style `sb_secret_…` keys and for legacy JWT keys whose
  /// role is `service_role`.
  static bool _looksLikeSecretKey(String key) {
    if (key.startsWith('sb_secret_')) return true;

    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload);
      return claims is Map && claims['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}

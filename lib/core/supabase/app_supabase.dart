import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// The single place Supabase is initialised and its client is obtained.
///
/// `main()` calls [initialize] once before `runApp`; every service reads
/// [client] rather than creating its own. Screens and providers never touch
/// this — they go through repositories.
class AppSupabase {
  AppSupabase._();

  /// Starts Supabase and restores any persisted session. Call once, at startup.
  static Future<void> initialize() {
    return Supabase.initialize(
      url: SupabaseConfig.url.trim(),
      publishableKey: SupabaseConfig.publishableKey.trim(),
    );
  }

  /// The shared client. Throws if [initialize] has not run.
  static SupabaseClient get client => Supabase.instance.client;
}

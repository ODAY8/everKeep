import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'supabase_errors.dart';

extension SignedInUser on supa.SupabaseClient {
  /// The signed-in Supabase user, or a [BackendException] saying the session
  /// has ended. Row Level Security is what actually protects the data; this
  /// just turns "no session" into a clear message before a request is made.
  supa.User get requireUser =>
      auth.currentUser ??
      (throw const BackendException(
        'Your session has expired. Please sign in again.',
      ));
}

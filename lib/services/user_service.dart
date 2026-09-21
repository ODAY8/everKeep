import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../core/supabase/app_supabase.dart';
import '../core/supabase/client_extensions.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/user.dart';

abstract class UserService {
  Future<User> fetchUserProfile();
  Future<User> updateUserProfile(User user);
}

/// [UserService] backed by the `profiles` table.
///
/// Identity (id, email, last sign-in) comes from Supabase Auth; the profile
/// row only holds Everkeep's own data (name, phone, avatar). Row Level
/// Security restricts every query to the caller's own row.
class UserServiceImpl implements UserService {
  final supa.SupabaseClient _client;

  UserServiceImpl({supa.SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  @override
  Future<User> fetchUserProfile() {
    return guardBackend(() async {
      final authUser = _client.requireUser;

      var row = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      // A database trigger creates the row at sign-up. If it is missing for
      // any reason, create it now rather than leaving the account without one.
      row ??= await _client
          .from('profiles')
          .upsert({'id': authUser.id, 'full_name': _metadataName(authUser)})
          .select()
          .single();

      return _toAppUser(authUser, row);
    });
  }

  @override
  Future<User> updateUserProfile(User user) {
    return guardBackend(() async {
      final authUser = _client.requireUser;

      final row = await _client
          .from('profiles')
          .update(user.toProfileRow())
          .eq('id', authUser.id)
          .select()
          .single();

      return _toAppUser(authUser, row);
    });
  }

  String _metadataName(supa.User user) =>
      (user.userMetadata?['full_name'] as String?)?.trim() ?? '';

  User _toAppUser(supa.User authUser, Map<String, dynamic> profile) {
    return User.fromAuth(
      id: authUser.id,
      email: authUser.email,
      profile: profile,
      metadataName: _metadataName(authUser),
      lastLogin: DateTime.tryParse(authUser.lastSignInAt ?? '')?.toLocal(),
    );
  }
}

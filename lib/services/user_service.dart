import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../core/supabase/app_supabase.dart';
import '../core/supabase/client_extensions.dart';
import '../core/supabase/supabase_errors.dart';
import '../models/document_upload.dart';
import '../models/user.dart';

abstract class UserService {
  Future<User> fetchUserProfile();
  Future<User> updateUserProfile(User user);

  /// Replaces the profile photo. [photo] must be a PNG (see `pickAvatar`).
  Future<User> uploadAvatar(User user, DocumentUpload photo);
  Future<User> removeAvatar(User user);

  /// Everything the account holds, as a JSON-ready map, for "Download my data".
  Future<Map<String, dynamic>> exportMyData();

  /// Permanently deletes the account and everything in it, including stored
  /// files. Signs the device out at the end.
  Future<void> deleteAccount();
}

/// [UserService] backed by the `profiles` table.
///
/// Identity (id, email, last sign-in) comes from Supabase Auth; the profile
/// row only holds Everkeep's own data (name, phone, avatar). Row Level
/// Security restricts every query to the caller's own row.
class UserServiceImpl implements UserService {
  static const String _documentsBucket = 'documents';
  static const String _avatarsBucket = 'avatars';

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

  @override
  Future<User> uploadAvatar(User user, DocumentUpload photo) {
    return guardBackend(() async {
      final authUser = _client.requireUser;
      if (photo.mimeType != 'image/png') {
        throw const BackendException('Please choose a photo (PNG, JPG or WebP).');
      }

      // One file per user, replaced in place: no orphaned old photos.
      final path = '${authUser.id}/avatar.png';
      await _client.storage
          .from(_avatarsBucket)
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: const supa.FileOptions(
              contentType: 'image/png',
              upsert: true,
              cacheControl: '3600',
            ),
          );

      // The URL never changes for a given path, so add a version to make every
      // screen (and the image cache) pick up the new picture.
      final url =
          '${_client.storage.from(_avatarsBucket).getPublicUrl(path)}'
          '?v=${DateTime.now().millisecondsSinceEpoch}';

      final row = await _client
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', authUser.id)
          .select()
          .single();
      return _toAppUser(authUser, row);
    });
  }

  @override
  Future<User> removeAvatar(User user) {
    return guardBackend(() async {
      final authUser = _client.requireUser;

      // Removing a file that isn't there is not an error worth surfacing.
      await _client.storage.from(_avatarsBucket).remove([
        '${authUser.id}/avatar.png',
      ]);

      final row = await _client
          .from('profiles')
          .update({'avatar_url': null})
          .eq('id', authUser.id)
          .select()
          .single();
      return _toAppUser(authUser, row);
    });
  }

  @override
  Future<Map<String, dynamic>> exportMyData() {
    return guardBackend(() async {
      final authUser = _client.requireUser;

      // Row Level Security means each query only ever returns this user's rows.
      final results = await Future.wait<Object?>([
        _client.from('profiles').select().eq('id', authUser.id).maybeSingle(),
        _client.from('documents').select().order('created_at'),
        _client.from('accounts').select().order('created_at'),
        _client.from('trusted_contacts').select().order('created_at'),
        _client
            .from('security_settings')
            .select()
            .eq('user_id', authUser.id)
            .maybeSingle(),
      ]);

      return {
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'account': {'id': authUser.id, 'email': authUser.email},
        'profile': results[0],
        // File contents aren't included; each document lists its `file_path`.
        'documents': results[1],
        'accounts': results[2],
        'trustedContacts': results[3],
        'securitySettings': results[4],
      };
    });
  }

  @override
  Future<void> deleteAccount() {
    return guardBackend(() async {
      final userId = _client.requireUser.id;

      // Stored files are not removed by deleting the account (the database
      // can't reach Storage), so clear them first. If this fails nothing has
      // been deleted yet and the user can simply retry.
      await _removeFolder(_documentsBucket, userId);
      await _removeFolder(_avatarsBucket, userId);

      // Deletes the login and, by cascade, every row the user owns. It acts only
      // on the caller — the id comes from their session, not an argument.
      await _client.rpc('delete_my_account');

      // The server session is gone with the account; clear this device's copy.
      try {
        await _client.auth.signOut();
      } on Exception catch (_) {
        // Already invalid; the local session is cleared regardless.
      }
    });
  }

  /// Removes every file under [folder] in [bucket], including sub-folders.
  ///
  /// Throws if any file could not actually be removed. Storage answers a
  /// forbidden or failed delete with an *empty* success rather than an error, so
  /// the result is checked: otherwise the account would be deleted with files
  /// still left behind, and this loop would keep re-listing the same files.
  Future<void> _removeFolder(String bucket, String folder) async {
    final files = _client.storage.from(bucket);

    // A page holds up to 1000 files; this bound is far beyond any real vault and
    // only guards against looping forever.
    for (var page = 0; page < 200; page++) {
      final entries = await files.list(
        path: folder,
        searchOptions: const supa.SearchOptions(limit: 1000),
      );
      if (entries.isEmpty) return;

      // Folders come back without an id; files have one.
      final filePaths = <String>[];
      final subFolders = <String>[];
      for (final entry in entries) {
        (entry.id == null ? subFolders : filePaths).add('$folder/${entry.name}');
      }

      if (filePaths.isNotEmpty) {
        final removed = await files.remove(filePaths);
        if (removed.length < filePaths.length) {
          throw const BackendException(
            'Some of your files couldn\'t be removed, so your account was not '
            'deleted. Please try again.',
          );
        }
      }
      for (final sub in subFolders) {
        await _removeFolder(bucket, sub);
      }

      // Nothing but folders (now emptied) means we're finished; otherwise go
      // round again in case there were more files than one page holds.
      if (filePaths.isEmpty) return;
    }

    throw const BackendException(
      'Your account has too many files to delete in one go. Please try again.',
    );
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
      emailVerified: authUser.emailConfirmedAt != null,
    );
  }
}

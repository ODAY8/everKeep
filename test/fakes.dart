import 'dart:async';

import 'package:everkeep/models/account_item.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/security_settings.dart';
import 'package:everkeep/models/trusted_contact_item.dart';
import 'package:everkeep/models/user.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/repositories/account_repository.dart';
import 'package:everkeep/repositories/auth_repository.dart';
import 'package:everkeep/repositories/document_repository.dart';
import 'package:everkeep/repositories/settings_repository.dart';
import 'package:everkeep/repositories/trusted_contact_repository.dart';
import 'package:everkeep/repositories/user_repository.dart';
import 'package:everkeep/repositories/vault_repository.dart';
import 'package:flutter/material.dart';

/// A signed-in user for tests. (The app has no built-in persona: real users
/// come from Supabase.)
const User testUser = User(
  id: 'user-001',
  name: 'Sarah Mitchell',
  email: 'sarah.mitchell@example.com',
  phone: '+1 (555) 123-4567',
  isAuthenticated: true,
);

/// Fake repositories that resolve instantly and can be told to fail, so tests
/// can exercise the error paths without a backend.
mixin Failable {
  /// While non-null, every call throws `Exception(failWith)`.
  String? failWith;

  void throwIfFailing() {
    if (failWith != null) throw Exception(failWith);
  }
}

class FakeAuthRepository with Failable implements AuthRepository {
  User? sessionUser;
  bool failSignOut = false;
  bool failRestore = false;

  /// When true, sign-up creates the account but returns no session (the
  /// "confirm your email first" case).
  bool signUpNeedsConfirmation = false;

  final StreamController<void> _sessionEnded = StreamController<void>.broadcast();

  /// Simulates the backend ending the session (expiry, revocation, sign-out
  /// on another device).
  void endSession() {
    sessionUser = null;
    _sessionEnded.add(null);
  }

  @override
  Stream<void> get sessionEnded => _sessionEnded.stream;

  @override
  Future<User?> signIn({required String email, required String password}) async {
    throwIfFailing();
    return sessionUser = testUser.copyWith(email: email);
  }

  @override
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    throwIfFailing();
    if (signUpNeedsConfirmation) return null;
    return sessionUser = testUser.copyWith(name: name, email: email);
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw Exception('Network unavailable');
    sessionUser = null;
  }

  @override
  Future<bool> sendPasswordReset({required String email}) async => true;

  @override
  Future<User?> restoreSession() async {
    if (failRestore) throw Exception('Token check failed');
    return sessionUser;
  }
}

class FakeDocumentRepository with Failable implements DocumentRepository {
  final List<DocumentItem> items;

  /// When set, the next fetch waits on this instead of resolving.
  Completer<List<DocumentItem>>? pendingFetch;

  /// The upload passed to the most recent [addDocument], if any.
  DocumentUpload? lastUpload;

  int _nextId = 100;

  FakeDocumentRepository([List<DocumentItem>? seed])
      : items = seed ?? [doc('d1', 'Will.pdf'), doc('d2', 'Deed.pdf'), doc('d3', 'Tax.pdf')];

  static DocumentItem doc(String id, String title, {String category = 'Legal'}) =>
      DocumentItem(
        id: id,
        title: title,
        subtitle: '$category · Added today',
        category: category,
      );

  @override
  Future<List<DocumentItem>> fetchDocuments() {
    if (pendingFetch != null) return pendingFetch!.future;
    throwIfFailing();
    return Future.value(List.of(items));
  }

  @override
  Future<DocumentItem> addDocument(
    DocumentItem document, {
    DocumentUpload? upload,
  }) async {
    throwIfFailing();
    lastUpload = upload;
    // Like the backend, assign the id (a caller's id is ignored) and subtitle.
    final saved = document.copyWith(
      id: document.id.isEmpty ? 'gen-${_nextId++}' : document.id,
      subtitle: document.subtitle.isEmpty
          ? '${document.category} · Added just now'
          : document.subtitle,
    );
    items.insert(0, saved);
    return saved;
  }

  @override
  Future<void> deleteDocument(String id) async {
    throwIfFailing();
    items.removeWhere((d) => d.id == id);
  }

  @override
  Future<String> createDownloadUrl(String filePath) async {
    throwIfFailing();
    return 'https://example.test/signed/$filePath';
  }
}

class FakeAccountRepository with Failable implements AccountRepository {
  final List<AccountItem> items;

  /// When set, the next favorite change waits on this instead of resolving.
  Completer<void>? pendingToggle;

  /// The (id, value) of the most recent [setFavorite] call.
  (String, bool)? lastFavorite;

  int _nextId = 100;

  FakeAccountRepository([List<AccountItem>? seed])
      : items = seed ?? [account('a1', 'Bank'), account('a2', 'GitHub')];

  static AccountItem account(String id, String title, {bool favorite = false}) =>
      AccountItem(
        id: id,
        title: title,
        subtitle: 'Added today',
        icon: Icons.key_rounded,
        color: Colors.blue,
        isFavorite: favorite,
      );

  @override
  Future<List<AccountItem>> fetchAccounts() async {
    throwIfFailing();
    return List.of(items);
  }

  @override
  Future<AccountItem> addAccount(AccountItem item) async {
    throwIfFailing();
    final saved = item.copyWith(
      id: item.id.isEmpty ? 'gen-${_nextId++}' : item.id,
      subtitle: item.subtitle.isEmpty ? 'Added just now' : item.subtitle,
    );
    items.insert(0, saved);
    return saved;
  }

  @override
  Future<AccountItem> updateAccount(AccountItem item) async {
    throwIfFailing();
    final index = items.indexWhere((a) => a.id == item.id);
    if (index == -1) throw Exception('That item couldn\'t be found.');
    return items[index] = item;
  }

  @override
  Future<void> setFavorite(String id, bool isFavorite) {
    lastFavorite = (id, isFavorite);
    final pending = pendingToggle;
    if (pending != null) {
      pendingToggle = null;
      return pending.future;
    }
    throwIfFailing();
    return Future.value();
  }

  @override
  Future<void> deleteAccount(String id) async {
    throwIfFailing();
    items.removeWhere((a) => a.id == id);
  }
}

class FakeTrustedContactRepository
    with Failable
    implements TrustedContactRepository {
  final List<TrustedContactItem> items;

  int _nextId = 100;

  FakeTrustedContactRepository([List<TrustedContactItem>? seed])
      : items = seed ??
            [
              const TrustedContactItem(
                id: 'tc-a',
                name: 'Ada Lovelace',
                relationship: 'Sibling',
                accessLevel: 'View Only',
                avatarUrl: '',
              ),
              const TrustedContactItem(
                id: 'tc-b',
                name: 'Grace Hopper',
                relationship: 'Attorney',
                accessLevel: 'On Release',
                avatarUrl: '',
              ),
            ];

  @override
  Future<List<TrustedContactItem>> fetchContacts() async {
    throwIfFailing();
    return List.of(items);
  }

  @override
  Future<TrustedContactItem> addContact(TrustedContactItem contact) async {
    throwIfFailing();
    final saved = contact.id.isEmpty
        ? contact.copyWith(id: 'gen-${_nextId++}')
        : contact;
    items.add(saved);
    return saved;
  }

  @override
  Future<void> removeContact(String id) async {
    throwIfFailing();
    items.removeWhere((c) => c.id == id);
  }
}

class FakeSettingsRepository with Failable implements SettingsRepository {
  SecuritySettings stored = const SecuritySettings();

  /// When set, the next save waits on this instead of resolving.
  Completer<void>? holdNextUpdate;

  @override
  Future<SecuritySettings> fetchSecuritySettings() async {
    throwIfFailing();
    return stored;
  }

  @override
  Future<void> updateSecuritySettings(SecuritySettings settings) {
    final held = holdNextUpdate;
    if (held != null) {
      holdNextUpdate = null;
      return held.future;
    }
    throwIfFailing();
    stored = settings;
    return Future.value();
  }
}

class FakeVaultRepository with Failable implements VaultRepository {
  /// Explicit numbers (the model's own defaults describe an empty vault), so
  /// tests can check how live counts are layered on top.
  static const VaultSummary sample = VaultSummary(
    totalItems: 92,
    passwordsCount: 24,
    documentsCount: 11,
    financialsCount: 6,
    messagesCount: 8,
    memoriesCount: 43,
    securityScore: 94,
    securityScoreLabel: 'Excellent — 94/100',
    legacyProgress: 0.73,
    storageUsedMb: 24.5,
  );

  @override
  Future<VaultSummary> fetchVaultSummary() async {
    throwIfFailing();
    return sample;
  }
}

class FakeUserRepository with Failable implements UserRepository {
  /// When given, the profile is that of whoever is signed in there (as the
  /// real backend derives it from the session); otherwise [testUser].
  final FakeAuthRepository? auth;

  FakeUserRepository([this.auth]);

  @override
  Future<User> fetchUserProfile() async {
    throwIfFailing();
    return auth?.sessionUser ?? testUser;
  }

  @override
  Future<User> updateUserProfile(User user) async {
    throwIfFailing();
    return user;
  }
}

import 'dart:async';

import 'package:everkeep/models/account_item.dart';
import 'package:everkeep/models/document_item.dart';
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

/// Fake repositories that resolve instantly and can be told to fail, so tests
/// can exercise the error paths the real mock services never hit.
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

  @override
  Future<User?> signIn({required String email, required String password}) async {
    throwIfFailing();
    return sessionUser = User.defaultUser.copyWith(email: email);
  }

  @override
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    throwIfFailing();
    return sessionUser = User.defaultUser.copyWith(name: name, email: email);
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
  Future<DocumentItem> addDocument(DocumentItem document) async {
    throwIfFailing();
    items.insert(0, document);
    return document;
  }

  @override
  Future<void> deleteDocument(String id) async {
    throwIfFailing();
    items.removeWhere((d) => d.id == id);
  }
}

class FakeAccountRepository with Failable implements AccountRepository {
  final List<AccountItem> items;

  /// When set, the next toggle waits on this instead of resolving.
  Completer<void>? pendingToggle;

  FakeAccountRepository([List<AccountItem>? seed])
      : items = seed ?? [account('a1', 'Bank'), account('a2', 'GitHub')];

  static AccountItem account(String id, String title, {bool favorite = false}) =>
      AccountItem(
        id: id,
        title: title,
        subtitle: 'Updated today',
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
    items.insert(0, item);
    return item;
  }

  @override
  Future<void> toggleFavorite(String id) {
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
    items.add(contact);
    return contact;
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
  @override
  Future<VaultSummary> fetchVaultSummary() async {
    throwIfFailing();
    return const VaultSummary();
  }
}

class FakeUserRepository with Failable implements UserRepository {
  @override
  Future<User> fetchUserProfile() async {
    throwIfFailing();
    return User.defaultUser;
  }

  @override
  Future<User> updateUserProfile(User user) async {
    throwIfFailing();
    return user;
  }
}

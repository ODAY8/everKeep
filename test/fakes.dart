import 'dart:async';

import 'package:everkeep/models/account_item.dart';
import 'package:everkeep/models/document_item.dart';
import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/memory_item.dart';
import 'package:everkeep/models/memory_media_item.dart';
import 'package:everkeep/models/security_settings.dart';
import 'package:everkeep/models/trusted_contact_item.dart';
import 'package:everkeep/models/user.dart';
import 'package:everkeep/models/vault_summary.dart';
import 'package:everkeep/repositories/account_repository.dart';
import 'package:everkeep/repositories/auth_repository.dart';
import 'package:everkeep/repositories/document_repository.dart';
import 'package:everkeep/repositories/memory_repository.dart';
import 'package:everkeep/repositories/settings_repository.dart';
import 'package:everkeep/repositories/trusted_contact_repository.dart';
import 'package:everkeep/repositories/user_repository.dart';
import 'package:everkeep/repositories/vault_repository.dart';
import 'package:everkeep/services/auth_service.dart' show AuthSessionEvent;
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

  /// What the last calls were asked to do, for assertions.
  String? lastPassword;
  String? lastEmailChange;
  int signOutEverywhereCalls = 0;

  final StreamController<AuthSessionEvent> _events =
      StreamController<AuthSessionEvent>.broadcast();

  /// Simulates the backend ending the session (expiry, revocation, sign-out
  /// on another device).
  void endSession() {
    sessionUser = null;
    _events.add(AuthSessionEvent.signedOut);
  }

  /// Simulates a session beginning on its own, e.g. via the link in a
  /// confirmation email.
  void startSessionFromLink(User user) {
    sessionUser = user;
    _events.add(AuthSessionEvent.signedIn);
  }

  /// Simulates opening a password-reset link.
  void openRecoveryLink() => _events.add(AuthSessionEvent.passwordRecovery);

  @override
  Stream<AuthSessionEvent> get events => _events.stream;

  @override
  Future<void> updatePassword(String newPassword) async {
    throwIfFailing();
    lastPassword = newPassword;
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    throwIfFailing();
    lastEmailChange = newEmail;
  }

  @override
  Future<void> signOutEverywhere() async {
    signOutEverywhereCalls++;
    throwIfFailing();
    sessionUser = null;
  }

  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
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
    : items =
          seed ??
          [doc('d1', 'Will.pdf'), doc('d2', 'Deed.pdf'), doc('d3', 'Tax.pdf')];

  static DocumentItem doc(
    String id,
    String title, {
    String category = 'Legal',
  }) => DocumentItem(
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
  Future<DocumentItem> updateDocument(DocumentItem document) async {
    throwIfFailing();
    final index = items.indexWhere((d) => d.id == document.id);
    if (index != -1) {
      items[index] = document;
    }
    return document;
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

class FakeMemoryRepository with Failable implements MemoryRepository {
  final List<MemoryItem> items;

  /// The upload passed to the most recent [createMemory] or
  /// [uploadAttachment], if any.
  DocumentUpload? lastUpload;

  int _nextId = 100;

  FakeMemoryRepository([List<MemoryItem>? seed])
    : items =
          seed ??
          [
            memory('m1', 'Summer at the lake', type: 'memory'),
            memory('m2', 'For my daughter', type: 'wish'),
          ];

  static MemoryItem memory(
    String id,
    String title, {
    String type = 'memory',
    String? filePath,
  }) => MemoryItem(
    id: id,
    title: title,
    content: 'Some notes about $title.',
    type: type,
    filePath: filePath,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  );

  @override
  Future<List<MemoryItem>> fetchMemories() async {
    throwIfFailing();
    return List.of(items);
  }

  @override
  Future<MemoryItem> fetchMemory(String id) async {
    throwIfFailing();
    return items.firstWhere(
      (m) => m.id == id,
      orElse: () => throw Exception('That item couldn\'t be found.'),
    );
  }

  @override
  Future<MemoryItem> createMemory(
    MemoryItem item, {
    DocumentUpload? upload,
  }) async {
    throwIfFailing();
    lastUpload = upload;
    // Like the backend, assign the id; a file upload fills in the storage
    // columns.
    final saved = item.copyWith(
      id: item.id.isEmpty ? 'gen-${_nextId++}' : item.id,
      filePath: upload != null ? 'user/memories/${upload.fileName}' : item.filePath,
      fileSize: upload != null ? upload.bytes.length : item.fileSize,
      mimeType: upload?.mimeType ?? item.mimeType,
      createdAt: DateTime.now(),
    );
    items.insert(0, saved);
    return saved;
  }

  @override
  Future<MemoryItem> updateMemory(MemoryItem item) async {
    throwIfFailing();
    final index = items.indexWhere((m) => m.id == item.id);
    if (index == -1) throw Exception('That item couldn\'t be found.');
    return items[index] = item;
  }

  @override
  Future<void> deleteMemory(String id) async {
    throwIfFailing();
    items.removeWhere((m) => m.id == id);
  }

  @override
  Future<MemoryItem> uploadAttachment(String id, DocumentUpload upload) async {
    throwIfFailing();
    lastUpload = upload;
    final index = items.indexWhere((m) => m.id == id);
    if (index == -1) throw Exception('That item couldn\'t be found.');
    final saved = items[index].copyWith(
      filePath: 'user/memories/${upload.fileName}',
      fileSize: upload.bytes.length,
      mimeType: upload.mimeType,
    );
    return items[index] = saved;
  }

  @override
  Future<MemoryItem> deleteAttachment(String id) async {
    throwIfFailing();
    final index = items.indexWhere((m) => m.id == id);
    if (index == -1) throw Exception('That item couldn\'t be found.');
    final current = items[index];
    // copyWith can't null a field out, so rebuild without the attachment.
    final saved = MemoryItem(
      id: current.id,
      title: current.title,
      content: current.content,
      type: current.type,
      date: current.date,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
    return items[index] = saved;
  }

  @override
  Future<String> createDownloadUrl(String filePath) async {
    throwIfFailing();
    return 'https://example.test/signed/$filePath';
  }

  @override
  Future<String> createSignedUrl(String filePath) async {
    return createDownloadUrl(filePath);
  }

  @override
  Future<MemoryItem> createMemoryWithMedia(
    MemoryItem item,
    List<DocumentUpload> uploads, {
    List<String>? captions,
    List<int?>? durations,
  }) async {
    throwIfFailing();
    final memoryId = item.id.isEmpty ? 'gen-${_nextId++}' : item.id;
    final mediaList = <MemoryMediaItem>[];
    for (var i = 0; i < uploads.length; i++) {
      final upload = uploads[i];
      final mediaType = MemoryMediaItem.fromLegacy(
        filePath: 'user/memories/$memoryId/${upload.fileName}',
        fileSize: upload.bytes.length,
        mimeType: upload.mimeType,
      ).mediaType;

      mediaList.add(MemoryMediaItem(
        id: 'med-$memoryId-$i',
        memoryId: memoryId,
        filePath: 'user/memories/$memoryId/${upload.fileName}',
        mediaType: mediaType,
        mimeType: upload.mimeType ?? 'application/octet-stream',
        fileSize: upload.bytes.length,
        displayOrder: i,
        caption: (captions != null && i < captions.length) ? captions[i] : null,
        durationSeconds: (durations != null && i < durations.length) ? durations[i] : null,
        createdAt: DateTime.now(),
      ));
    }

    final saved = item.copyWith(
      id: memoryId,
      media: mediaList,
      createdAt: DateTime.now(),
    );
    items.insert(0, saved);
    return saved;
  }

  @override
  Future<MemoryMediaItem> addMedia(
    String memoryId,
    DocumentUpload upload, {
    String? caption,
    int? displayOrder,
    int? durationSeconds,
  }) async {
    throwIfFailing();
    final index = items.indexWhere((m) => m.id == memoryId);
    if (index == -1) throw Exception('That item couldn\'t be found.');

    final mediaType = MemoryMediaItem.fromLegacy(
      filePath: 'user/memories/$memoryId/${upload.fileName}',
      fileSize: upload.bytes.length,
      mimeType: upload.mimeType,
    ).mediaType;

    final mediaItem = MemoryMediaItem(
      id: 'med-$memoryId-${DateTime.now().millisecondsSinceEpoch}',
      memoryId: memoryId,
      filePath: 'user/memories/$memoryId/${upload.fileName}',
      mediaType: mediaType,
      mimeType: upload.mimeType ?? 'application/octet-stream',
      fileSize: upload.bytes.length,
      displayOrder: displayOrder ?? items[index].media.length,
      caption: caption,
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
    );

    final updatedMedia = List<MemoryMediaItem>.from(items[index].media)..add(mediaItem);
    items[index] = items[index].copyWith(media: updatedMedia);
    return mediaItem;
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    throwIfFailing();
    for (var i = 0; i < items.length; i++) {
      if (items[i].media.any((m) => m.id == mediaId)) {
        final updated = items[i].media.where((m) => m.id != mediaId).toList();
        items[i] = items[i].copyWith(media: updated);
        return;
      }
    }
  }

  @override
  Future<void> reorderMedia(
    String memoryId,
    List<String> orderedMediaIds,
  ) async {
    throwIfFailing();
    final index = items.indexWhere((m) => m.id == memoryId);
    if (index == -1) throw Exception('That item couldn\'t be found.');

    final existing = {for (final m in items[index].media) m.id: m};
    final reordered = <MemoryMediaItem>[];
    for (var i = 0; i < orderedMediaIds.length; i++) {
      final item = existing[orderedMediaIds[i]];
      if (item != null) {
        reordered.add(item.copyWith(displayOrder: i));
      }
    }
    items[index] = items[index].copyWith(media: reordered);
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

  static AccountItem account(
    String id,
    String title, {
    bool favorite = false,
  }) => AccountItem(
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
    : items =
          seed ??
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
  Future<TrustedContactItem> updateContact(TrustedContactItem contact) async {
    throwIfFailing();
    final index = items.indexWhere((c) => c.id == contact.id);
    if (index == -1) throw Exception('That item couldn\'t be found.');
    return items[index] = contact;
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
  static final VaultSummary sample = VaultSummary(
    totalItems: 92,
    passwordsCount: 24,
    documentsCount: 11,
    financialsCount: 6,
    messagesCount: 8,
    memoriesCount: 43,
    trustedContactsCount: 2,
    emailVerified: true,
    storageUsedMb: 24.5,
  ).withDerived();

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

  DocumentUpload? lastAvatar;
  bool avatarRemoved = false;
  bool accountDeleted = false;
  Map<String, dynamic> exportPayload = {
    'account': {'email': 'sarah.mitchell@example.com'},
    'documents': [],
  };

  @override
  Future<User> uploadAvatar(User user, DocumentUpload photo) async {
    throwIfFailing();
    lastAvatar = photo;
    return user.copyWith(avatarUrl: 'https://example.test/avatar.png?v=1');
  }

  @override
  Future<User> removeAvatar(User user) async {
    throwIfFailing();
    avatarRemoved = true;
    return User(
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      isAuthenticated: user.isAuthenticated,
      emailVerified: user.emailVerified,
    );
  }

  @override
  Future<Map<String, dynamic>> exportMyData() async {
    throwIfFailing();
    return exportPayload;
  }

  @override
  Future<void> deleteAccount() async {
    throwIfFailing();
    accountDeleted = true;
  }
}

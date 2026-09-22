import 'dart:convert';
import 'dart:typed_data';

import 'package:everkeep/models/document_upload.dart';
import 'package:everkeep/models/user.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// The account-management behaviour of the providers: password/email changes,
/// reset links, signing out everywhere, the profile photo, export and delete.
void main() {
  group('AuthProvider: account management', () {
    late FakeAuthRepository repo;
    late AuthProvider auth;

    setUp(() {
      repo = FakeAuthRepository();
      auth = AuthProvider(authRepository: repo);
    });

    tearDown(() => auth.dispose());

    test('updatePassword saves the new password', () async {
      expect(await auth.updatePassword('brand-new-1'), isTrue);
      expect(repo.lastPassword, 'brand-new-1');
      expect(auth.error, isNull);
    });

    test('a rejected password change reports why and is not a success', () async {
      repo.failWith = 'Choose a password you haven\'t used before.';

      expect(await auth.updatePassword('old-password'), isFalse);
      expect(auth.error, 'Choose a password you haven\'t used before.');
    });

    test('updateEmail says the change waits for the emailed link', () async {
      expect(await auth.updateEmail('new@example.com'), isTrue);

      expect(repo.lastEmailChange, 'new@example.com');
      expect(auth.notice, contains('new@example.com'));
      expect(auth.notice, contains('once you open it'));
    });

    test('a failed email change gives no notice and sets the error', () async {
      repo.failWith = 'That email is already registered.';

      expect(await auth.updateEmail('taken@example.com'), isFalse);
      expect(auth.notice, isNull);
      expect(auth.error, 'That email is already registered.');
    });

    test('opening a reset link marks a recovery as pending until a password is set',
        () async {
      expect(auth.recoveryPending, isFalse);

      repo.openRecoveryLink();
      await pumpEventQueue();
      expect(auth.recoveryPending, isTrue);

      expect(await auth.updatePassword('brand-new-1'), isTrue);
      expect(auth.recoveryPending, isFalse);
    });

    test('a recovery can be abandoned', () async {
      repo.openRecoveryLink();
      await pumpEventQueue();

      auth.dismissRecovery();
      expect(auth.recoveryPending, isFalse);
    });

    test('a failed password change during recovery keeps the recovery open', () async {
      repo.openRecoveryLink();
      await pumpEventQueue();
      repo.failWith = 'Too weak.';

      expect(await auth.updatePassword('x'), isFalse);
      expect(auth.recoveryPending, isTrue);
    });

    test('a session that ends clears any pending recovery', () async {
      await auth.signIn(email: 'a@b.co', password: 'secret1');
      repo.openRecoveryLink();
      await pumpEventQueue();

      repo.endSession();
      await pumpEventQueue();

      expect(auth.recoveryPending, isFalse);
      expect(auth.isAuthenticated, isFalse);
    });

    test('a session that starts from an emailed link is adopted', () async {
      expect(auth.isAuthenticated, isFalse);

      repo.startSessionFromLink(testUser);
      await pumpEventQueue();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.email, testUser.email);
    });

    test('signing in ourselves is not adopted twice', () async {
      var restores = 0;
      final counting = _CountingAuth(onRestore: () => restores++);
      final provider = AuthProvider(authRepository: counting);
      addTearDown(provider.dispose);

      await provider.signIn(email: 'a@b.co', password: 'secret1');
      await pumpEventQueue();

      expect(restores, 0, reason: 'the sign-in event of our own call is ignored');
    });

    test('signOutEverywhere reaches the backend once', () async {
      await auth.signIn(email: 'a@b.co', password: 'secret1');

      expect(await auth.signOutEverywhere(), isTrue);
      expect(repo.signOutEverywhereCalls, 1);
    });

    test('if other devices could not be reached, the error says so', () async {
      repo.failWith = 'We couldn\'t reach your other devices.';

      expect(await auth.signOutEverywhere(), isFalse);
      expect(auth.error, 'We couldn\'t reach your other devices.');
    });

    test('signing up when the email must be confirmed is a notice, not an error', () async {
      repo.signUpNeedsConfirmation = true;

      final ok = await auth.signUp(name: 'A', email: 'a@b.co', password: 'secret1');

      expect(ok, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.error, isNull);
      expect(auth.notice, contains('Check your email'));
      expect(auth.status, AuthStatus.unauthenticated);
    });

    test('clearError also clears the notice', () async {
      repo.signUpNeedsConfirmation = true;
      await auth.signUp(name: 'A', email: 'a@b.co', password: 'secret1');
      expect(auth.notice, isNotNull);

      auth.clearError();
      expect(auth.notice, isNull);
    });
  });

  group('UserProvider: photo, export and deletion', () {
    late FakeUserRepository repo;
    late UserProvider user;

    final photo = DocumentUpload(
      fileName: 'avatar.png',
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/png',
    );

    setUp(() {
      repo = FakeUserRepository();
      user = UserProvider(userRepository: repo)..setUser(testUser);
    });

    test('uploadAvatar stores the photo and updates the user', () async {
      expect(user.user?.avatarUrl, isNull);

      expect(await user.uploadAvatar(photo), isTrue);

      expect(repo.lastAvatar?.fileName, 'avatar.png');
      expect(user.user?.avatarUrl, startsWith('https://'));
      expect(user.user?.name, testUser.name, reason: 'the rest of the profile is untouched');
    });

    test('a failed upload keeps the old photo and reports why', () async {
      user.setUser(testUser.copyWith(avatarUrl: 'https://example.test/old.png'));
      repo.failWith = 'That photo is too large.';

      expect(await user.uploadAvatar(photo), isFalse);

      expect(user.error, 'That photo is too large.');
      expect(user.user?.avatarUrl, 'https://example.test/old.png');
      expect(user.isLoading, isFalse);
    });

    test('removeAvatar clears the photo', () async {
      user.setUser(testUser.copyWith(avatarUrl: 'https://example.test/old.png'));

      expect(await user.removeAvatar(), isTrue);

      expect(repo.avatarRemoved, isTrue);
      expect(user.user?.avatarUrl, anyOf(isNull, isEmpty));
    });

    test('with nobody signed in there is nothing to change the photo of', () async {
      user.reset();

      expect(await user.uploadAvatar(photo), isFalse);
      expect(await user.removeAvatar(), isFalse);
      expect(repo.lastAvatar, isNull);
      expect(repo.avatarRemoved, isFalse);
    });

    test('exportData returns readable JSON of what the account holds', () async {
      final text = await user.exportData();

      expect(text, isNotNull);
      final decoded = jsonDecode(text!) as Map<String, dynamic>;
      expect(decoded['account'], {'email': 'sarah.mitchell@example.com'});
      expect(text, contains('\n'), reason: 'indented, so a person can read it');
    });

    test('a failed export returns nothing and says why', () async {
      repo.failWith = 'Can\'t reach the server.';

      expect(await user.exportData(), isNull);
      expect(user.error, 'Can\'t reach the server.');
    });

    test('deleteAccount succeeds only when the backend did', () async {
      expect(await user.deleteAccount(), isTrue);
      expect(repo.accountDeleted, isTrue);
      expect(user.isLoading, isFalse);
    });

    test('a failed deletion is reported and the account is kept', () async {
      repo.failWith = 'Some of your files couldn\'t be removed.';

      expect(await user.deleteAccount(), isFalse);
      expect(repo.accountDeleted, isFalse);
      expect(user.error, 'Some of your files couldn\'t be removed.');
      expect(user.user, isNotNull, reason: 'still the signed-in user');
      expect(user.isLoading, isFalse);
    });
  });
}

/// Counts how often the provider asks to restore a session.
class _CountingAuth extends FakeAuthRepository {
  final void Function() onRestore;
  _CountingAuth({required this.onRestore});

  @override
  Future<User?> restoreSession() {
    onRestore();
    return super.restoreSession();
  }
}

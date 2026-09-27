import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'package:everkeep/core/security/biometric_auth_service.dart';
import 'package:everkeep/core/security/biometric_lock_storage.dart';
import 'package:everkeep/core/security/vault_crypto_service.dart';
import 'package:everkeep/features/security/presentation/screens/app_lock_screen.dart';
import 'package:everkeep/features/security/presentation/widgets/app_lock_gate.dart';
import 'package:everkeep/features/security/presentation/widgets/biometric_lock_sheet.dart';
import 'package:everkeep/providers/account_provider.dart';
import 'package:everkeep/providers/app_lock_provider.dart';
import 'package:everkeep/providers/auth_provider.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Biometric Lock - Security & Capabilities', () {
    late FakeBiometricAuthService authService;
    late InMemoryBiometricLockStorage storage;
    late AppLockProvider lockProv;

    setUp(() {
      authService = FakeBiometricAuthService();
      storage = InMemoryBiometricLockStorage();
      lockProv = AppLockProvider(
        authService: authService,
        storage: storage,
      );
    });

    test('biometric lock is disabled by default', () async {
      await lockProv.initialize();
      expect(lockProv.isEnabled, isFalse);
      expect(lockProv.isLocked, isFalse);
    });

    test('detects biometric capabilities on initialization', () async {
      authService.biometrics = [BiometricType.fingerprint];
      await lockProv.initialize();
      expect(lockProv.biometricName, 'Fingerprint');
      expect(lockProv.biometricIcon, Icons.fingerprint_rounded);
    });

    test('detects face authentication on supported devices', () async {
      authService.biometrics = [BiometricType.face];
      await lockProv.initialize();
      expect(lockProv.biometricName, 'Face ID');
      expect(lockProv.biometricIcon, Icons.face_rounded);
    });

    test('fails to enable if hardware is not supported', () async {
      authService.isSupported = false;
      await lockProv.initialize();

      final success = await lockProv.enableBiometricLock();
      expect(success, isFalse);
      expect(lockProv.isEnabled, isFalse);
      expect(
        lockProv.errorMessage,
        contains('not supported'),
      );
    });

    test('fails to enable if no biometrics are enrolled', () async {
      authService.biometrics = [];
      await lockProv.initialize();

      final success = await lockProv.enableBiometricLock();
      expect(success, isFalse);
      expect(lockProv.isEnabled, isFalse);
      expect(
        lockProv.errorMessage,
        contains('No biometrics are enrolled'),
      );
    });

    test('fails to enable if user authentication fails', () async {
      authService.nextResult = BiometricAuthResult.failure;
      await lockProv.initialize();

      final success = await lockProv.enableBiometricLock();
      expect(success, isFalse);
      expect(lockProv.isEnabled, isFalse);
      expect(lockProv.errorMessage, contains('not recognized'));
    });

    test('fails to enable if user cancels biometric prompt', () async {
      authService.nextResult = BiometricAuthResult.canceled;
      await lockProv.initialize();

      final success = await lockProv.enableBiometricLock();
      expect(success, isFalse);
      expect(lockProv.isEnabled, isFalse);
      expect(lockProv.errorMessage, contains('canceled'));
    });

    test('successfully enables biometric lock after authenticating', () async {
      authService.nextResult = BiometricAuthResult.success;
      await lockProv.initialize();

      final success = await lockProv.enableBiometricLock();
      expect(success, isTrue);
      expect(lockProv.isEnabled, isTrue);
      expect(lockProv.errorMessage, isNull);
      expect(await storage.isBiometricLockEnabled(), isTrue);
    });

    test('requires biometric authentication to disable', () async {
      // First enable
      authService.nextResult = BiometricAuthResult.success;
      await lockProv.initialize();
      await lockProv.enableBiometricLock();
      expect(lockProv.isEnabled, isTrue);

      // Attempt disable with failed auth
      authService.nextResult = BiometricAuthResult.failure;
      final disabledFailed = await lockProv.disableBiometricLock();
      expect(disabledFailed, isFalse);
      expect(lockProv.isEnabled, isTrue);

      // Disable with successful auth
      authService.nextResult = BiometricAuthResult.success;
      final disabledSuccess = await lockProv.disableBiometricLock();
      expect(disabledSuccess, isTrue);
      expect(lockProv.isEnabled, isFalse);
      expect(await storage.isBiometricLockEnabled(), isFalse);
    });

    test('handles OS lockout gracefully', () async {
      authService.nextResult = BiometricAuthResult.lockedOut;
      await lockProv.initialize();

      final success = await lockProv.enableBiometricLock();
      expect(success, isFalse);
      expect(lockProv.errorMessage, contains('temporarily locked'));
    });
  });

  group('Biometric Lock - Lock State & Timeouts', () {
    late FakeBiometricAuthService authService;
    late InMemoryBiometricLockStorage storage;
    late AppLockProvider lockProv;

    setUp(() {
      authService = FakeBiometricAuthService();
      storage = InMemoryBiometricLockStorage();
      lockProv = AppLockProvider(
        authService: authService,
        storage: storage,
      );
    });

    test('fresh launch with enabled lock sets app to locked state', () async {
      storage.enabled = true;
      await lockProv.initialize();

      expect(lockProv.isEnabled, isTrue);
      expect(lockProv.isLocked, isTrue);
    });

    test('fresh launch with disabled lock does not lock app', () async {
      storage.enabled = false;
      await lockProv.initialize();

      expect(lockProv.isEnabled, isFalse);
      expect(lockProv.isLocked, isFalse);
    });

    test('successful unlock clears lock state', () async {
      storage.enabled = true;
      await lockProv.initialize();
      expect(lockProv.isLocked, isTrue);

      authService.nextResult = BiometricAuthResult.success;
      final success = await lockProv.unlock();

      expect(success, isTrue);
      expect(lockProv.isLocked, isFalse);
      expect(lockProv.errorMessage, isNull);
    });

    test('failed unlock keeps app locked with error message', () async {
      storage.enabled = true;
      await lockProv.initialize();

      authService.nextResult = BiometricAuthResult.failure;
      final success = await lockProv.unlock();

      expect(success, isFalse);
      expect(lockProv.isLocked, isTrue);
      expect(lockProv.errorMessage, isNotNull);
    });

    test('canceled unlock keeps app locked', () async {
      storage.enabled = true;
      await lockProv.initialize();

      authService.nextResult = BiometricAuthResult.canceled;
      final success = await lockProv.unlock();

      expect(success, isFalse);
      expect(lockProv.isLocked, isTrue);
    });

    test('app remains unlocked if returning within timeout', () async {
      storage.enabled = true;
      await lockProv.initialize();
      // Unlock first
      authService.nextResult = BiometricAuthResult.success;
      await lockProv.unlock();
      expect(lockProv.isLocked, isFalse);

      // Set timeout to 5 minutes
      await lockProv.setLockTimeout(const Duration(minutes: 5));

      // Background app
      lockProv.onAppBackgrounded();

      // Return immediately
      lockProv.onAppForegrounded();
      expect(lockProv.isLocked, isFalse);
    });

    test('app locks if returning after timeout has elapsed', () async {
      storage.enabled = true;
      await lockProv.initialize();
      authService.nextResult = BiometricAuthResult.success;
      await lockProv.unlock();

      // Set timeout to immediately (Duration.zero)
      await lockProv.setLockTimeout(Duration.zero);

      lockProv.onAppBackgrounded();
      lockProv.onAppForegrounded();

      expect(lockProv.isLocked, isTrue);
    });

    test('explicit manual lock() locks immediately', () async {
      storage.enabled = true;
      await lockProv.initialize();
      authService.nextResult = BiometricAuthResult.success;
      await lockProv.unlock();
      expect(lockProv.isLocked, isFalse);

      lockProv.lock();
      expect(lockProv.isLocked, isTrue);
    });
  });

  group('Biometric Lock - Concurrency & Duplicate Prompt Prevention', () {
    late FakeBiometricAuthService authService;
    late InMemoryBiometricLockStorage storage;
    late AppLockProvider lockProv;

    setUp(() {
      authService = FakeBiometricAuthService();
      storage = InMemoryBiometricLockStorage();
      lockProv = AppLockProvider(
        authService: authService,
        storage: storage,
      );
    });

    test('prevents duplicate concurrent authentication calls', () async {
      storage.enabled = true;
      await lockProv.initialize();

      final firstFuture = lockProv.unlock();
      final secondFuture = lockProv.unlock();

      final results = await Future.wait([firstFuture, secondFuture]);

      // One call should succeed, duplicate call should return false immediately
      expect(results, contains(true));
      expect(results, contains(false));
      expect(authService.authenticateCalls, equals(1));
    });
  });

  group('Biometric Lock - Password Vault Integration', () {
    late FakeBiometricAuthService authService;
    late InMemoryBiometricLockStorage storage;
    late FakeAccountRepository accRepo;
    late InMemoryVaultKeyStorage keyStorage;
    late VaultCryptoService cryptoService;
    late AccountProvider accProv;
    late AppLockProvider lockProv;

    setUp(() async {
      authService = FakeBiometricAuthService();
      storage = InMemoryBiometricLockStorage(enabled: true);
      accRepo = FakeAccountRepository([]);
      keyStorage = InMemoryVaultKeyStorage();
      cryptoService = VaultCryptoService(keyStorage: keyStorage);
      accProv = AccountProvider(
        accountRepository: accRepo,
        cryptoService: cryptoService,
      );
      lockProv = AppLockProvider(
        authService: authService,
        storage: storage,
        accountProvider: accProv,
      );
      await lockProv.initialize();

      // Add a test account with an encrypted password
      await accProv.addCredential(
        title: 'GitHub Enterprise',
        username: 'octocat@github.com',
        website: 'https://github.com',
        password: 'super-secret-password-123',
        category: 'Work',
        userId: testUser.id,
      );
    });

    test('decrypting password caches plaintext in AccountProvider', () async {
      final item = accProv.accounts.first;
      final decrypted = await accProv.getDecryptedPassword(
        item,
        userId: testUser.id,
      );

      expect(decrypted, 'super-secret-password-123');
      expect(
        accProv.getCachedDecryptedPassword(item.id),
        'super-secret-password-123',
      );
    });

    test('locking app clears decrypted password cache while preserving encrypted data', () async {
      final item = accProv.accounts.first;
      await accProv.getDecryptedPassword(item, userId: testUser.id);
      expect(accProv.getCachedDecryptedPassword(item.id), isNotNull);

      // Lock the app
      lockProv.lock();

      // In-memory cache is wiped
      expect(accProv.getCachedDecryptedPassword(item.id), isNull);

      // Encrypted password in repository remains intact
      expect(item.encryptedPassword, isNotNull);
      expect(item.encryptedPassword, isNotEmpty);
      expect(item.encryptedPassword, isNot(equals('super-secret-password-123')));
    });

    test('signing out clears lock state and cache', () async {
      final item = accProv.accounts.first;
      await accProv.getDecryptedPassword(item, userId: testUser.id);
      expect(accProv.getCachedDecryptedPassword(item.id), isNotNull);

      lockProv.onSignOut();

      expect(accProv.getCachedDecryptedPassword(item.id), isNull);
      expect(lockProv.isLocked, isFalse);
    });
  });

  group('Biometric Lock - UI & Widgets', () {
    late FakeBiometricAuthService authService;
    late InMemoryBiometricLockStorage storage;
    late AppLockProvider lockProv;
    late FakeAuthRepository authRepo;
    late AuthProvider authProv;

    setUp(() async {
      authService = FakeBiometricAuthService();
      storage = InMemoryBiometricLockStorage();
      lockProv = AppLockProvider(
        authService: authService,
        storage: storage,
      );
      authRepo = FakeAuthRepository()..sessionUser = testUser;
      authProv = AuthProvider(authRepository: authRepo);
      await authProv.signIn(email: testUser.email, password: 'pw');
    });

    Widget createTestWidget({required Widget child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AppLockProvider>.value(value: lockProv),
          ChangeNotifierProvider<AuthProvider>.value(value: authProv),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('AppLockScreen renders brand emblem, texts, and unlock button', (
      tester,
    ) async {
      storage.enabled = true;
      await lockProv.initialize();

      await tester.pumpWidget(createTestWidget(child: const AppLockScreen()));
      await tester.pumpAndSettle();

      expect(find.text('EverKeep is locked'), findsOneWidget);
      expect(find.text('Unlock to access your secure vault'), findsOneWidget);
      expect(find.text('Unlock with Fingerprint'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('AppLockScreen displays error banner on auth failure', (
      tester,
    ) async {
      storage.enabled = true;
      await lockProv.initialize();

      authService.nextResult = BiometricAuthResult.failure;
      await lockProv.unlock();

      await tester.pumpWidget(createTestWidget(child: const AppLockScreen()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Biometric authentication was not recognized'),
        findsOneWidget,
      );
    });

    testWidgets('AppLockGate shows lock screen when locked and authenticated', (
      tester,
    ) async {
      storage.enabled = true;
      authService.nextResult = BiometricAuthResult.canceled;
      await lockProv.initialize();

      await tester.pumpWidget(
        createTestWidget(
          child: const AppLockGate(
            child: Text('Vault Home Screen Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Lock screen is rendered on top
      expect(find.text('EverKeep is locked'), findsOneWidget);

      // Unlock successfully
      authService.nextResult = BiometricAuthResult.success;
      await lockProv.unlock();
      await tester.pumpAndSettle();

      // Lock screen is gone, underlying content visible
      expect(find.text('EverKeep is locked'), findsNothing);
      expect(find.text('Vault Home Screen Content'), findsOneWidget);
    });

    testWidgets('BiometricLockSheet displays toggle and allows enabling', (
      tester,
    ) async {
      await lockProv.initialize();

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showBiometricLockSheet(ctx),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Biometric Lock'), findsOneWidget);
      expect(find.text('Require Fingerprint'), findsOneWidget);

      // Tap Switch to enable
      authService.nextResult = BiometricAuthResult.success;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(lockProv.isEnabled, isTrue);
      expect(find.text('LOCK TIMEOUT'), findsOneWidget);
      expect(find.text('Immediately'), findsOneWidget);
      expect(find.text('After 1 minute'), findsOneWidget);
      expect(find.text('After 5 minutes'), findsOneWidget);
      expect(find.text('After 15 minutes'), findsOneWidget);
    });
  });

  group('Biometric Lock - Persistence & Re-initialization', () {
    test('setting and timeout survive app restart across new provider instances', () async {
      final storage = InMemoryBiometricLockStorage();
      final authService = FakeBiometricAuthService();

      // First run: user enables biometric lock and sets timeout to 5 minutes
      final firstProvider = AppLockProvider(
        authService: authService,
        storage: storage,
      );
      await firstProvider.initialize();
      final enabled = await firstProvider.enableBiometricLock();
      expect(enabled, isTrue);
      await firstProvider.setLockTimeout(const Duration(minutes: 5));

      // Simulate app kill & relaunch: create fresh provider instance with same storage
      final restartedProvider = AppLockProvider(
        authService: authService,
        storage: storage,
      );
      await restartedProvider.initialize();

      expect(restartedProvider.isEnabled, isTrue);
      expect(restartedProvider.isLocked, isTrue); // Must lock on fresh launch
      expect(restartedProvider.lockTimeout, equals(const Duration(minutes: 5)));
      expect(restartedProvider.lockTimeoutOption, equals(LockTimeoutOption.fiveMinutes));
    });
  });

  group('Biometric Lock - Lifecycle Transitions & Robustness', () {
    test('handles rapid or repeated lifecycle events smoothly', () async {
      final storage = InMemoryBiometricLockStorage(
        enabled: true,
        timeout: const Duration(minutes: 5),
      );
      final authService = FakeBiometricAuthService();
      final provider = AppLockProvider(
        authService: authService,
        storage: storage,
      );
      await provider.initialize();
      await provider.unlock();
      expect(provider.isLocked, isFalse);

      // Rapid paused events without intervening resumed
      provider.onAppBackgrounded();
      provider.onAppBackgrounded();

      // Return immediately
      provider.onAppForegrounded();
      expect(provider.isLocked, isFalse);

      // Repeat foregrounded
      provider.onAppForegrounded();
      expect(provider.isLocked, isFalse);
    });
  });
}


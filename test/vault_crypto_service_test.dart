import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/core/security/vault_crypto_service.dart';

void main() {
  group('VaultCryptoService', () {
    late InMemoryVaultKeyStorage keyStorage;
    late VaultCryptoService cryptoService;

    const testUserId = 'user-abc-123';
    const otherUserId = 'user-xyz-987';

    setUp(() {
      keyStorage = InMemoryVaultKeyStorage();
      cryptoService = VaultCryptoService(keyStorage: keyStorage);
    });

    test('getOrCreateUserKey creates and persists 256-bit key in storage', () async {
      final key1 = await cryptoService.getOrCreateUserKey(testUserId);
      expect(key1.bytes.length, 32);

      final storedBase64 = await keyStorage.readKey(testUserId);
      expect(storedBase64, isNotNull);

      // Second call retrieves identical key
      final key2 = await cryptoService.getOrCreateUserKey(testUserId);
      expect(key2.bytes, equals(key1.bytes));
    });

    test('encrypts plaintext into v1 payload and decrypts back accurately', () async {
      const originalPassword = 'MySecretP@ssword2026!#';

      final encrypted = await cryptoService.encryptPassword(
        originalPassword,
        userId: testUserId,
      );

      expect(encrypted, startsWith('v1:'));
      final parts = encrypted.split(':');
      expect(parts.length, 4); // v1 : iv : ciphertext : mac

      final decrypted = await cryptoService.decryptPassword(
        encrypted,
        userId: testUserId,
      );

      expect(decrypted, equals(originalPassword));
    });

    test('uses unique IV for each encryption of identical plaintext', () async {
      const password = 'SamePasswordTwice';

      final enc1 = await cryptoService.encryptPassword(password, userId: testUserId);
      final enc2 = await cryptoService.encryptPassword(password, userId: testUserId);

      expect(enc1, isNot(equals(enc2)));

      final iv1 = enc1.split(':')[1];
      final iv2 = enc2.split(':')[1];
      expect(iv1, isNot(equals(iv2)));

      expect(await cryptoService.decryptPassword(enc1, userId: testUserId), password);
      expect(await cryptoService.decryptPassword(enc2, userId: testUserId), password);
    });

    test('detects tampered ciphertext with SecurityException', () async {
      const password = 'TamperProofPassword!';
      final encrypted = await cryptoService.encryptPassword(password, userId: testUserId);

      final parts = encrypted.split(':');
      // Tamper ciphertext
      final tamperedCipher = 'A${parts[2].substring(1)}';
      final tamperedPayload = 'v1:${parts[1]}:$tamperedCipher:${parts[3]}';

      expect(
        () => cryptoService.decryptPassword(tamperedPayload, userId: testUserId),
        throwsA(isA<SecurityException>()),
      );
    });

    test('rejects malformed payload with FormatException', () async {
      expect(
        () => cryptoService.decryptPassword('invalid-payload', userId: testUserId),
        throwsA(isA<FormatException>()),
      );
    });

    test('different users have isolated keys and cannot decrypt each other', () async {
      const password = 'UserASecretPassword';
      final encForUserA = await cryptoService.encryptPassword(password, userId: testUserId);

      // User B attempts to decrypt User A's payload
      expect(
        () => cryptoService.decryptPassword(encForUserA, userId: otherUserId),
        throwsA(anyOf(isA<SecurityException>(), isA<ArgumentError>())),
      );
    });

    test('ephemeral cache stores and purges decrypted passwords', () {
      cryptoService.cacheDecryptedPassword('acc-1', 'decryptedSecret');
      expect(cryptoService.getCachedDecryptedPassword('acc-1'), 'decryptedSecret');

      cryptoService.clearCache();
      expect(cryptoService.getCachedDecryptedPassword('acc-1'), isNull);
    });

    test('deleteUserKey removes key from storage and clears cache', () async {
      await cryptoService.getOrCreateUserKey(testUserId);
      cryptoService.cacheDecryptedPassword('acc-1', 'password');

      await cryptoService.deleteUserKey(testUserId);
      expect(await keyStorage.readKey(testUserId), isNull);
      expect(cryptoService.getCachedDecryptedPassword('acc-1'), isNull);
    });
  });
}

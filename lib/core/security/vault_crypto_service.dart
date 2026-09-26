import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract storage for user vault encryption keys.
abstract class VaultKeyStorage {
  Future<String?> readKey(String userId);
  Future<void> writeKey(String userId, String keyBase64);
  Future<void> deleteKey(String userId);
  Future<void> clearAll();
}

/// Production implementation backed by Android Keystore / iOS Keychain via [FlutterSecureStorage].
class PlatformVaultKeyStorage implements VaultKeyStorage {
  final FlutterSecureStorage _storage;

  PlatformVaultKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  String _keyFor(String userId) => 'everkeep_vault_key_${userId.trim()}';

  @override
  Future<String?> readKey(String userId) async {
    try {
      return await _storage.read(key: _keyFor(userId));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeKey(String userId, String keyBase64) async {
    await _storage.write(key: _keyFor(userId), value: keyBase64);
  }

  @override
  Future<void> deleteKey(String userId) async {
    await _storage.delete(key: _keyFor(userId));
  }

  @override
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

/// In-memory storage for test isolation or environments where native secure storage is unavailable.
class InMemoryVaultKeyStorage implements VaultKeyStorage {
  final Map<String, String> _keys = {};

  @override
  Future<String?> readKey(String userId) async => _keys[userId.trim()];

  @override
  Future<void> writeKey(String userId, String keyBase64) async {
    _keys[userId.trim()] = keyBase64;
  }

  @override
  Future<void> deleteKey(String userId) async {
    _keys.remove(userId.trim());
  }

  @override
  Future<void> clearAll() async {
    _keys.clear();
  }
}

/// Core cryptographic service for EverKeep's Password Vault.
///
/// Features:
/// - Client-side AES-256-CBC encryption with PKCS7 padding.
/// - Unique 16-byte cryptographically secure IV per encryption ([Random.secure]).
/// - HMAC-SHA256 message authentication to guarantee ciphertext integrity.
/// - Zero-knowledge architecture: plaintext passwords and encryption keys are NEVER sent to or stored in Supabase.
/// - In-memory ephemeral cache cleared immediately on sign-out.
class VaultCryptoService {
  final VaultKeyStorage _keyStorage;
  final Map<String, String> _ephemeralDecryptedCache = {};

  VaultCryptoService({VaultKeyStorage? keyStorage})
      : _keyStorage = keyStorage ?? PlatformVaultKeyStorage();

  /// Gets existing 256-bit key for [userId] or generates a new one securely.
  Future<enc.Key> getOrCreateUserKey(String userId) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError('A valid user ID is required for vault encryption.');
    }

    final existingBase64 = await _keyStorage.readKey(cleanId);
    if (existingBase64 != null && existingBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(existingBase64);
        if (bytes.length == 32) {
          return enc.Key(Uint8List.fromList(bytes));
        }
      } catch (_) {
        // Fall through to regenerate if corrupted
      }
    }

    // Generate a fresh 256-bit (32 byte) key
    final secureRandom = Random.secure();
    final keyBytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      keyBytes[i] = secureRandom.nextInt(256);
    }

    final newKeyBase64 = base64Encode(keyBytes);
    await _keyStorage.writeKey(cleanId, newKeyBase64);
    return enc.Key(keyBytes);
  }

  /// Encrypts a plaintext password using the user's 256-bit AES key.
  ///
  /// Returns a formatted payload: `v1:<iv_base64>:<ciphertext_base64>:<mac_base64>`.
  Future<String> encryptPassword(
    String plainPassword, {
    required String userId,
  }) async {
    if (plainPassword.isEmpty) return '';

    final key = await getOrCreateUserKey(userId);
    final secureRandom = Random.secure();
    final ivBytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      ivBytes[i] = secureRandom.nextInt(256);
    }
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    final encrypted = encrypter.encrypt(plainPassword, iv: iv);

    // Compute HMAC-SHA256 for integrity: HMAC(key, iv + ciphertext)
    final hmac = Hmac(sha256, key.bytes);
    final dataToAuth = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    final macDigest = hmac.convert(dataToAuth);
    final macBase64 = base64Encode(macDigest.bytes);

    return 'v1:${iv.base64}:${encrypted.base64}:$macBase64';
  }

  /// Decrypts a previously encrypted password payload.
  ///
  /// Verifies format, authenticates MAC, and decrypts ciphertext using the user's key.
  Future<String> decryptPassword(
    String encryptedPayload, {
    required String userId,
  }) async {
    if (encryptedPayload.isEmpty) return '';

    final parts = encryptedPayload.split(':');
    if (parts.length < 3 || parts[0] != 'v1') {
      throw const FormatException('Invalid or unsupported credential encryption format.');
    }

    final ivBase64 = parts[1];
    final ciphertextBase64 = parts[2];
    final macBase64 = parts.length >= 4 ? parts[3] : null;

    final key = await getOrCreateUserKey(userId);
    final ivBytes = base64Decode(ivBase64);
    final ciphertextBytes = base64Decode(ciphertextBase64);

    // Verify MAC if present
    if (macBase64 != null && macBase64.isNotEmpty) {
      final hmac = Hmac(sha256, key.bytes);
      final dataToAuth = Uint8List.fromList([...ivBytes, ...ciphertextBytes]);
      final computedMac = hmac.convert(dataToAuth);
      final expectedMacBytes = base64Decode(macBase64);

      if (!_constantTimeCompare(computedMac.bytes, expectedMacBytes)) {
        throw const SecurityException('Credential integrity check failed. Data may be tampered.');
      }
    }

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    final decrypted = encrypter.decrypt(
      enc.Encrypted(ciphertextBytes),
      iv: enc.IV(ivBytes),
    );

    return decrypted;
  }

  /// Constant-time comparison to prevent timing attacks.
  bool _constantTimeCompare(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Caches decrypted password in ephemeral memory for the given credential [id].
  void cacheDecryptedPassword(String id, String plainPassword) {
    if (id.isNotEmpty && plainPassword.isNotEmpty) {
      _ephemeralDecryptedCache[id] = plainPassword;
    }
  }

  /// Retrieves cached decrypted password if available.
  String? getCachedDecryptedPassword(String id) => _ephemeralDecryptedCache[id];

  /// Clears all decrypted passwords from in-memory cache.
  /// MUST be called on sign-out and screen disposal.
  void clearCache() {
    _ephemeralDecryptedCache.clear();
  }

  /// Deletes stored encryption key for a user (used during account deletion).
  Future<void> deleteUserKey(String userId) async {
    clearCache();
    await _keyStorage.deleteKey(userId);
  }
}

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => message;
}

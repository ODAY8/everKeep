import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage contract for Biometric Lock user preferences.
abstract class BiometricLockStorage {
  Future<bool> isBiometricLockEnabled();
  Future<void> setBiometricLockEnabled(bool enabled);
  Future<Duration> getLockTimeout();
  Future<void> setLockTimeout(Duration timeout);
  Future<void> clear();
}

/// Hardware-backed secure storage implementation using [FlutterSecureStorage].
class PlatformBiometricLockStorage implements BiometricLockStorage {
  static const String _enabledKey = 'everkeep_biometric_lock_enabled';
  static const String _timeoutSecondsKey = 'everkeep_biometric_lock_timeout_sec';

  final FlutterSecureStorage _storage;

  PlatformBiometricLockStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  @override
  Future<bool> isBiometricLockEnabled() async {
    final value = await _storage.read(key: _enabledKey);
    return value == 'true';
  }

  @override
  Future<void> setBiometricLockEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
  }

  @override
  Future<Duration> getLockTimeout() async {
    final raw = await _storage.read(key: _timeoutSecondsKey);
    if (raw == null) return Duration.zero; // Default: Immediately
    final seconds = int.tryParse(raw) ?? 0;
    return Duration(seconds: seconds);
  }

  @override
  Future<void> setLockTimeout(Duration timeout) async {
    await _storage.write(
      key: _timeoutSecondsKey,
      value: timeout.inSeconds.toString(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _timeoutSecondsKey);
  }
}

/// In-memory storage implementation for unit and widget testing.
class InMemoryBiometricLockStorage implements BiometricLockStorage {
  bool enabled;
  Duration timeout;

  InMemoryBiometricLockStorage({
    this.enabled = false,
    this.timeout = Duration.zero,
  });

  @override
  Future<bool> isBiometricLockEnabled() async => enabled;

  @override
  Future<void> setBiometricLockEnabled(bool enabled) async {
    this.enabled = enabled;
  }

  @override
  Future<Duration> getLockTimeout() async => timeout;

  @override
  Future<void> setLockTimeout(Duration timeout) async {
    this.timeout = timeout;
  }

  @override
  Future<void> clear() async {
    enabled = false;
    timeout = Duration.zero;
  }
}

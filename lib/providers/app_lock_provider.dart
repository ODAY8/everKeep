import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../core/security/biometric_auth_service.dart';
import '../core/security/biometric_lock_storage.dart';
import 'account_provider.dart';

/// Available timeout intervals for automatically locking EverKeep.
enum LockTimeoutOption {
  immediately(Duration.zero, 'Immediately'),
  oneMinute(Duration(minutes: 1), 'After 1 minute'),
  fiveMinutes(Duration(minutes: 5), 'After 5 minutes'),
  fifteenMinutes(Duration(minutes: 15), 'After 15 minutes');

  final Duration duration;
  final String label;

  const LockTimeoutOption(this.duration, this.label);

  static LockTimeoutOption fromDuration(Duration duration) {
    for (final opt in LockTimeoutOption.values) {
      if (opt.duration == duration) return opt;
    }
    return LockTimeoutOption.immediately;
  }
}

/// Coordinates the Biometric App Lock state, lifecycle checks, and integration
/// with password vault memory safety.
class AppLockProvider extends ChangeNotifier {
  final BiometricAuthService _authService;
  final BiometricLockStorage _storage;
  AccountProvider? _accountProvider;

  bool _isEnabled = false;
  bool _isLocked = false;
  Duration _lockTimeout = Duration.zero;
  bool _isAuthenticating = false;
  String? _errorMessage;

  List<BiometricType> _availableBiometrics = const [];
  bool _canCheckBiometrics = false;
  bool _isDeviceSupported = false;
  bool _hasEnrolledBiometrics = false;
  DateTime? _lastBackgroundedTime;
  bool _isInitialized = false;

  AppLockProvider({
    BiometricAuthService? authService,
    BiometricLockStorage? storage,
    AccountProvider? accountProvider,
  })  : _authService = authService ?? LocalBiometricAuthService(),
        _storage = storage ?? PlatformBiometricLockStorage() {
    _accountProvider = accountProvider;
  }

  void updateAccountProvider(AccountProvider? provider) {
    _accountProvider = provider;
  }

  bool get isEnabled => _isEnabled;
  bool get isLocked => _isLocked;
  Duration get lockTimeout => _lockTimeout;
  LockTimeoutOption get lockTimeoutOption =>
      LockTimeoutOption.fromDuration(_lockTimeout);
  bool get isAuthenticating => _isAuthenticating;
  String? get errorMessage => _errorMessage;

  List<BiometricType> get availableBiometrics => _availableBiometrics;
  bool get canCheckBiometrics => _canCheckBiometrics;
  bool get isDeviceSupported => _isDeviceSupported;
  bool get hasEnrolledBiometrics => _hasEnrolledBiometrics;
  bool get isInitialized => _isInitialized;

  /// User-friendly label matching the device's hardware type.
  String get biometricName {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris Scan';
    }
    return 'Biometrics';
  }

  /// Icon matching the device's primary biometric sensor.
  IconData get biometricIcon {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face_rounded;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint_rounded;
    }
    return Icons.lock_outline_rounded;
  }

  /// Initialises hardware detection and restores persisted lock preferences.
  Future<void> initialize({bool requireAuthenticationOnLaunch = true}) async {
    try {
      _isDeviceSupported = await _authService.isDeviceSupported();
      _canCheckBiometrics = await _authService.canCheckBiometrics();
      _availableBiometrics = await _authService.getAvailableBiometrics();
      _hasEnrolledBiometrics = await _authService.hasEnrolledBiometrics();

      _isEnabled = await _storage.isBiometricLockEnabled();
      _lockTimeout = await _storage.getLockTimeout();

      // If biometric lock is enabled, require authentication on fresh launch.
      if (_isEnabled && requireAuthenticationOnLaunch) {
        _isLocked = true;
        _clearDecryptedCache();
      }
    } catch (_) {
      // Gracefully fall back to unlocked if hardware initialization fails
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Attempts to enable biometric lock after checking hardware and requiring
  /// a confirmation biometric challenge.
  Future<bool> enableBiometricLock() async {
    if (!_isDeviceSupported || !_canCheckBiometrics) {
      _errorMessage =
          'Biometric authentication is not supported by this device.';
      notifyListeners();
      return false;
    }

    final hasEnrolled = await _authService.hasEnrolledBiometrics();
    if (!hasEnrolled) {
      _errorMessage =
          'No biometrics are enrolled on this device. Please add a fingerprint '
          'or face unlock in your phone\'s settings.';
      notifyListeners();
      return false;
    }

    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.authenticate(
        localizedReason: 'Confirm your $biometricName to enable Biometric Lock',
      );

      if (result.isSuccess) {
        _isEnabled = true;
        await _storage.setBiometricLockEnabled(true);
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Authentication failed';
        notifyListeners();
        return false;
      }
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// Disables biometric lock after requiring a successful biometric confirmation.
  Future<bool> disableBiometricLock() async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.authenticate(
        localizedReason:
            'Confirm your $biometricName to disable Biometric Lock',
      );

      if (result.isSuccess) {
        _isEnabled = false;
        _isLocked = false;
        await _storage.setBiometricLockEnabled(false);
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Authentication failed';
        notifyListeners();
        return false;
      }
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// Updates the lock timeout preference.
  Future<void> setLockTimeout(Duration timeout) async {
    _lockTimeout = timeout;
    await _storage.setLockTimeout(timeout);
    notifyListeners();
  }

  /// Immediately locks the app and clears decrypted password memory caches.
  void lock() {
    if (!_isEnabled) return;
    _isLocked = true;
    _errorMessage = null;
    _clearDecryptedCache();
    notifyListeners();
  }

  /// Prompts the user for biometric unlock.
  Future<bool> unlock() async {
    if (!_isLocked) return true;
    if (_isAuthenticating) return false;

    _isAuthenticating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.authenticate(
        localizedReason: 'Unlock EverKeep to access your secure vault',
      );

      if (result.isSuccess) {
        _isLocked = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Authentication failed';
        notifyListeners();
        return false;
      }
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// App lifecycle hook: called when the app goes into the background or pauses.
  void onAppBackgrounded() {
    if (_isEnabled && !_isLocked) {
      _lastBackgroundedTime = DateTime.now();
    }
  }

  /// App lifecycle hook: called when the app is resumed to the foreground.
  void onAppForegrounded() {
    if (!_isEnabled || _isLocked) return;

    if (_lastBackgroundedTime != null) {
      final elapsed = DateTime.now().difference(_lastBackgroundedTime!);
      if (elapsed >= _lockTimeout) {
        lock();
      }
    }
    _lastBackgroundedTime = null;
  }

  /// Resets lock state on sign-out while leaving device hardware capabilities intact.
  void onSignOut() {
    _isLocked = false;
    _errorMessage = null;
    _lastBackgroundedTime = null;
    _clearDecryptedCache();
    notifyListeners();
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  void _clearDecryptedCache() {
    _accountProvider?.clearDecryptedPasswordCache();
  }
}

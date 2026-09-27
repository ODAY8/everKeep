import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Status codes for biometric authentication outcomes.
enum BiometricAuthStatus {
  success,
  failure,
  canceled,
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  error,
}

/// Represents the result of a biometric authentication request.
class BiometricAuthResult {
  final BiometricAuthStatus status;
  final String? errorMessage;

  const BiometricAuthResult(this.status, [this.errorMessage]);

  bool get isSuccess => status == BiometricAuthStatus.success;

  static const success = BiometricAuthResult(BiometricAuthStatus.success);
  static const failure = BiometricAuthResult(
    BiometricAuthStatus.failure,
    'Biometric authentication was not recognized. Please try again.',
  );
  static const canceled = BiometricAuthResult(
    BiometricAuthStatus.canceled,
    'Authentication was canceled.',
  );
  static const notAvailable = BiometricAuthResult(
    BiometricAuthStatus.notAvailable,
    'Biometric hardware is not available on this device.',
  );
  static const notEnrolled = BiometricAuthResult(
    BiometricAuthStatus.notEnrolled,
    'No biometrics or lock screen credentials enrolled on this device.',
  );
  static const lockedOut = BiometricAuthResult(
    BiometricAuthStatus.lockedOut,
    'Too many failed attempts. Biometric sensor is temporarily locked.',
  );
  static const permanentlyLockedOut = BiometricAuthResult(
    BiometricAuthStatus.permanentlyLockedOut,
    'Biometrics permanently locked. Unlock your device using your device passcode.',
  );
}

/// Abstract contract for device biometric capability checks and authentication.
abstract class BiometricAuthService {
  Future<bool> canCheckBiometrics();
  Future<bool> isDeviceSupported();
  Future<List<BiometricType>> getAvailableBiometrics();
  Future<bool> hasEnrolledBiometrics();
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  });
}

/// Production implementation backed by Flutter's [LocalAuthentication].
class LocalBiometricAuthService implements BiometricAuthService {
  final LocalAuthentication _auth;

  LocalBiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  }) async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) {
        return BiometricAuthResult.notAvailable;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        return BiometricAuthResult.success;
      } else {
        return BiometricAuthResult.failure;
      }
    } on LocalAuthException catch (e) {
      return _mapLocalAuthException(e);
    } on PlatformException catch (e) {
      return _mapPlatformException(e);
    } catch (e) {
      return BiometricAuthResult(
        BiometricAuthStatus.error,
        'Unexpected biometric error: $e',
      );
    }
  }

  BiometricAuthResult _mapLocalAuthException(LocalAuthException e) {
    switch (e.code) {
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return BiometricAuthResult.notAvailable;
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return BiometricAuthResult.notEnrolled;
      case LocalAuthExceptionCode.temporaryLockout:
        return BiometricAuthResult.lockedOut;
      case LocalAuthExceptionCode.biometricLockout:
        return BiometricAuthResult.permanentlyLockedOut;
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
        return BiometricAuthResult.canceled;
      case LocalAuthExceptionCode.authInProgress:
        return const BiometricAuthResult(
          BiometricAuthStatus.error,
          'An authentication prompt is already active.',
        );
      default:
        return BiometricAuthResult(
          BiometricAuthStatus.error,
          e.description ?? 'Authentication error',
        );
    }
  }

  BiometricAuthResult _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return BiometricAuthResult.notAvailable;
      case 'NotEnrolled':
      case 'PasscodeNotSet':
        return BiometricAuthResult.notEnrolled;
      case 'LockedOut':
        return BiometricAuthResult.lockedOut;
      case 'PermanentlyLockedOut':
        return BiometricAuthResult.permanentlyLockedOut;
      case 'auth_in_progress':
        return const BiometricAuthResult(
          BiometricAuthStatus.error,
          'An authentication prompt is already active.',
        );
      case 'UserCancel':
      case 'SystemCancel':
      case 'AppCancel':
        return BiometricAuthResult.canceled;
      default:
        return BiometricAuthResult(
          BiometricAuthStatus.error,
          e.message ?? 'Authentication error (${e.code})',
        );
    }
  }
}

/// Fake implementation for tests allowing complete control over capabilities and auth outcomes.
class FakeBiometricAuthService implements BiometricAuthService {
  bool isSupported;
  bool canCheck;
  List<BiometricType> biometrics;
  BiometricAuthResult nextResult;
  int authenticateCalls = 0;
  String? lastReason;

  FakeBiometricAuthService({
    this.isSupported = true,
    this.canCheck = true,
    this.biometrics = const [BiometricType.fingerprint],
    this.nextResult = BiometricAuthResult.success,
  });

  @override
  Future<bool> isDeviceSupported() async => isSupported;

  @override
  Future<bool> canCheckBiometrics() async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrics;

  @override
  Future<bool> hasEnrolledBiometrics() async =>
      canCheck && isSupported && biometrics.isNotEmpty;

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  }) async {
    authenticateCalls++;
    lastReason = localizedReason;
    return nextResult;
  }
}

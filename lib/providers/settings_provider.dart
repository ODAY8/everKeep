import 'package:flutter/foundation.dart';
import '../models/security_settings.dart';
import '../repositories/settings_repository.dart';
import 'session_scoped.dart';

class SettingsProvider extends ChangeNotifier with SessionScoped {
  final SettingsRepository _settingsRepository;

  SecuritySettings _settings = const SecuritySettings();
  bool _isLoading = false;
  String? _error;

  SettingsProvider({SettingsRepository? settingsRepository})
      : _settingsRepository = settingsRepository ?? SettingsRepositoryImpl();

  SecuritySettings get settings => _settings;
  bool get twoFactorEnabled => _settings.twoFactorEnabled;
  bool get biometricEnabled => _settings.biometricEnabled;
  bool get loginAlertsEnabled => _settings.loginAlertsEnabled;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchSecuritySettings() async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _settingsRepository.fetchSecuritySettings();
      if (isStale(epoch)) return;
      _settings = fetched;
    } catch (e) {
      if (isStale(epoch)) return;
      _error = errorMessage(e);
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> toggleTwoFactor(bool value) {
    final previous = _settings.twoFactorEnabled;
    return _persist(
      _settings.copyWith(twoFactorEnabled: value),
      rollback: (s) => s.copyWith(twoFactorEnabled: previous),
    );
  }

  Future<bool> toggleBiometric(bool value) {
    final previous = _settings.biometricEnabled;
    return _persist(
      _settings.copyWith(biometricEnabled: value),
      rollback: (s) => s.copyWith(biometricEnabled: previous),
    );
  }

  Future<bool> toggleLoginAlerts(bool value) {
    final previous = _settings.loginAlertsEnabled;
    return _persist(
      _settings.copyWith(loginAlertsEnabled: value),
      rollback: (s) => s.copyWith(loginAlertsEnabled: previous),
    );
  }

  /// Applies [updated] immediately, then saves it. If saving fails, only the
  /// flag that was changed is put back (via [rollback]) so a concurrent
  /// change to a different flag isn't lost.
  Future<bool> _persist(
    SecuritySettings updated, {
    required SecuritySettings Function(SecuritySettings current) rollback,
  }) async {
    final epoch = sessionEpoch;
    _settings = updated;
    _error = null;
    notifyListeners();

    try {
      await _settingsRepository.updateSecuritySettings(updated);
      return true;
    } catch (e) {
      if (isStale(epoch)) return false;
      _settings = rollback(_settings);
      _error = errorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Restores defaults (called on sign-out).
  void reset() {
    invalidateSession();
    _settings = const SecuritySettings();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

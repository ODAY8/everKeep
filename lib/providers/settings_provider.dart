import 'package:flutter/foundation.dart';
import '../models/security_settings.dart';
import '../repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _settingsRepository.fetchSecuritySettings();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleTwoFactor(bool value) async {
    final updated = _settings.copyWith(twoFactorEnabled: value);
    _settings = updated;
    notifyListeners();

    try {
      await _settingsRepository.updateSecuritySettings(updated);
    } catch (e) {
      _settings = _settings.copyWith(twoFactorEnabled: !value);
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> toggleBiometric(bool value) async {
    final updated = _settings.copyWith(biometricEnabled: value);
    _settings = updated;
    notifyListeners();

    try {
      await _settingsRepository.updateSecuritySettings(updated);
    } catch (e) {
      _settings = _settings.copyWith(biometricEnabled: !value);
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> toggleLoginAlerts(bool value) async {
    final updated = _settings.copyWith(loginAlertsEnabled: value);
    _settings = updated;
    notifyListeners();

    try {
      await _settingsRepository.updateSecuritySettings(updated);
    } catch (e) {
      _settings = _settings.copyWith(loginAlertsEnabled: !value);
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }
}

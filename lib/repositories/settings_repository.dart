import '../models/security_settings.dart';
import '../services/settings_service.dart';

abstract class SettingsRepository {
  Future<SecuritySettings> fetchSecuritySettings();
  Future<void> updateSecuritySettings(SecuritySettings settings);
}

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsService _settingsService;

  SettingsRepositoryImpl({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsServiceImpl();

  @override
  Future<SecuritySettings> fetchSecuritySettings() {
    return _settingsService.fetchSecuritySettings();
  }

  @override
  Future<void> updateSecuritySettings(SecuritySettings settings) {
    return _settingsService.updateSecuritySettings(settings);
  }
}

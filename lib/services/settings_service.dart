import '../models/security_settings.dart';

abstract class SettingsService {
  Future<SecuritySettings> fetchSecuritySettings();
  Future<void> updateSecuritySettings(SecuritySettings settings);
}

class SettingsServiceImpl implements SettingsService {
  SecuritySettings _settings = const SecuritySettings();

  // TODO: Connect to secure local storage (SharedPreferences / FlutterSecureStorage) or remote user settings

  @override
  Future<SecuritySettings> fetchSecuritySettings() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _settings;
  }

  @override
  Future<void> updateSecuritySettings(SecuritySettings settings) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _settings = settings;
  }
}

/// A user's security preferences.
///
/// These are stored preferences. Saving one does not by itself enforce
/// anything — turning on two-factor here does not enroll an authenticator, and
/// biometric lock needs on-device support. They default to off so a new
/// account never claims a protection it hasn't set up.
class SecuritySettings {
  final bool twoFactorEnabled;
  final bool biometricEnabled;
  final bool loginAlertsEnabled;

  const SecuritySettings({
    this.twoFactorEnabled = false,
    this.biometricEnabled = false,
    this.loginAlertsEnabled = false,
  });

  /// Builds settings from a `security_settings` row.
  factory SecuritySettings.fromRow(Map<String, dynamic> row) {
    return SecuritySettings(
      twoFactorEnabled: row['two_factor_enabled'] as bool? ?? false,
      biometricEnabled: row['biometric_enabled'] as bool? ?? false,
      loginAlertsEnabled: row['login_alerts_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toRow() => {
    'two_factor_enabled': twoFactorEnabled,
    'biometric_enabled': biometricEnabled,
    'login_alerts_enabled': loginAlertsEnabled,
  };

  /// How many of the three protections are switched on.
  int get enabledCount => [
    twoFactorEnabled,
    biometricEnabled,
    loginAlertsEnabled,
  ].where((enabled) => enabled).length;

  SecuritySettings copyWith({
    bool? twoFactorEnabled,
    bool? biometricEnabled,
    bool? loginAlertsEnabled,
  }) {
    return SecuritySettings(
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      loginAlertsEnabled: loginAlertsEnabled ?? this.loginAlertsEnabled,
    );
  }
}

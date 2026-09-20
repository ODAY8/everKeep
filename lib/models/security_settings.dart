class SecuritySettings {
  final bool twoFactorEnabled;
  final bool biometricEnabled;
  final bool loginAlertsEnabled;

  const SecuritySettings({
    this.twoFactorEnabled = true,
    this.biometricEnabled = true,
    this.loginAlertsEnabled = true,
  });

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

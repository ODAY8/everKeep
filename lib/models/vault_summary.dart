class VaultSummary {
  final int totalItems;
  final String encryptionStatus;
  final int passwordsCount;
  final int documentsCount;
  final int financialsCount;
  final int messagesCount;
  final int memoriesCount;
  final int securityScore;
  final String securityScoreLabel;
  final double legacyProgress;
  final double storageUsedMb;
  final double storageLimitMb;

  const VaultSummary({
    this.totalItems = 92,
    this.encryptionStatus = 'All encrypted',
    this.passwordsCount = 24,
    this.documentsCount = 11,
    this.financialsCount = 6,
    this.messagesCount = 8,
    this.memoriesCount = 43,
    this.securityScore = 94,
    this.securityScoreLabel = 'Excellent — 94/100',
    this.legacyProgress = 0.73,
    this.storageUsedMb = 24.5,
    this.storageLimitMb = 2048.0,
  });

  VaultSummary copyWith({
    int? totalItems,
    String? encryptionStatus,
    int? passwordsCount,
    int? documentsCount,
    int? financialsCount,
    int? messagesCount,
    int? memoriesCount,
    int? securityScore,
    String? securityScoreLabel,
    double? legacyProgress,
    double? storageUsedMb,
    double? storageLimitMb,
  }) {
    return VaultSummary(
      totalItems: totalItems ?? this.totalItems,
      encryptionStatus: encryptionStatus ?? this.encryptionStatus,
      passwordsCount: passwordsCount ?? this.passwordsCount,
      documentsCount: documentsCount ?? this.documentsCount,
      financialsCount: financialsCount ?? this.financialsCount,
      messagesCount: messagesCount ?? this.messagesCount,
      memoriesCount: memoriesCount ?? this.memoriesCount,
      securityScore: securityScore ?? this.securityScore,
      securityScoreLabel: securityScoreLabel ?? this.securityScoreLabel,
      legacyProgress: legacyProgress ?? this.legacyProgress,
      storageUsedMb: storageUsedMb ?? this.storageUsedMb,
      storageLimitMb: storageLimitMb ?? this.storageLimitMb,
    );
  }
}

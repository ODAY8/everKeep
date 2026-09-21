import 'security_settings.dart';

/// The dashboard's numbers. The defaults describe an empty vault; real values
/// come from [VaultSummary.fromData], built out of the user's actual data.
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
    this.totalItems = 0,
    this.encryptionStatus = 'Private to you',
    this.passwordsCount = 0,
    this.documentsCount = 0,
    this.financialsCount = 0,
    this.messagesCount = 0,
    this.memoriesCount = 0,
    this.securityScore = 0,
    this.securityScoreLabel = 'Weak — 0/100',
    this.legacyProgress = 0.0,
    this.storageUsedMb = 0.0,
    this.storageLimitMb = defaultStorageLimitMb,
  });

  /// The storage allowance shown to users.
  static const double defaultStorageLimitMb = 2048.0;

  /// Derives the summary from what the user actually has.
  ///
  /// Financials, messages and memories aren't built yet, so they count as 0.
  /// The security score is the share of the three security preferences that
  /// are switched on. It reflects those *preferences*, not verified
  /// protections. Legacy progress is the share of four milestones reached: a
  /// document, an account, a trusted person, and at least one security
  /// preference enabled.
  factory VaultSummary.fromData({
    required int documents,
    required int accounts,
    required int trustedContacts,
    required int storageBytes,
    required SecuritySettings settings,
  }) {
    // With three preferences the score is 0, 33, 67 or 100 — one label each.
    final score = (settings.enabledCount * 100 / 3).round();
    final word = score >= 100
        ? 'Excellent'
        : score >= 67
        ? 'Good'
        : score >= 33
        ? 'Fair'
        : 'Weak';

    final milestones = [
      documents > 0,
      accounts > 0,
      trustedContacts > 0,
      settings.enabledCount > 0,
    ].where((reached) => reached).length;

    return VaultSummary(
      totalItems: documents + accounts,
      passwordsCount: accounts,
      documentsCount: documents,
      securityScore: score,
      securityScoreLabel: '$word — $score/100',
      legacyProgress: milestones / 4,
      storageUsedMb: storageBytes / (1024 * 1024),
    );
  }

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

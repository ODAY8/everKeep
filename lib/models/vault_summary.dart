import 'legacy_checklist.dart';
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
  final int trustedContactsCount;
  final bool emailVerified;
  final bool protectionsEnabled;
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
    this.trustedContactsCount = 0,
    this.emailVerified = false,
    this.protectionsEnabled = false,
    this.securityScore = 0,
    this.securityScoreLabel = 'Weak — 0/100',
    this.legacyProgress = 0.0,
    this.storageUsedMb = 0.0,
    this.storageLimitMb = defaultStorageLimitMb,
  });

  /// The storage allowance shown to users.
  static const double defaultStorageLimitMb = 2048.0;

  /// Derives the summary from what the user actually has. Memories and
  /// messages aren't built yet, so they count as 0. Accounts in the "Banking"
  /// category are the vault's "Financials"; the rest are "Passwords".
  factory VaultSummary.fromData({
    required int documents,
    required int accounts,
    required int bankingAccounts,
    required int trustedContacts,
    required int storageBytes,
    required bool emailVerified,
    required SecuritySettings settings,
  }) {
    return VaultSummary(
      totalItems: documents + accounts,
      passwordsCount: accounts - bankingAccounts,
      financialsCount: bankingAccounts,
      documentsCount: documents,
      trustedContactsCount: trustedContacts,
      emailVerified: emailVerified,
      protectionsEnabled: settings.enabledCount > 0,
      storageUsedMb: storageBytes / (1024 * 1024),
    ).withDerived();
  }

  /// Every account, whatever its category.
  int get accountsCount => passwordsCount + financialsCount;

  /// The setup steps, from the counts held here.
  LegacyChecklist get checklist => LegacyChecklist(
    documents: documentsCount,
    accounts: accountsCount,
    trustedContacts: trustedContactsCount,
    emailVerified: emailVerified,
  );

  /// This summary with the security score and legacy progress recomputed from
  /// its own counts — so they stay right when counts are updated live.
  ///
  /// The security score is the share of three safeguards in place: a confirmed
  /// email, a trusted person, and at least one protection (two-factor or
  /// biometric) switched on. It measures what is *set up*, not a guarantee.
  VaultSummary withDerived() {
    final safeguards = [
      emailVerified,
      trustedContactsCount > 0,
      protectionsEnabled,
    ].where((inPlace) => inPlace).length;

    final score = (safeguards * 100 / 3).round();
    final word = score >= 100
        ? 'Excellent'
        : score >= 67
        ? 'Good'
        : score >= 33
        ? 'Fair'
        : 'Weak';

    return copyWith(
      securityScore: score,
      securityScoreLabel: '$word — $score/100',
      legacyProgress: checklist.progress,
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
    int? trustedContactsCount,
    bool? emailVerified,
    bool? protectionsEnabled,
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
      trustedContactsCount: trustedContactsCount ?? this.trustedContactsCount,
      emailVerified: emailVerified ?? this.emailVerified,
      protectionsEnabled: protectionsEnabled ?? this.protectionsEnabled,
      securityScore: securityScore ?? this.securityScore,
      securityScoreLabel: securityScoreLabel ?? this.securityScoreLabel,
      legacyProgress: legacyProgress ?? this.legacyProgress,
      storageUsedMb: storageUsedMb ?? this.storageUsedMb,
      storageLimitMb: storageLimitMb ?? this.storageLimitMb,
    );
  }
}

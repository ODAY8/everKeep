/// The steps that make a vault "set up". Each is something the user can
/// actually do today, so 100% is reachable.
enum LegacyStep {
  addDocument('Add your first document'),
  saveAccount('Save an account login'),
  addTrustedPerson('Add a trusted person'),
  verifyEmail('Confirm your email address');

  final String prompt;
  const LegacyStep(this.prompt);
}

/// How far along the user is, computed from what they really have.
class LegacyChecklist {
  final int documents;
  final int accounts;
  final int trustedContacts;
  final bool emailVerified;

  const LegacyChecklist({
    required this.documents,
    required this.accounts,
    required this.trustedContacts,
    required this.emailVerified,
  });

  static const int totalSteps = 4;

  bool isDone(LegacyStep step) => switch (step) {
    LegacyStep.addDocument => documents > 0,
    LegacyStep.saveAccount => accounts > 0,
    LegacyStep.addTrustedPerson => trustedContacts > 0,
    LegacyStep.verifyEmail => emailVerified,
  };

  int get completed => LegacyStep.values.where(isDone).length;
  int get remaining => totalSteps - completed;
  double get progress => completed / totalSteps;
  bool get isComplete => remaining == 0;

  /// The first step still to do, in a sensible order — or null when finished.
  LegacyStep? get nextStep {
    for (final step in LegacyStep.values) {
      if (!isDone(step)) return step;
    }
    return null;
  }
}

import 'package:flutter/foundation.dart';
import '../models/vault_summary.dart';
import '../repositories/vault_repository.dart';
import 'session_scoped.dart';

class VaultProvider extends ChangeNotifier with SessionScoped {
  final VaultRepository _vaultRepository;

  /// The summary as last returned by the backend.
  VaultSummary _base = const VaultSummary();

  /// [_base] with the counts replaced by what the Documents, Accounts and
  /// Trusted People providers actually hold, and the score/progress recomputed
  /// from them. Cached so `Selector`s only rebuild when it really changes.
  VaultSummary _summary = const VaultSummary();
  int? _documentsCount;
  int? _accountsCount;
  int? _bankingCount;
  int? _contactsCount;

  bool _isLoading = false;
  String? _error;

  VaultProvider({VaultRepository? vaultRepository})
      : _vaultRepository = vaultRepository ?? VaultRepositoryImpl();

  VaultSummary get vaultSummary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchVaultSummary() async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _vaultRepository.fetchVaultSummary();
      if (isStale(epoch)) return;
      _base = fetched;
      _recompute();
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

  /// Overrides the counts with live values. Pass null for a count that isn't
  /// loaded yet to fall back to the backend's figure. [accounts] is every
  /// account; [banking] is how many of them are in the Banking category.
  void updateLiveCounts({
    int? documents,
    int? accounts,
    int? banking,
    int? contacts,
  }) {
    if (documents == _documentsCount &&
        accounts == _accountsCount &&
        banking == _bankingCount &&
        contacts == _contactsCount) {
      return;
    }
    _documentsCount = documents;
    _accountsCount = accounts;
    _bankingCount = banking;
    _contactsCount = contacts;
    _recompute();
    notifyListeners();
  }

  void _recompute() {
    final baseAccounts = _base.accountsCount;
    final documents = _documentsCount ?? _base.documentsCount;
    final accounts = _accountsCount ?? baseAccounts;
    final banking = _bankingCount ?? _base.financialsCount;
    final contacts = _contactsCount ?? _base.trustedContactsCount;

    _summary = _base
        .copyWith(
          // Shift the total by however far the live counts moved from the
          // backend's, so any categories we don't track stay included.
          totalItems: _base.totalItems +
              (documents - _base.documentsCount) +
              (accounts - baseAccounts),
          documentsCount: documents,
          passwordsCount: accounts - banking,
          financialsCount: banking,
          trustedContactsCount: contacts,
        )
        // Score and progress follow the counts, so they stay right as the user
        // adds and removes things without another round trip.
        .withDerived();
  }

  /// Forgets the previous user's summary (called on sign-out).
  void reset() {
    invalidateSession();
    _base = const VaultSummary();
    _documentsCount = null;
    _accountsCount = null;
    _bankingCount = null;
    _contactsCount = null;
    _summary = _base;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

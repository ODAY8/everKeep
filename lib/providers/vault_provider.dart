import 'package:flutter/foundation.dart';
import '../models/vault_summary.dart';
import '../repositories/vault_repository.dart';
import 'session_scoped.dart';

class VaultProvider extends ChangeNotifier with SessionScoped {
  final VaultRepository _vaultRepository;

  /// The summary as last returned by the backend.
  VaultSummary _base = const VaultSummary();

  /// [_base] with the document/password counts replaced by what the
  /// Documents and Accounts providers actually hold. Cached so `Selector`s
  /// only rebuild when it really changes.
  VaultSummary _summary = const VaultSummary();
  int? _documentsCount;
  int? _passwordsCount;

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

  /// Overrides the document/password counts with live values. Pass null for
  /// a count that isn't loaded yet to fall back to the backend's figure.
  void updateLiveCounts({int? documents, int? passwords}) {
    if (documents == _documentsCount && passwords == _passwordsCount) return;
    _documentsCount = documents;
    _passwordsCount = passwords;
    _recompute();
    notifyListeners();
  }

  void _recompute() {
    final documents = _documentsCount ?? _base.documentsCount;
    final passwords = _passwordsCount ?? _base.passwordsCount;
    _summary = _base.copyWith(
      // Shift the total by however far the live counts moved from the
      // backend's, so any categories we don't track stay included.
      totalItems: _base.totalItems +
          (documents - _base.documentsCount) +
          (passwords - _base.passwordsCount),
      documentsCount: documents,
      passwordsCount: passwords,
    );
  }

  /// Forgets the previous user's summary (called on sign-out).
  void reset() {
    invalidateSession();
    _base = const VaultSummary();
    _documentsCount = null;
    _passwordsCount = null;
    _summary = _base;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

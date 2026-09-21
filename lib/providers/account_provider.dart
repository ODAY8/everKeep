import 'package:flutter/foundation.dart';
import '../models/account_item.dart';
import '../repositories/account_repository.dart';
import 'session_scoped.dart';

class AccountProvider extends ChangeNotifier with SessionScoped {
  final AccountRepository _accountRepository;

  List<AccountItem> _accounts = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  AccountProvider({AccountRepository? accountRepository})
      : _accountRepository = accountRepository ?? AccountRepositoryImpl();

  List<AccountItem> get accounts => List.unmodifiable(_accounts);
  List<AccountItem> get favoriteAccounts =>
      List.unmodifiable(_accounts.where((a) => a.isFavorite));
  int get count => _accounts.length;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  bool get isEmpty => _accounts.isEmpty;

  List<AccountItem> filterByCategory(String category) {
    if (category.isEmpty || category == 'All') {
      return accounts;
    }
    return _accounts
        .where((acc) => acc.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  Future<void> fetchAccounts() async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _accountRepository.fetchAccounts();
      if (isStale(epoch)) return;
      _accounts = fetched;
      _hasFetched = true;
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

  Future<bool> addAccount(AccountItem item) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final added = await _accountRepository.addAccount(item);
      if (isStale(epoch)) return false;
      _accounts.insert(0, added);
      return true;
    } catch (e) {
      if (isStale(epoch)) return false;
      _error = errorMessage(e);
      return false;
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Saves edits to an account's name, username or category.
  Future<bool> updateAccount(AccountItem item) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saved = await _accountRepository.updateAccount(item);
      if (isStale(epoch)) return false;
      final index = _accounts.indexWhere((a) => a.id == saved.id);
      if (index != -1) _accounts[index] = saved;
      return true;
    } catch (e) {
      if (isStale(epoch)) return false;
      _error = errorMessage(e);
      return false;
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Flips the favorite flag immediately and rolls it back if the backend
  /// rejects the change. Returns whether the change stuck.
  Future<bool> toggleFavorite(String id) async {
    final index = _accounts.indexWhere((item) => item.id == id);
    if (index == -1) return false;

    final epoch = sessionEpoch;
    final wasFavorite = _accounts[index].isFavorite;
    _accounts[index] = _accounts[index].copyWith(isFavorite: !wasFavorite);
    _error = null;
    notifyListeners();

    try {
      await _accountRepository.setFavorite(id, !wasFavorite);
      return true;
    } catch (e) {
      if (isStale(epoch)) return false;
      // Look the item up again: the list may have shifted (an add or delete)
      // while the request was in flight, so the original index can be wrong.
      final current = _accounts.indexWhere((item) => item.id == id);
      if (current != -1) {
        _accounts[current] =
            _accounts[current].copyWith(isFavorite: wasFavorite);
      }
      _error = errorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount(String id) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _accountRepository.deleteAccount(id);
      if (isStale(epoch)) return false;
      _accounts.removeWhere((item) => item.id == id);
      return true;
    } catch (e) {
      if (isStale(epoch)) return false;
      _error = errorMessage(e);
      return false;
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Drops everything held for the previous user (called on sign-out).
  void reset() {
    invalidateSession();
    _accounts = [];
    _isLoading = false;
    _error = null;
    _hasFetched = false;
    notifyListeners();
  }
}

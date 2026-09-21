import 'package:flutter/foundation.dart';
import '../models/account_item.dart';
import '../repositories/account_repository.dart';

class AccountProvider extends ChangeNotifier {
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _accounts = await _accountRepository.fetchAccounts();
      _hasFetched = true;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addAccount(AccountItem item) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final added = await _accountRepository.addAccount(item);
      _accounts.insert(0, added);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String id) async {
    final index = _accounts.indexWhere((item) => item.id == id);
    if (index == -1) return;

    // Optimistic UI update
    final current = _accounts[index];
    _accounts[index] = current.copyWith(isFavorite: !current.isFavorite);
    notifyListeners();

    try {
      await _accountRepository.toggleFavorite(id);
    } catch (e) {
      // Rollback on error
      _accounts[index] = current;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> deleteAccount(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _accountRepository.deleteAccount(id);
      _accounts.removeWhere((item) => item.id == id);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

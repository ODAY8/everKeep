import '../models/account_item.dart';
import '../services/account_service.dart';

abstract class AccountRepository {
  Future<List<AccountItem>> fetchAccounts();
  Future<AccountItem> addAccount(AccountItem item);
  Future<AccountItem> updateAccount(AccountItem item);
  Future<void> setFavorite(String id, bool isFavorite);
  Future<void> deleteAccount(String id);
}

class AccountRepositoryImpl implements AccountRepository {
  final AccountService _accountService;

  AccountRepositoryImpl({AccountService? accountService})
    : _accountService = accountService ?? AccountServiceImpl();

  @override
  Future<List<AccountItem>> fetchAccounts() {
    return _accountService.fetchAccounts();
  }

  @override
  Future<AccountItem> addAccount(AccountItem item) {
    return _accountService.addAccount(item);
  }

  @override
  Future<AccountItem> updateAccount(AccountItem item) {
    return _accountService.updateAccount(item);
  }

  @override
  Future<void> setFavorite(String id, bool isFavorite) {
    return _accountService.setFavorite(id, isFavorite);
  }

  @override
  Future<void> deleteAccount(String id) {
    return _accountService.deleteAccount(id);
  }
}

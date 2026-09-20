import '../models/account_item.dart';
import '../services/account_service.dart';

abstract class AccountRepository {
  Future<List<AccountItem>> fetchAccounts();
  Future<AccountItem> addAccount(AccountItem item);
  Future<void> toggleFavorite(String id);
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
  Future<void> toggleFavorite(String id) {
    return _accountService.toggleFavorite(id);
  }

  @override
  Future<void> deleteAccount(String id) {
    return _accountService.deleteAccount(id);
  }
}

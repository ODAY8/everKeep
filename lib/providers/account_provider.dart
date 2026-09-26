import 'package:flutter/foundation.dart';
import '../core/security/vault_crypto_service.dart';
import '../core/utils/search_helper.dart';
import '../models/account_item.dart';
import '../repositories/account_repository.dart';
import 'session_scoped.dart';

class AccountProvider extends ChangeNotifier with SessionScoped {
  final AccountRepository _accountRepository;
  final VaultCryptoService _cryptoService;

  List<AccountItem> _accounts = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  AccountProvider({
    AccountRepository? accountRepository,
    VaultCryptoService? cryptoService,
  })  : _accountRepository = accountRepository ?? AccountRepositoryImpl(),
        _cryptoService = cryptoService ?? VaultCryptoService();

  VaultCryptoService get cryptoService => _cryptoService;

  List<AccountItem> get accounts => List.unmodifiable(_accounts);
  List<AccountItem> get favoriteAccounts =>
      List.unmodifiable(_accounts.where((a) => a.isFavorite));
  int get count => _accounts.length;

  /// Returns accounts that have an encrypted password saved in the vault.
  List<AccountItem> get credentials =>
      List.unmodifiable(_accounts.where((a) => a.hasPassword));
  int get credentialsCount => _accounts.where((a) => a.hasPassword).length;

  /// Accounts in the Banking category (the vault's "Financials").
  int get bankingCount => _accounts.where((a) => a.category == 'Banking').length;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  bool get isEmpty => _accounts.isEmpty;

  /// Accounts in [category] ("All" or empty for every category) whose metadata
  /// matches [query] (ignoring case).
  List<AccountItem> filterByCategory(String category, {String query = ''}) {
    final tokens = SearchMatcher.tokenize(query);
    final anyCategory = category.isEmpty || category == 'All';
    return _accounts.where((acc) {
      if (!anyCategory && acc.category.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      return SearchMatcher.matchesAccount(acc, tokens: tokens);
    }).toList();
  }

  /// Filters credentials (by category, query, and optionally restricting to items with passwords).
  List<AccountItem> filterCredentials(
    String category, {
    String query = '',
    bool passwordsOnly = false,
  }) {
    final tokens = SearchMatcher.tokenize(query);
    final anyCategory = category.isEmpty || category == 'All';
    return _accounts.where((acc) {
      if (passwordsOnly && !acc.hasPassword) return false;
      if (!anyCategory && acc.category.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      return SearchMatcher.matchesAccount(acc, tokens: tokens);
    }).toList();
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

  /// Saves edits to an account's name, username, category, website, notes, or password.
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

  /// Decrypts a password on demand for the given [account] and [userId].
  ///
  /// Uses ephemeral in-memory cache to avoid redundant crypto operations.
  Future<String?> getDecryptedPassword(
    AccountItem account, {
    required String userId,
  }) async {
    if (!account.hasPassword || account.encryptedPassword == null) return null;

    final cached = _cryptoService.getCachedDecryptedPassword(account.id);
    if (cached != null) return cached;

    try {
      final decrypted = await _cryptoService.decryptPassword(
        account.encryptedPassword!,
        userId: userId,
      );
      _cryptoService.cacheDecryptedPassword(account.id, decrypted);
      return decrypted;
    } catch (_) {
      return null;
    }
  }

  /// Creates and saves a new credential with client-side encrypted password.
  Future<bool> addCredential({
    required String title,
    String? username,
    String? website,
    String? password,
    required String category,
    String? notes,
    required String userId,
  }) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String? encryptedPassword;
      final trimmedPassword = password?.trim();
      if (trimmedPassword != null && trimmedPassword.isNotEmpty) {
        encryptedPassword = await _cryptoService.encryptPassword(
          trimmedPassword,
          userId: userId,
        );
      }

      final (icon, color) = AccountItem.styleFor(category);
      final newItem = AccountItem(
        id: '',
        title: title.trim(),
        subtitle: '',
        category: category,
        icon: icon,
        color: color,
        username: (username == null || username.trim().isEmpty) ? null : username.trim(),
        website: (website == null || website.trim().isEmpty) ? null : website.trim(),
        notes: (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
        encryptedPassword: encryptedPassword,
      );

      final added = await _accountRepository.addAccount(newItem);
      if (isStale(epoch)) return false;

      if (trimmedPassword != null && trimmedPassword.isNotEmpty) {
        _cryptoService.cacheDecryptedPassword(added.id, trimmedPassword);
      }

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

  /// Updates an existing credential with new fields and optional new password.
  Future<bool> updateCredential({
    required AccountItem account,
    String? newTitle,
    String? newUsername,
    String? newWebsite,
    String? newCategory,
    String? newNotes,
    String? newPassword,
    bool removePassword = false,
    required String userId,
  }) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String? updatedEncryptedPassword = account.encryptedPassword;

      if (removePassword) {
        updatedEncryptedPassword = null;
        _cryptoService.cacheDecryptedPassword(account.id, '');
      } else if (newPassword != null && newPassword.trim().isNotEmpty) {
        final trimmed = newPassword.trim();
        updatedEncryptedPassword = await _cryptoService.encryptPassword(
          trimmed,
          userId: userId,
        );
        _cryptoService.cacheDecryptedPassword(account.id, trimmed);
      }

      final category = newCategory ?? account.category;
      final (icon, color) = AccountItem.styleFor(category);

      final updated = account.copyWith(
        title: newTitle?.trim() ?? account.title,
        username: newUsername != null
            ? (newUsername.trim().isEmpty ? null : newUsername.trim())
            : account.username,
        website: newWebsite != null
            ? (newWebsite.trim().isEmpty ? null : newWebsite.trim())
            : account.website,
        notes: newNotes != null
            ? (newNotes.trim().isEmpty ? null : newNotes.trim())
            : account.notes,
        category: category,
        icon: icon,
        color: color,
        encryptedPassword: updatedEncryptedPassword,
        clearPassword: removePassword,
        clearWebsite: newWebsite != null && newWebsite.trim().isEmpty,
        clearNotes: newNotes != null && newNotes.trim().isEmpty,
      );

      final saved = await _accountRepository.updateAccount(updated);
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
  ///
  /// Clears in-memory accounts, states, and sensitive decrypted passwords.
  void reset() {
    invalidateSession();
    _cryptoService.clearCache();
    _accounts = [];
    _isLoading = false;
    _error = null;
    _hasFetched = false;
    notifyListeners();
  }
}

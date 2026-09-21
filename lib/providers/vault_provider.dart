import 'package:flutter/foundation.dart';
import '../models/vault_summary.dart';
import '../repositories/vault_repository.dart';

class VaultProvider extends ChangeNotifier {
  final VaultRepository _vaultRepository;

  VaultSummary _vaultSummary = const VaultSummary();
  bool _isLoading = false;
  String? _error;

  VaultProvider({VaultRepository? vaultRepository})
      : _vaultRepository = vaultRepository ?? VaultRepositoryImpl();

  VaultSummary get vaultSummary => _vaultSummary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchVaultSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _vaultSummary = await _vaultRepository.fetchVaultSummary();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

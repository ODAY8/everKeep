import '../models/vault_summary.dart';
import '../services/vault_service.dart';

abstract class VaultRepository {
  Future<VaultSummary> fetchVaultSummary();
}

class VaultRepositoryImpl implements VaultRepository {
  final VaultService _vaultService;

  VaultRepositoryImpl({VaultService? vaultService})
    : _vaultService = vaultService ?? VaultServiceImpl();

  @override
  Future<VaultSummary> fetchVaultSummary() {
    return _vaultService.fetchVaultSummary();
  }
}

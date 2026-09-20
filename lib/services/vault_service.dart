import '../models/vault_summary.dart';

abstract class VaultService {
  Future<VaultSummary> fetchVaultSummary();
}

class VaultServiceImpl implements VaultService {
  // TODO: Connect to backend API for calculating live vault analytics

  @override
  Future<VaultSummary> fetchVaultSummary() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const VaultSummary();
  }
}

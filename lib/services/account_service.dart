import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/account_item.dart';

abstract class AccountService {
  Future<List<AccountItem>> fetchAccounts();
  Future<AccountItem> addAccount(AccountItem item);
  Future<void> toggleFavorite(String id);
  Future<void> deleteAccount(String id);
}

class AccountServiceImpl implements AccountService {
  final List<AccountItem> _mockDatabase = [
    const AccountItem(
      id: 'acc-1',
      title: 'Bank of America - Checking',
      subtitle: 'Updated yesterday · •••• 1234',
      category: 'Banking',
      icon: Icons.account_balance_rounded,
      color: AppColors.glassAccentGreen,
      isFavorite: true,
    ),
    const AccountItem(
      id: 'acc-2',
      title: 'Amazon.com',
      subtitle: 'Updated 3 days ago · •••• 5678',
      category: 'Social',
      icon: Icons.shopping_cart_rounded,
      color: AppColors.glassAccentPink,
      isFavorite: false,
    ),
    const AccountItem(
      id: 'acc-3',
      title: 'GitHub',
      subtitle: 'Updated 1 week ago',
      category: 'Work',
      icon: Icons.code_rounded,
      color: AppColors.glassOnSurfaceMuted,
      isFavorite: true,
    ),
    const AccountItem(
      id: 'acc-4',
      title: 'Wi-Fi Home Network',
      subtitle: 'Updated 2 weeks ago',
      category: 'Other',
      icon: Icons.wifi_rounded,
      color: AppColors.glassAccentBlue,
      isFavorite: false,
    ),
  ];

  // TODO: Connect to encrypted password/credentials vault backend

  @override
  Future<List<AccountItem>> fetchAccounts() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.from(_mockDatabase);
  }

  @override
  Future<AccountItem> addAccount(AccountItem item) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockDatabase.insert(0, item);
    return item;
  }

  @override
  Future<void> toggleFavorite(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _mockDatabase.indexWhere((item) => item.id == id);
    if (index != -1) {
      final current = _mockDatabase[index];
      _mockDatabase[index] = current.copyWith(isFavorite: !current.isFavorite);
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockDatabase.removeWhere((item) => item.id == id);
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/account_item.dart';
import '../../../../providers/account_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_sheet.dart';

const List<String> accountCategories = [
  'Banking',
  'Social',
  'Work',
  'Other',
];

/// Displays the glass form sheet for creating or updating an account.
Future<bool> showAccountFormSheet(
  BuildContext context, {
  AccountItem? existing,
}) async {
  final accProv = context.read<AccountProvider>();
  final isEditing = existing != null;
  final initialCategory = existing?.category ?? accountCategories.first;
  var initialCategoryIndex = accountCategories.indexOf(initialCategory);
  if (initialCategoryIndex == -1) initialCategoryIndex = 0;

  final saved = await showGlassFormSheet(
    context,
    title: isEditing ? 'Edit Account' : 'Add Account',
    subtitle: isEditing
        ? 'Update login details or category for this account.'
        : 'Save a login so your trusted people can find it later.',
    submitLabel: isEditing ? 'Save Changes' : 'Add Account',
    fields: [
      GlassFormField(
        key: 'title',
        label: 'Account name',
        hint: 'e.g. Netflix',
        initialValue: existing?.title ?? '',
      ),
      GlassFormField(
        key: 'username',
        label: 'Username or email',
        hint: 'Optional',
        required: false,
        keyboardType: TextInputType.emailAddress,
        initialValue: existing?.username ?? '',
      ),
    ],
    choices: [
      GlassFormChoice(
        key: 'category',
        label: 'Category',
        options: accountCategories,
        initialIndex: initialCategoryIndex,
      ),
    ],
    onSubmit: (values) async {
      final category = values['category']!;
      final username = values['username']!.trim();
      final (icon, color) = AccountItem.styleFor(category);

      if (isEditing) {
        final prefix = existing.subtitle.contains(' · ')
            ? existing.subtitle.split(' · ').first
            : existing.subtitle;
        final updatedSubtitle = username.isEmpty
            ? prefix
            : '$prefix · $username';

        final updated = existing.copyWith(
          title: values['title']!,
          username: username.isEmpty ? null : username,
          category: category,
          icon: icon,
          color: color,
          subtitle: updatedSubtitle,
        );
        final ok = await accProv.updateAccount(updated);
        return ok ? null : accProv.error ?? 'Could not update the account.';
      } else {
        final added = await accProv.addAccount(
          AccountItem(
            id: '',
            title: values['title']!,
            subtitle: '',
            category: category,
            icon: icon,
            color: color,
            username: username.isEmpty ? null : username,
          ),
        );
        return added ? null : accProv.error ?? 'Could not add the account.';
      }
    },
  );

  if (saved && context.mounted) {
    showAppSnackBar(
      context,
      isEditing ? 'Account updated' : 'Account added',
    );
  }

  return saved;
}

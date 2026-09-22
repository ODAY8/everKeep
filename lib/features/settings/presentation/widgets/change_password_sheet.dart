import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/utils/validators.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';

/// The "change password" form, shared by Settings and Security. Keeps the
/// user's input if saving fails, and confirms with a snackbar on success.
Future<void> showChangePasswordSheet(BuildContext context) async {
  final auth = context.read<AuthProvider>();

  final saved = await showGlassFormSheet(
    context,
    title: 'Change Password',
    submitLabel: 'Update Password',
    fields: [
      GlassFormField(
        key: 'password',
        label: 'New password',
        hint: '••••••••',
        obscure: true,
        validator: validatePassword,
      ),
      const GlassFormField(
        key: 'confirm',
        label: 'Confirm password',
        hint: '••••••••',
        obscure: true,
      ),
    ],
    onSubmit: (values) async {
      if (values['password'] != values['confirm']) {
        return 'The passwords don\'t match.';
      }
      final ok = await auth.updatePassword(values['password']!);
      return ok ? null : auth.error ?? 'Could not change your password.';
    },
  );

  if (saved && context.mounted) showAppSnackBar(context, 'Password updated');
}

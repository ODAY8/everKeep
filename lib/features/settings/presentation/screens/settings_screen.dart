import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/config/app_info.dart';
import 'package:everkeep/core/config/app_links.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/session/sign_out.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/core/utils/external_link.dart';
import 'package:everkeep/core/utils/validators.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/features/settings/presentation/widgets/change_password_sheet.dart';
import 'package:everkeep/features/settings/presentation/widgets/phone_edit_sheet.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/glass_list_row.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';

/// Account, data and support settings. Every row does something: the account
/// rows change real account data, and the support/legal rows only appear when
/// their link has been configured (see `AppLinks`).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ── Account ─────────────────────────────────────────────────────────────────

  Future<void> _changeEmail(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final saved = await showGlassFormSheet(
      context,
      title: 'Change Email',
      subtitle: 'We\'ll send a confirmation link to the new address. Your email '
          'changes once you open it.',
      submitLabel: 'Send Link',
      fields: [
        GlassFormField(
          key: 'email',
          label: 'New email address',
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          validator: (v) => isValidEmail(v) ? null : 'Enter a valid email address',
        ),
      ],
      onSubmit: (values) async {
        final ok = await auth.updateEmail(values['email']!);
        return ok ? null : auth.error ?? 'Could not change your email.';
      },
    );
    if (saved && context.mounted) {
      showAppSnackBar(context, auth.notice ?? 'Check your new email to confirm.');
    }
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _exportData(BuildContext context) async {
    final userProv = context.read<UserProvider>();
    showAppSnackBar(context, 'Gathering your data…');

    final json = await userProv.exportData();
    if (!context.mounted) return;
    if (json == null) {
      showAppSnackBar(
        context,
        userProv.error ?? 'Could not gather your data.',
        isError: true,
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      'Copied to your clipboard. Paste it into a note or file to keep it safe.',
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final userProv = context.read<UserProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final deleted = await showGlassFormSheet(
      context,
      title: 'Delete Account',
      subtitle: 'This permanently deletes your account and everything in it: '
          'documents, saved accounts, trusted people and your photo. It '
          'cannot be undone.',
      submitLabel: 'Delete Everything',
      fields: [
        GlassFormField(
          key: 'confirm',
          label: 'Type DELETE to confirm',
          hint: 'DELETE',
          validator: (v) => v.trim() == 'DELETE' ? null : 'Type DELETE exactly',
        ),
      ],
      onSubmit: (values) async {
        final ok = await userProv.deleteAccount();
        return ok ? null : userProv.error ?? 'Could not delete your account.';
      },
    );

    if (deleted) {
      navigator.pushNamedAndRemoveUntil(AppRouter.welcome, (route) => false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    }
  }

  // ── Support / About ─────────────────────────────────────────────────────────

  Future<void> _open(BuildContext context, Uri? uri) async {
    if (uri == null) return;
    final opened = await openExternal(uri);
    if (!opened && context.mounted) {
      showAppSnackBar(context, 'Couldn\'t open that link.', isError: true);
    }
  }

  void _about(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: appName,
      applicationVersion: appVersion,
      applicationLegalese: 'A digital legacy vault.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final user = userProv.user;
    final email = userProv.displayEmail.isNotEmpty
        ? userProv.displayEmail
        : 'Not set';
    final phone = (user?.phone?.isNotEmpty ?? false) ? user!.phone! : 'Not set';

    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassPageHeader(title: 'Settings', showBackButton: true),
          const SizedBox(height: 22),
          _buildSection('ACCOUNT', [
            GlassListRow(
              label: 'Email',
              subtitle: (user?.emailVerified ?? true) ? email : '$email · Not confirmed',
              onTap: () => _changeEmail(context),
            ),
            GlassListRow(
              label: 'Password',
              subtitle: 'Change your password',
              onTap: () => showChangePasswordSheet(context),
            ),
            GlassListRow(
              label: 'Phone',
              subtitle: phone,
              onTap: () => showPhoneEditSheet(context),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection('YOUR DATA', [
            GlassListRow(
              label: 'Download My Data',
              subtitle: 'Copy everything in your account as JSON',
              onTap: () => _exportData(context),
            ),
          ]),
          if (AppLinks.hasSupport) ...[
            const SizedBox(height: 20),
            _buildSection('SUPPORT', [
              if (AppLinks.hasHelp)
                GlassListRow(
                  label: 'Help Center',
                  subtitle: 'Guides and FAQs',
                  onTap: () => _open(context, AppLinks.webUri(AppLinks.helpUrl)),
                ),
              if (AppLinks.hasContact)
                GlassListRow(
                  label: 'Contact Us',
                  subtitle: AppLinks.supportEmail,
                  onTap: () => _open(context, AppLinks.contactUri),
                ),
            ]),
          ],
          const SizedBox(height: 20),
          _buildSection('ABOUT', [
            if (AppLinks.termsUrl.isNotEmpty)
              GlassListRow(
                label: 'Terms of Service',
                onTap: () => _open(context, AppLinks.webUri(AppLinks.termsUrl)),
              ),
            if (AppLinks.privacyUrl.isNotEmpty)
              GlassListRow(
                label: 'Privacy Policy',
                onTap: () => _open(context, AppLinks.webUri(AppLinks.privacyUrl)),
              ),
            GlassListRow(
              label: 'About $appName',
              subtitle: 'Version $appVersion',
              onTap: () => _about(context),
            ),
          ]),
          const SizedBox(height: 24),
          GlassOutlineButton(
            text: 'Log Out',
            onPressed: () => signOutAndReturnToWelcome(context),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => _deleteAccount(context),
              child: Text(
                'Delete Account',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.glassDestructive,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.glassDestructive,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String label, List<GlassListRow> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.overline.copyWith(
            color: AppColors.glassOnSurfaceFaint,
          ),
        ),
        const SizedBox(height: 10),
        GlassListCard(rows: rows),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/providers/auth_provider.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/widgets/glass/glass_list_row.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final email = userProv.displayEmail.isNotEmpty
        ? userProv.displayEmail
        : 'sarah.mitchell@editorial.com';
    final phone = userProv.user?.phone ?? '+1 (555) 123-4567';

    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassPageHeader(title: 'Settings', showBackButton: true),
          const SizedBox(height: 22),
          _buildSection('ACCOUNT', [
            GlassListRow(
              label: 'Email',
              subtitle: email,
              onTap: () {},
            ),
            GlassListRow(
              label: 'Password',
              subtitle: 'Last changed 3 months ago',
              onTap: () => Navigator.of(context).pushNamed(AppRouter.security),
            ),
            GlassListRow(
              label: 'Phone Verification',
              subtitle: phone,
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection('PRIVACY', [
            GlassListRow(
              label: 'Data Sharing',
              subtitle: 'Manage third-party sharing',
              onTap: () {},
            ),
            GlassListRow(
              label: 'Visibility',
              subtitle: 'Who can find your profile',
              onTap: () {},
            ),
            GlassListRow(
              label: 'Download My Data',
              subtitle: 'Export a copy of your data',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection('NOTIFICATIONS', [
            GlassListRow(
              label: 'Email Alerts',
              subtitle: 'Security and activity emails',
              onTap: () {},
            ),
            GlassListRow(
              label: 'Push Notifications',
              subtitle: 'On this device',
              onTap: () {},
            ),
            GlassListRow(
              label: 'Message Reminders',
              subtitle: 'Scheduled letter reminders',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection('SUPPORT', [
            GlassListRow(
              label: 'Help Center',
              subtitle: 'Guides and FAQs',
              onTap: () {},
            ),
            GlassListRow(
              label: 'Contact Us',
              subtitle: 'Get in touch with our team',
              onTap: () {},
            ),
            GlassListRow(label: 'FAQ', onTap: () {}),
          ]),
          const SizedBox(height: 20),
          _buildSection('ABOUT', [
            GlassListRow(label: 'Terms of Service', onTap: () {}),
            GlassListRow(label: 'Privacy Policy', onTap: () {}),
            GlassListRow(
              label: 'About Everkeep',
              subtitle: 'Version 1.0.0',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),
          GlassOutlineButton(
            text: 'Log Out',
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.welcome,
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () {},
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

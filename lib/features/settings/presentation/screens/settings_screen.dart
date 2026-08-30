import 'package:flutter/material.dart';
import 'package:everkeep/core/routing/app_router.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
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
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassPageHeader(title: 'Settings', showBackButton: true),
          const SizedBox(height: 22),
          _buildSection('ACCOUNT', [
            const GlassListRow(label: 'Email', subtitle: 'sarah.mitchell@editorial.com'),
            const GlassListRow(label: 'Password', subtitle: 'Last changed 3 months ago'),
            const GlassListRow(label: 'Phone Verification', subtitle: '+1 (555) 123-4567'),
          ]),
          const SizedBox(height: 20),
          _buildSection('PRIVACY', [
            const GlassListRow(label: 'Data Sharing', subtitle: 'Manage third-party sharing'),
            const GlassListRow(label: 'Visibility', subtitle: 'Who can find your profile'),
            const GlassListRow(label: 'Download My Data', subtitle: 'Export a copy of your data'),
          ]),
          const SizedBox(height: 20),
          _buildSection('NOTIFICATIONS', [
            const GlassListRow(label: 'Email Alerts', subtitle: 'Security and activity emails'),
            const GlassListRow(label: 'Push Notifications', subtitle: 'On this device'),
            const GlassListRow(label: 'Message Reminders', subtitle: 'Scheduled letter reminders'),
          ]),
          const SizedBox(height: 20),
          _buildSection('SUPPORT', [
            const GlassListRow(label: 'Help Center', subtitle: 'Guides and FAQs'),
            const GlassListRow(label: 'Contact Us', subtitle: 'Get in touch with our team'),
            const GlassListRow(label: 'FAQ'),
          ]),
          const SizedBox(height: 20),
          _buildSection('ABOUT', [
            const GlassListRow(label: 'Terms of Service'),
            const GlassListRow(label: 'Privacy Policy'),
            const GlassListRow(label: 'About Everkeep', subtitle: 'Version 1.0.0'),
          ]),
          const SizedBox(height: 24),
          GlassOutlineButton(
            text: 'Log Out',
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRouter.welcome,
              (route) => false,
            ),
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

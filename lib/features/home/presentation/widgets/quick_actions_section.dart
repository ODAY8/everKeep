import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/pick_upload.dart';
import '../../../../models/account_item.dart';
import '../../../../models/memory_item.dart';
import '../../../../providers/account_provider.dart';
import '../../../../providers/memory_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_sheet.dart';
import '../../../documents/presentation/widgets/document_form_sheet.dart';

/// Quick actions on the EverKeep Dashboard:
/// + Add Document, + Add Memory, + Add Important Information
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  static const List<String> _accountCategories = [
    'Banking',
    'Social',
    'Work',
    'Other',
  ];

  // ── Add Document ────────────────────────────────────────────────────────────

  Future<void> _chooseHowToAddDocument(BuildContext context) async {
    showGlassActionSheet(
      context,
      title: 'Add Document',
      subtitle: 'Store a file securely, or keep a record in your vault.',
      actions: [
        GlassSheetAction(
          label: 'Choose a file',
          icon: Icons.upload_file_rounded,
          onTap: () async {
            try {
              final upload = await pickDocument();
              if (upload != null && context.mounted) {
                final saved = await DocumentFormSheet.show(
                  context,
                  initialUpload: upload,
                );
                if (saved == true && context.mounted) {
                  showAppSnackBar(context, 'Document uploaded to your vault');
                }
              }
            } on PickedTooLarge catch (e) {
              if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
            } catch (_) {
              if (context.mounted) {
                showAppSnackBar(
                  context,
                  'Couldn\'t read that file. Try another one.',
                  isError: true,
                );
              }
            }
          },
        ),
        GlassSheetAction(
          label: 'Add without a file',
          icon: Icons.edit_note_rounded,
          onTap: () async {
            final saved = await DocumentFormSheet.show(context);
            if (saved == true && context.mounted) {
              showAppSnackBar(context, 'Document added to your vault');
            }
          },
        ),
      ],
    );
  }

  // ── Add Memory ──────────────────────────────────────────────────────────────

  Future<void> _addMemory(BuildContext context) async {
    final memoryProv = context.read<MemoryProvider>();

    final saved = await showGlassFormSheet(
      context,
      title: 'Add Memory',
      subtitle: 'Preserve a story, moment, or milestone.',
      submitLabel: 'Save Memory',
      fields: [
        const GlassFormField(
          key: 'title',
          label: 'Title',
          hint: 'e.g. First day at university',
        ),
        const GlassFormField(
          key: 'content',
          label: 'Story / Notes',
          hint: 'What happened...',
          required: false,
          minLines: 3,
          maxLines: 6,
        ),
      ],
      dateFields: const [
        GlassFormDateField(key: 'date', label: 'Date (optional)'),
      ],
      onSubmit: (values) async {
        final title = values['title']!;
        final content = values['content'] ?? '';
        final dateStr = values['date'];
        final date = dateStr != null && dateStr.isNotEmpty
            ? DateTime.tryParse(dateStr)
            : null;

        final ok = await memoryProv.createMemory(
          MemoryItem(
            id: '',
            title: title,
            content: content,
            type: 'memory',
            date: date,
          ),
        );
        return ok ? null : memoryProv.error ?? 'Could not save memory.';
      },
    );

    if (saved && context.mounted) {
      showAppSnackBar(context, 'Memory saved to your vault');
    }
  }

  // ── Add Important Information ───────────────────────────────────────────────

  Future<void> _addAccount(BuildContext context) async {
    final accProv = context.read<AccountProvider>();

    final saved = await showGlassFormSheet(
      context,
      title: 'Add Important Information',
      subtitle: 'Save an account login or critical access record.',
      submitLabel: 'Save Record',
      fields: const [
        GlassFormField(
          key: 'title',
          label: 'Account or service name',
          hint: 'e.g. Fidelity, Gmail, Bank of America',
        ),
        GlassFormField(
          key: 'username',
          label: 'Username or email',
          hint: 'Optional identifier',
          required: false,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
      choices: const [
        GlassFormChoice(
          key: 'category',
          label: 'Category',
          options: _accountCategories,
        ),
      ],
      onSubmit: (values) async {
        final category = values['category']!;
        final username = values['username']!;
        final (icon, color) = AccountItem.styleFor(category);

        final ok = await accProv.addAccount(
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
        return ok ? null : accProv.error ?? 'Could not save account.';
      },
    );

    if (saved && context.mounted) {
      showAppSnackBar(context, 'Account saved to your vault');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.glassOnSurfaceFaint,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _QuickActionButton(
          icon: Icons.note_add_outlined,
          iconColor: AppColors.glassAccentSecondary,
          label: 'Add Document',
          subtitle: 'Upload files and track expiration dates',
          onTap: () => _chooseHowToAddDocument(context),
        ),
        const SizedBox(height: 10),
        _QuickActionButton(
          icon: Icons.favorite_outline_rounded,
          iconColor: AppColors.glassAccentPink,
          label: 'Add Memory',
          subtitle: 'Store photos, stories, and meaningful moments',
          onTap: () => _addMemory(context),
        ),
        const SizedBox(height: 10),
        _QuickActionButton(
          icon: Icons.key_rounded,
          iconColor: AppColors.glassAccentBlue,
          label: 'Add Important Information',
          subtitle: 'Secure logins, insurance, or account records',
          onTap: () => _addAccount(context),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: AppRadius.radiusLG,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: AppRadius.radiusMD,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.glassOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.glassBorder.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.glassOnSurface,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/document_expiration.dart';
import '../../../../models/document_item.dart';
import '../../../../widgets/glass/glass_primary_button.dart';

/// Polished bottom sheet displaying complete structured metadata, expiration
/// status, attached files, and vault management actions for a [DocumentItem].
class DocumentDetailsSheet extends StatelessWidget {
  final DocumentItem document;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenFile;

  const DocumentDetailsSheet({
    super.key,
    required this.document,
    required this.onEdit,
    required this.onDelete,
    this.onOpenFile,
  });

  static String _formatFriendlyDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = document.expirationStatus;
    final statusColor = DocumentExpirationHelper.colorFor(status);
    final statusBg = DocumentExpirationHelper.backgroundColorFor(status);

    final statusIcon = switch (status) {
      DocumentExpirationStatus.expired => Icons.warning_amber_rounded,
      DocumentExpirationStatus.expiringSoon => Icons.schedule_rounded,
      DocumentExpirationStatus.valid => Icons.check_circle_outline_rounded,
      DocumentExpirationStatus.noExpiryDate => Icons.remove_circle_outline_rounded,
    };

    final statusTitle = switch (status) {
      DocumentExpirationStatus.expired => 'Expired',
      DocumentExpirationStatus.expiringSoon => 'Expiring Soon',
      DocumentExpirationStatus.valid => 'Valid',
      DocumentExpirationStatus.noExpiryDate => 'No Expiry Date',
    };

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.glassBorder,
                    borderRadius: AppRadius.radiusPill,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Type badge & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurfaceRaised,
                      borderRadius: AppRadius.radiusPill,
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(document.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          document.displayType.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.glassAccentPink,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.glassOnSurfaceMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                document.title,
                style: AppTextStyles.serifTitleMedium.copyWith(
                  color: AppColors.glassOnSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),

              // Expiration Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: AppRadius.radiusMD,
                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            document.expirationNotice,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Metadata Details Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.glassSurfaceRaised,
                  borderRadius: AppRadius.radiusLG,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  children: [
                    if (document.documentNumber != null &&
                        document.documentNumber!.trim().isNotEmpty) ...[
                      _MetadataRow(
                        label: document.typeInfo.numberLabel,
                        value: document.documentNumber!,
                        icon: Icons.tag_rounded,
                      ),
                      const Divider(color: AppColors.glassBorder, height: 20),
                    ],
                    if (document.country != null &&
                        document.country!.trim().isNotEmpty) ...[
                      _MetadataRow(
                        label: document.typeInfo.countryLabel,
                        value: document.country!,
                        icon: Icons.public_rounded,
                      ),
                      const Divider(color: AppColors.glassBorder, height: 20),
                    ],
                    if (document.institution != null &&
                        document.institution!.trim().isNotEmpty) ...[
                      _MetadataRow(
                        label: document.typeInfo.institutionLabel,
                        value: document.institution!,
                        icon: Icons.account_balance_outlined,
                      ),
                      const Divider(color: AppColors.glassBorder, height: 20),
                    ],
                    if (document.issueDate != null) ...[
                      _MetadataRow(
                        label: 'Issue Date',
                        value: _formatFriendlyDate(document.issueDate!),
                        icon: Icons.event_available_outlined,
                      ),
                      const Divider(color: AppColors.glassBorder, height: 20),
                    ],
                    if (document.expiryDate != null) ...[
                      _MetadataRow(
                        label: 'Expiry Date',
                        value: _formatFriendlyDate(document.expiryDate!),
                        icon: Icons.schedule_rounded,
                        valueColor: statusColor,
                      ),
                      const Divider(color: AppColors.glassBorder, height: 20),
                    ],
                    _MetadataRow(
                      label: 'Category',
                      value: document.category,
                      icon: Icons.folder_open_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stored file box
              if (document.hasFile) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.glassAccentSecondaryBg,
                    borderRadius: AppRadius.radiusMD,
                    border: Border.all(
                      color: AppColors.glassAccentSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        color: AppColors.glassAccentSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document.filePath!.split('/').last,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.glassOnSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Private & encrypted in your personal vault',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.glassOnSurfaceMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onOpenFile != null)
                        TextButton(
                          onPressed: onOpenFile,
                          child: Text(
                            'Open',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.glassAccentPink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Notes section
              if (document.notes != null && document.notes!.trim().isNotEmpty) ...[
                Text(
                  'NOTES',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.glassOnSurfaceFaint,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurfaceRaised,
                    borderRadius: AppRadius.radiusMD,
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    document.notes!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.glassOnSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Buttons
              if (document.hasFile && onOpenFile != null) ...[
                GlassPrimaryButton(
                  text: 'Open File',
                  onPressed: onOpenFile,
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: GlassOutlineButton(
                      text: 'Edit',
                      onPressed: onEdit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: onDelete,
                      borderRadius: AppRadius.radiusPill,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.glassDestructive.withValues(alpha: 0.12),
                          borderRadius: AppRadius.radiusPill,
                          border: Border.all(
                            color: AppColors.glassDestructive.withValues(alpha: 0.4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Delete',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.glassDestructive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _MetadataRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.glassOnSurfaceMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            color: valueColor ?? AppColors.glassOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

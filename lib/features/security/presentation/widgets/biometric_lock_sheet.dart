import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/app_lock_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_card.dart';

/// Opens the Biometric Lock configuration bottom sheet.
Future<void> showBiometricLockSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.glassSurfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _BiometricLockSheetContent(),
  );
}

class _BiometricLockSheetContent extends StatelessWidget {
  const _BiometricLockSheetContent();

  @override
  Widget build(BuildContext context) {
    final lockProv = context.watch<AppLockProvider>();
    final biometricName = lockProv.biometricName;
    final biometricIcon = lockProv.biometricIcon;
    final isEnabled = lockProv.isEnabled;
    final currentTimeout = lockProv.lockTimeoutOption;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEnabled
                      ? AppColors.glassAccentGreen.withValues(alpha: 0.15)
                      : AppColors.glassSurface,
                ),
                child: Icon(
                  biometricIcon,
                  color: isEnabled
                      ? AppColors.glassAccentGreen
                      : AppColors.glassOnSurfaceMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biometric Lock',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.glassOnSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Protect your vault with $biometricName',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.glassOnSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Enable / Disable Toggle Card
          GlassCard(
            borderRadius: AppRadius.radiusXL,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Require $biometricName',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.glassOnSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Require biometric authentication when opening EverKeep.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: isEnabled,
                  activeTrackColor: AppColors.glassAccentGreen,
                  onChanged: lockProv.isAuthenticating
                      ? null
                      : (enable) async {
                          if (enable) {
                            final ok = await lockProv.enableBiometricLock();
                            if (!ok && context.mounted) {
                              final err = lockProv.errorMessage;
                              if (err != null) {
                                showAppSnackBar(context, err, isError: true);
                              }
                            }
                          } else {
                            final ok = await lockProv.disableBiometricLock();
                            if (!ok && context.mounted) {
                              final err = lockProv.errorMessage;
                              if (err != null) {
                                showAppSnackBar(context, err, isError: true);
                              }
                            }
                          }
                        },
                ),
              ],
            ),
          ),

          if (isEnabled) ...[
            const SizedBox(height: 22),
            Text(
              'LOCK TIMEOUT',
              style: AppTextStyles.overline.copyWith(
                color: AppColors.glassOnSurfaceFaint,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),

            GlassCard(
              borderRadius: AppRadius.radiusXL,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: LockTimeoutOption.values.map((option) {
                  final isSelected = currentTimeout == option;
                  return InkWell(
                    onTap: () => lockProv.setLockTimeout(option.duration),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 20,
                            color: isSelected
                                ? AppColors.glassAccentGreen
                                : AppColors.glassOnSurfaceFaint,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              option.label,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isSelected
                                    ? AppColors.glassOnSurface
                                    : AppColors.glassOnSurfaceMuted,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),
            // "Lock App Now" test button
            Center(
              child: TextButton.icon(
                icon: const Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: AppColors.glassAccentPink,
                ),
                label: Text(
                  'Lock app now',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.glassAccentPink,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  lockProv.lock();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

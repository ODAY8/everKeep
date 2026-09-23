import 'dart:async';

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/external_link.dart';

/// Shows a floating message in the glass style. Errors get a red outline.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.glassSurface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLG,
          side: BorderSide(
            color: isError ? AppColors.glassDestructive : AppColors.glassBorder,
          ),
        ),
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurface,
          ),
        ),
      ),
    );
}

/// Asks the user to confirm a destructive action. Resolves to true only if
/// they explicitly confirm; dismissing the dialog counts as cancelling.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.glassSurface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
      title: Text(
        title,
        style: AppTextStyles.titleMedium.copyWith(
          color: AppColors.glassOnSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.glassOnSurfaceMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Cancel',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.glassDestructive,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Centered spinner for a list that is loading for the first time.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(color: AppColors.glassAccentPink),
      ),
    );
  }
}

/// Shown in place of a list whose first load failed, with a way to retry.
class ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.glassOnSurfaceFaint,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.glassDestructive,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.glassAccentPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fetches a short-lived link to a stored file and opens it externally —
/// whichever browser or app on the device handles it (Android/iOS show their
/// own chooser when more than one can).
///
/// A signed-URL fetch is a network round trip; on a slow connection a tap
/// that does nothing for a second or two reads as broken. This shows a small
/// "Opening…" indicator, but only once the fetch has actually taken a
/// moment, so a fast response never flashes it on and straight back off.
Future<void> openRemoteFile(
  BuildContext context, {
  required Future<String?> Function() fetchUrl,
  required String? Function() errorMessage,
}) async {
  var dialogShown = false;
  final showTimer = Timer(const Duration(milliseconds: 350), () {
    if (!context.mounted) return;
    dialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _OpeningDialog(),
    );
  });

  String? url;
  try {
    url = await fetchUrl();
  } finally {
    showTimer.cancel();
    if (dialogShown && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
  if (!context.mounted) return;

  if (url == null) {
    showAppSnackBar(context, errorMessage() ?? 'Could not open the file.', isError: true);
    return;
  }

  final opened = await openExternal(Uri.parse(url));
  if (!opened && context.mounted) {
    showAppSnackBar(context, 'No app on this device can open that file.', isError: true);
  }
}

class _OpeningDialog extends StatelessWidget {
  const _OpeningDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.glassSurface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.glassAccentPink,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Opening…',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.glassOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

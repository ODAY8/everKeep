import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/greeting.dart';
import '../../../../providers/user_provider.dart';
import '../../../../widgets/profile_avatar.dart';

/// The top header on the EverKeep Dashboard:
/// Greeting, user name, EverKeep tagline, and user profile avatar.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${greetingFor(DateTime.now())},',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurfaceMuted,
                ),
              ),
              const SizedBox(height: 2),
              Selector<UserProvider, String>(
                selector: (_, userProv) => userProv.firstName,
                builder: (context, firstName, _) {
                  return Text(
                    firstName.isNotEmpty ? firstName : 'EverKeep',
                    style: AppTextStyles.serifHeadline.copyWith(
                      color: AppColors.glassOnSurface,
                      fontSize: 26,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                'EverKeep · Your personal life vault',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.glassOnSurfaceFaint,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Selector<UserProvider, String?>(
          selector: (_, userProv) => userProv.user?.avatarUrl,
          builder: (context, avatarUrl, _) {
            return GestureDetector(
              onTap: () => Navigator.of(context).pushNamed(AppRouter.profile),
              behavior: HitTestBehavior.opaque,
              child: ProfileAvatar(
                url: avatarUrl,
                size: 48,
                borderColor: AppColors.glassBorder,
                borderWidth: 1.5,
              ),
            );
          },
        ),
      ],
    );
  }
}

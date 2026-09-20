import 'package:flutter/material.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/widgets/glass/glass_card.dart';
import 'package:everkeep/widgets/glass/glass_page_header.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_scaffold.dart';

class EmergencyAccessScreen extends StatefulWidget {
  const EmergencyAccessScreen({super.key});

  @override
  State<EmergencyAccessScreen> createState() => _EmergencyAccessScreenState();
}

class _EmergencyAccessScreenState extends State<EmergencyAccessScreen> {
  int _currentStep = 0; // 0: Setup, 1: Verify, 2: Complete

  final List<Map<String, dynamic>> _steps = const [
    {
      'title': 'Set Up Emergency Access',
      'subtitle': 'Choose trusted contacts who can request access',
      'icon': Icons.person_add_rounded,
      'color': AppColors.glassAccentPink,
    },
    {
      'title': 'Verify Identity',
      'subtitle': 'Confirm your identity for security',
      'icon': Icons.verified_user_rounded,
      'color': AppColors.glassAccentBlue,
    },
    {
      'title': 'Access Granted',
      'subtitle': 'Your legacy is now accessible in emergencies',
      'icon': Icons.check_circle_rounded,
      'color': AppColors.glassAccentGreen,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassPageHeader(
            title: 'Emergency Access',
            subtitle: 'Set up legacy access for trusted contacts',
            showBackButton: true,
          ),
          const SizedBox(height: 24),
          _buildProgressIndicator(),
          const SizedBox(height: 24),
          _buildStepContent(),
          const SizedBox(height: 28),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_steps.length, (index) {
            final isActive = index == _currentStep;
            final isCompleted = index < _currentStep;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 10,
              height: 8,
              decoration: BoxDecoration(
                gradient: (isActive || isCompleted) ? AppColors.glassAccentGradient : null,
                color: (isActive || isCompleted) ? null : AppColors.glassSurfaceRaised,
                borderRadius: AppRadius.radiusPill,
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(
          _steps[_currentStep]['title'] as String,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.glassOnSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _steps[_currentStep]['subtitle'] as String,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildSetupStep();
      case 1:
        return _buildVerifyStep();
      case 2:
        return _buildCompleteStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepIcon(int index) {
    final color = _steps[index]['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(_steps[index]['icon'] as IconData, color: color, size: 44),
    );
  }

  Widget _buildSetupStep() {
    return Column(
      children: [
        _buildStepIcon(0),
        const SizedBox(height: 20),
        Text(
          'Choose trusted contacts who can request access to your legacy in case of emergency.',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildContactsPreview([
          {'name': 'Sarah Johnson', 'relationship': 'Spouse'},
          {'name': 'Michael Chen', 'relationship': 'Attorney'},
        ]),
      ],
    );
  }

  Widget _buildVerifyStep() {
    return Column(
      children: [
        _buildStepIcon(1),
        const SizedBox(height: 20),
        Text(
          'Verify your identity to ensure only you can set up emergency access.',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: AppRadius.radiusPill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.glassOnSurfaceFaint, size: 20),
              const SizedBox(width: 10),
              Text(
                'Enter your password',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurfaceFaint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint_rounded, size: 22, color: AppColors.glassAccentBlue),
            const SizedBox(width: 8),
            Text(
              'Use Touch ID or Face ID',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.glassOnSurface),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompleteStep() {
    return Column(
      children: [
        _buildStepIcon(2),
        const SizedBox(height: 20),
        Text(
          'Emergency access has been successfully set up!',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.glassOnSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your trusted contacts can now request access to your legacy in case of emergency.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildWhatHappensNext(),
      ],
    );
  }

  Widget _buildContactsPreview(List<Map<String, String>> contacts) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: contacts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return SizedBox(
            width: 108,
            child: GlassCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_rounded, size: 22, color: AppColors.glassAccentPink),
                  const SizedBox(height: 6),
                  Text(
                    contact['name']!,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.glassOnSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    contact['relationship']!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.glassOnSurfaceMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWhatHappensNext() {
    final items = const [
      {'icon': Icons.request_page_rounded, 'title': 'Request Made', 'description': 'Contact requests access'},
      {'icon': Icons.hourglass_empty_rounded, 'title': 'Waiting Period', 'description': 'You have time to respond'},
      {'icon': Icons.check_circle_rounded, 'title': 'Access Granted', 'description': 'Shared if no response'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What happens next?',
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.glassOnSurface,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 108,
                child: GlassCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item['icon'] as IconData, size: 22, color: AppColors.glassAccentBlue),
                      const SizedBox(height: 6),
                      Text(
                        item['title'] as String,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.glassOnSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        item['description'] as String,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: GlassOutlineButton(
              text: 'Previous',
              onPressed: () => setState(() => _currentStep--),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: GlassPrimaryButton(
            text: _currentStep < _steps.length - 1 ? 'Next' : 'Get Started',
            onPressed: () {
              if (_currentStep < _steps.length - 1) {
                setState(() => _currentStep++);
              } else {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ),
      ],
    );
  }
}

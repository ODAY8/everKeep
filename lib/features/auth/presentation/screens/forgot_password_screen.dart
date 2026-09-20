import 'package:flutter/material.dart';
import '../../../../core/config/app_image_urls.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../widgets/app_network_image.dart';
import '../../../../widgets/circular_icon_button.dart';
import '../../../../widgets/glass/frosted_glass_card.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../../../widgets/glass/glass_text_field.dart';

/// Password recovery screen matching the aesthetic of SignIn and SignUp.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  bool _submitted = false;

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  void _submit() {
    final email = _emailController.text.trim();
    setState(() {
      _emailError = email.isEmpty
          ? 'Email is required'
          : !_isValidEmail(email)
          ? 'Enter a valid email address'
          : null;
    });

    if (_emailError == null) {
      setState(() {
        _submitted = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.glassBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppNetworkImage(
            url: AppImageUrls.loginBackground,
            fallbackIcon: Icons.forest_rounded,
          ),
          Container(color: Colors.black.withValues(alpha: 0.7)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: CircularIconButton(
                      icon: Icons.arrow_back_rounded,
                      background: AppColors.glassSurface,
                      foreground: AppColors.glassOnSurface,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 80),
                  FrostedGlassCard(
                    child: _submitted ? _buildSuccessView() : _buildFormView(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset Password',
          style: AppTextStyles.serifHeadline.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your registered email address and we will send you a link to reset your vault credentials.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        GlassTextField(
          controller: _emailController,
          label: 'Email Address',
          hintText: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          errorText: _emailError,
        ),
        const SizedBox(height: 24),
        GlassPrimaryButton(text: 'Send Reset Link', onPressed: _submit),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Back to Sign In',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.glassOnSurfaceMuted,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.glassOnSurfaceMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: AppColors.glassSuccessBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: AppColors.glassAccentGreen,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Instructions Sent',
          style: AppTextStyles.serifHeadline.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'If an account exists for ${_emailController.text.trim()}, you will receive recovery instructions shortly.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.glassOnSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        GlassPrimaryButton(
          text: 'Return to Sign In',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

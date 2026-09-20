import 'package:flutter/material.dart';
import '../../../../core/config/app_image_urls.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../widgets/app_network_image.dart';
import '../../../../widgets/circular_icon_button.dart';
import '../../../../widgets/glass/frosted_glass_card.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../../../widgets/glass/glass_text_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$').hasMatch(email);

  void _submit() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    setState(() {
      _nameError = name.isEmpty ? 'Full name is required' : null;

      _emailError = email.isEmpty
          ? 'Email is required'
          : !_isValidEmail(email)
          ? 'Enter a valid email address'
          : null;

      _passwordError = password.isEmpty
          ? 'Password is required'
          : password.length < 6
          ? 'Password must be at least 6 characters'
          : null;

      _confirmError = confirm.isEmpty
          ? 'Please confirm your password'
          : confirm != password
          ? 'Passwords do not match'
          : null;
    });

    if (_nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmError == null) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
    }
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
                  const SizedBox(height: 40),
                  FrostedGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create Account',
                          style: AppTextStyles.serifHeadline.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start protecting your digital legacy',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.glassOnSurfaceMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        GlassTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hintText: 'Sarah Mitchell',
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          errorText: _nameError,
                        ),
                        const SizedBox(height: 16),
                        GlassTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hintText: 'you@example.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          errorText: _emailError,
                        ),
                        const SizedBox(height: 16),
                        GlassTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hintText: '••••••••',
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          suffixIcon: _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          errorText: _passwordError,
                        ),
                        const SizedBox(height: 16),
                        GlassTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hintText: '••••••••',
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          suffixIcon: _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          errorText: _confirmError,
                        ),
                        const SizedBox(height: 24),
                        GlassPrimaryButton(
                          text: 'Create Account',
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRouter.signIn),
                        child: Text(
                          'Sign In',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.glassAccentPink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

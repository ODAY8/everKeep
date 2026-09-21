import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/app_image_urls.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/app_network_image.dart';
import '../../../../widgets/circular_icon_button.dart';
import '../../../../widgets/glass/frosted_glass_card.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../../../widgets/glass/glass_text_field.dart';

/// Full-bleed background photo behind a frosted glass sign-in card,
/// matching the Figma login frame.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
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
    });

    if (_emailError == null && _passwordError == null) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.signIn(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                  const SizedBox(height: 100),
                  FrostedGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome Back',
                          style: AppTextStyles.serifHeadline.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Access your protected digital vault',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.glassOnSurfaceMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
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
                          textInputAction: TextInputAction.done,
                          suffixIcon: _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          errorText: _passwordError,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pushNamed(AppRouter.forgotPassword),
                            child: Text(
                              'Forgot password?',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.glassAccentPink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Selector<AuthProvider, String?>(
                          selector: (_, auth) => auth.error,
                          builder: (context, authError, _) {
                            if (authError == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                authError,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.glassDestructive,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                        Selector<AuthProvider, bool>(
                          selector: (_, auth) => auth.isLoading,
                          builder: (context, isLoading, _) {
                            return GlassPrimaryButton(
                              text: isLoading ? 'Signing In...' : 'Sign In',
                              onPressed: isLoading ? null : _submit,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Biometric authentication is not configured yet.',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.glassSurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.glassBorder,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.fingerprint_rounded,
                                    color: AppColors.glassAccentPink,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Sign in with Face ID',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.glassOnSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRouter.signUp),
                        child: Text(
                          'Sign Up',
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

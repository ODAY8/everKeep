import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/app_image_urls.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/app_network_image.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/frosted_glass_card.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import '../../../../widgets/glass/glass_text_field.dart';

/// Shown when someone opens the link in a password-reset email: they choose a
/// new password, then sign in with it.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final AuthProvider _auth;

  bool _obscure = true;
  String? _passwordError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    // Deferred a frame because clearing notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _auth.clearError();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _passwordError = validatePassword(password);
      _confirmError = confirm.isEmpty
          ? 'Please confirm your password'
          : confirm != password
          ? 'Passwords do not match'
          : null;
    });
    if (_passwordError != null || _confirmError != null) return;

    final saved = await _auth.updatePassword(password);
    if (!mounted || !saved) return;

    // The reset link signed the user in only so they could set a password. End
    // that session and have them sign in with the new one.
    await _auth.signOut();
    if (!mounted) return;
    showAppSnackBar(context, 'Password updated. Sign in with your new password.');
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.signIn,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Leaving without choosing a password abandons the reset.
        if (didPop) _auth.dismissRecovery();
      },
      child: Scaffold(
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
                padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
                child: FrostedGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Choose a New Password',
                        style: AppTextStyles.serifHeadline.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick something you haven\'t used before. You\'ll sign in with it next.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      GlassTextField(
                        controller: _passwordController,
                        label: 'New Password',
                        hintText: '••••••••',
                        obscureText: _obscure,
                        suffixIcon: _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        onSuffixTap: () => setState(() => _obscure = !_obscure),
                        errorText: _passwordError,
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        controller: _confirmController,
                        label: 'Confirm Password',
                        hintText: '••••••••',
                        obscureText: _obscure,
                        errorText: _confirmError,
                      ),
                      const SizedBox(height: 16),
                      Selector<AuthProvider, String?>(
                        selector: (_, auth) => auth.error,
                        builder: (context, authError, _) {
                          if (authError == null) return const SizedBox.shrink();
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
                            text: isLoading ? 'Saving...' : 'Save New Password',
                            onPressed: isLoading ? null : _submit,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

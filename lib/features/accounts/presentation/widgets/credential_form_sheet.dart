import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/security/password_strength.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/account_item.dart';
import '../../../../providers/account_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import 'password_generator_sheet.dart';
import 'password_strength_bar.dart';

const List<String> credentialCategories = [
  'Banking',
  'Social',
  'Work',
  'Personal',
  'Other',
];

/// Displays the glass form sheet for creating or editing a vault credential.
Future<bool> showCredentialFormSheet(
  BuildContext context, {
  AccountItem? existing,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => _CredentialFormSheet(existing: existing),
  );
  return result ?? false;
}

class _CredentialFormSheet extends StatefulWidget {
  final AccountItem? existing;

  const _CredentialFormSheet({this.existing});

  @override
  State<_CredentialFormSheet> createState() => _CredentialFormSheetState();
}

class _CredentialFormSheetState extends State<_CredentialFormSheet> {
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _passwordController = TextEditingController();
  final _notesController = TextEditingController();

  late String _selectedCategory;
  bool _isPasswordRevealed = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  PasswordStrength _strength = PasswordStrength.empty;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _usernameController.text = existing.username ?? '';
      _websiteController.text = existing.website ?? '';
      _notesController.text = existing.notes ?? '';
      _selectedCategory = existing.category;

      // Pre-decrypt password if present
      if (existing.hasPassword) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final auth = context.read<AuthProvider>();
          final userId = auth.currentUser?.id ?? '';
          if (userId.isNotEmpty) {
            final accProv = context.read<AccountProvider>();
            final decrypted = await accProv.getDecryptedPassword(existing, userId: userId);
            if (decrypted != null && mounted) {
              setState(() {
                _passwordController.text = decrypted;
                _strength = PasswordStrengthChecker.evaluate(decrypted);
              });
            }
          }
        });
      }
    } else {
      _selectedCategory = credentialCategories.first;
    }

    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {
      _strength = PasswordStrengthChecker.evaluate(_passwordController.text);
    });
  }

  @override
  void dispose() {
    // Explicitly zero-out and clear password from memory on disposal
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.clear();
    _passwordController.dispose();
    _titleController.dispose();
    _usernameController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openGenerator() async {
    final generated = await showPasswordGeneratorSheet(
      context,
      onSelectPassword: (pwd) {
        _passwordController.text = pwd;
        _passwordController.selection = TextSelection.fromPosition(
          TextPosition(offset: pwd.length),
        );
      },
    );
    if (generated != null && mounted) {
      _passwordController.text = generated;
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a service or account name.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';
    if (userId.isEmpty) {
      setState(() => _errorMessage = 'You must be signed in to save credentials.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final accProv = context.read<AccountProvider>();
    final isEditing = widget.existing != null;
    final passwordText = _passwordController.text.trim();

    bool ok = false;
    try {
      if (isEditing) {
        ok = await accProv.updateCredential(
          account: widget.existing!,
          newTitle: title,
          newUsername: _usernameController.text.trim(),
          newWebsite: _websiteController.text.trim(),
          newCategory: _selectedCategory,
          newNotes: _notesController.text.trim(),
          newPassword: passwordText.isNotEmpty ? passwordText : null,
          removePassword: passwordText.isEmpty && widget.existing!.hasPassword,
          userId: userId,
        );
      } else {
        ok = await accProv.addCredential(
          title: title,
          username: _usernameController.text.trim(),
          website: _websiteController.text.trim(),
          password: passwordText.isNotEmpty ? passwordText : null,
          category: _selectedCategory,
          notes: _notesController.text.trim(),
          userId: userId,
        );
      }
    } catch (e) {
      ok = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      showAppSnackBar(
        context,
        isEditing ? 'Credential updated' : 'Credential saved securely to vault',
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = accProv.error ?? _errorMessage ?? 'Failed to save credential.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 1.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.glassOnSurfaceFaint,
                  borderRadius: AppRadius.radiusPill,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.glassAccentBlue.withValues(alpha: 0.16),
                    borderRadius: AppRadius.radiusMD,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.glassAccentBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Credential' : 'Add Credential',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.glassOnSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Stored securely with on-device client encryption',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.glassOnSurfaceMuted),
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Error banner if any
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.glassDestructive.withValues(alpha: 0.15),
                  borderRadius: AppRadius.radiusSM,
                  border: Border.all(color: AppColors.glassDestructive.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.glassDestructive, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.glassDestructive),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Field: Service / Account Name
            _buildFieldLabel('Service or Account Name *'),
            _buildTextField(
              controller: _titleController,
              hint: 'e.g. Google, GitHub, Chase Bank',
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 14),

            // Field: Username / Email
            _buildFieldLabel('Username or Email'),
            _buildTextField(
              controller: _usernameController,
              hint: 'e.g. alex@example.com',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),

            // Field: Website
            _buildFieldLabel('Website URL'),
            _buildTextField(
              controller: _websiteController,
              hint: 'https://...',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),

            // Field: Password with reveal & generator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFieldLabel('Password'),
                GestureDetector(
                  onTap: _openGenerator,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.glassAccentBlue,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Generate',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.glassAccentBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: AppRadius.radiusMD,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _passwordController,
                obscureText: !_isPasswordRevealed,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurface,
                  fontFamily: _isPasswordRevealed ? 'monospace' : null,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.key_rounded, color: AppColors.glassOnSurfaceMuted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordRevealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.glassOnSurfaceMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _isPasswordRevealed = !_isPasswordRevealed),
                  ),
                  hintText: isEditing ? 'Leave blank to keep existing password' : 'Enter or generate password',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.glassOnSurfaceFaint),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            PasswordStrengthBar(strength: _strength),
            const SizedBox(height: 14),

            // Category selector
            _buildFieldLabel('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: credentialCategories.map((category) {
                final isSelected = _selectedCategory == category;
                final (icon, color) = AccountItem.styleFor(category);
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.22)
                          : AppColors.glassSurface,
                      borderRadius: AppRadius.radiusSM,
                      border: Border.all(
                        color: isSelected ? color : AppColors.glassBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: isSelected ? color : AppColors.glassOnSurfaceMuted),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isSelected ? AppColors.glassOnSurface : AppColors.glassOnSurfaceMuted,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Field: Notes
            _buildFieldLabel('Notes'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: AppRadius.radiusMD,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.glassOnSurface),
                decoration: InputDecoration(
                  hintText: 'Optional instructions, PIN, or recovery details',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.glassOnSurfaceFaint),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            GlassPrimaryButton(
              text: isEditing ? 'Save Changes' : 'Save to Vault',
              onPressed: _isSubmitting ? null : _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.glassOnSurfaceMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.glassOnSurface),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.glassOnSurfaceMuted, size: 20),
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.glassOnSurfaceFaint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

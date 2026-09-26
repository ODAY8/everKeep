import 'package:flutter/material.dart';
import '../../../../core/security/clipboard_safety_manager.dart';
import '../../../../core/security/password_generator.dart';
import '../../../../core/security/password_strength.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_primary_button.dart';
import 'password_strength_bar.dart';

/// Opens an interactive glass sheet to generate strong, cryptographically secure passwords.
Future<String?> showPasswordGeneratorSheet(
  BuildContext context, {
  void Function(String password)? onSelectPassword,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => _PasswordGeneratorSheet(onSelectPassword: onSelectPassword),
  );
}

class _PasswordGeneratorSheet extends StatefulWidget {
  final void Function(String password)? onSelectPassword;

  const _PasswordGeneratorSheet({this.onSelectPassword});

  @override
  State<_PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<_PasswordGeneratorSheet> {
  int _length = 16;
  bool _includeUpper = true;
  bool _includeLower = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;

  late String _generatedPassword;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    setState(() {
      _generatedPassword = PasswordGenerator.generate(
        length: _length,
        includeUppercase: _includeUpper,
        includeLowercase: _includeLower,
        includeNumbers: _includeNumbers,
        includeSymbols: _includeSymbols,
      );
    });
  }

  Future<void> _copyPassword() async {
    await ClipboardSafetyManager.instance.copySensitiveText(_generatedPassword);
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Password copied. Clipboard auto-clearing in 30s.',
    );
  }

  void _usePassword() {
    widget.onSelectPassword?.call(_generatedPassword);
    Navigator.of(context).pop(_generatedPassword);
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthChecker.evaluate(_generatedPassword);

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
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.glassAccentBlue,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Password Generator',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.glassOnSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.glassOnSurfaceMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Generated password display container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.glassSurface,
              borderRadius: AppRadius.radiusMD,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _generatedPassword,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.glassOnSurface,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.glassAccentBlue),
                      tooltip: 'Generate new',
                      onPressed: _regenerate,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.glassOnSurfaceMuted),
                      tooltip: 'Copy password',
                      onPressed: _copyPassword,
                    ),
                  ],
                ),
                PasswordStrengthBar(strength: strength),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Length Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Length',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$_length characters',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassAccentBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.glassAccentBlue,
              inactiveTrackColor: AppColors.glassBorder,
              thumbColor: AppColors.glassAccentBlue,
              overlayColor: AppColors.glassAccentBlue.withValues(alpha: 0.16),
            ),
            child: Slider(
              value: _length.toDouble(),
              min: 8,
              max: 32,
              divisions: 24,
              onChanged: (val) {
                setState(() => _length = val.round());
                _regenerate();
              },
            ),
          ),
          const SizedBox(height: 10),

          // Options Toggles
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOptionChip(
                label: 'A-Z',
                isSelected: _includeUpper,
                onTap: () {
                  setState(() => _includeUpper = !_includeUpper);
                  _regenerate();
                },
              ),
              _buildOptionChip(
                label: 'a-z',
                isSelected: _includeLower,
                onTap: () {
                  setState(() => _includeLower = !_includeLower);
                  _regenerate();
                },
              ),
              _buildOptionChip(
                label: '0-9',
                isSelected: _includeNumbers,
                onTap: () {
                  setState(() => _includeNumbers = !_includeNumbers);
                  _regenerate();
                },
              ),
              _buildOptionChip(
                label: '!@#\$%',
                isSelected: _includeSymbols,
                onTap: () {
                  setState(() => _includeSymbols = !_includeSymbols);
                  _regenerate();
                },
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GlassOutlineButton(
                  text: 'Copy',
                  onPressed: _copyPassword,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassPrimaryButton(
                  text: 'Use Password',
                  onPressed: _usePassword,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.glassAccentBlue.withValues(alpha: 0.2)
              : AppColors.glassSurface,
          borderRadius: AppRadius.radiusSM,
          border: Border.all(
            color: isSelected ? AppColors.glassAccentBlue : AppColors.glassBorder,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? AppColors.glassOnSurface : AppColors.glassOnSurfaceMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

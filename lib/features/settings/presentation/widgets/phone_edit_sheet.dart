import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:provider/provider.dart';
import 'package:everkeep/core/theme/app_colors.dart';
import 'package:everkeep/core/theme/app_radius.dart';
import 'package:everkeep/core/theme/app_text_styles.dart';
import 'package:everkeep/core/utils/countries.dart';
import 'package:everkeep/providers/user_provider.dart';
import 'package:everkeep/widgets/feedback.dart';
import 'package:everkeep/widgets/glass/country_picker_sheet.dart';
import 'package:everkeep/widgets/glass/glass_primary_button.dart';
import 'package:everkeep/widgets/glass/glass_sheet.dart';
import 'package:everkeep/widgets/glass/glass_text_field.dart';

/// Lets the user set their phone number with a real country code, validated
/// against that country's actual numbering plan — not just any typed text.
Future<void> showPhoneEditSheet(BuildContext context) async {
  final userProv = context.read<UserProvider>();
  final current = userProv.user;
  if (current == null) return;

  final saved = await showGlassSheet<bool>(
    context,
    enableDrag: false,
    builder: (_) => _PhoneEditSheet(currentPhone: current.phone),
  );

  if (saved == true && context.mounted) {
    showAppSnackBar(context, 'Phone number saved');
  }
}

class _PhoneEditSheet extends StatefulWidget {
  final String? currentPhone;

  const _PhoneEditSheet({required this.currentPhone});

  @override
  State<_PhoneEditSheet> createState() => _PhoneEditSheetState();
}

class _PhoneEditSheetState extends State<_PhoneEditSheet> {
  Country? _parsedCountry;
  Country? _country;
  late final TextEditingController _controller;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    final raw = widget.currentPhone?.trim() ?? '';
    String initialText = raw;

    if (raw.isNotEmpty) {
      try {
        final parsed = PhoneNumber.parse(raw);
        _parsedCountry = kCountries.firstWhere((c) => c.isoCode == parsed.isoCode);
        initialText = parsed.formatNsn();
      } catch (_) {
        // An older free-typed number that doesn't parse: keep it as-is in the
        // field (don't silently drop what the user had) and just pick a
        // sensible default country in didChangeDependencies below.
      }
    }

    _controller = TextEditingController(text: initialText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // View.of needs an inherited lookup, which isn't available yet in
    // initState — this runs right after it, before the first build.
    _country ??=
        _parsedCountry ??
        defaultCountry(View.of(context).platformDispatcher.locale.countryCode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerSheet(context);
    if (picked != null && mounted) setState(() => _country = picked);
  }

  Future<void> _submit() async {
    final typed = _controller.text.trim();

    if (typed.isEmpty) {
      await _save(null);
      return;
    }

    final country = _country!;
    PhoneNumber parsed;
    try {
      parsed = PhoneNumber.parse(typed, callerCountry: country.isoCode);
    } catch (_) {
      setState(() => _error = 'Enter a valid phone number for ${country.name}.');
      return;
    }
    if (!parsed.isValid()) {
      setState(() => _error = 'Enter a valid phone number for ${country.name}.');
      return;
    }

    await _save(parsed.international);
  }

  Future<void> _save(String? phone) async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final userProv = context.read<UserProvider>();
    final current = userProv.user;
    if (current == null) return; // signed out mid-edit; nothing to save to

    final ok = await userProv.updateUserProfile(current.copyWith(phone: phone ?? ''));
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = userProv.error ?? 'Could not save your number.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final country = _country!;
    return PopScope(
      canPop: !_submitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Phone Number',
            style: AppTextStyles.serifTitleSmall.copyWith(
              color: AppColors.glassOnSurface,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saved to your profile. It isn\'t verified by text message.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'PHONE',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                key: const Key('phone-country-button'),
                onTap: _submitting ? null : _pickCountry,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: AppRadius.radiusLG,
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(country.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '+${country.dialCode}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 15,
                          color: AppColors.glassOnSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppColors.glassOnSurfaceFaint,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassTextField(
                  controller: _controller,
                  hintText: 'Leave empty to remove',
                  keyboardType: TextInputType.phone,
                  errorText: _error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassPrimaryButton(
            text: _submitting ? 'Saving...' : 'Save',
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

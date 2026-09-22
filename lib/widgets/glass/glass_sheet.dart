import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import 'glass_filter_chips.dart';
import 'glass_primary_button.dart';
import 'glass_text_field.dart';

/// Opens a glass-styled modal bottom sheet that lifts above the keyboard.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: enableDrag,
    backgroundColor: AppColors.glassSurfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: builder(sheetContext),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SheetHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.serifTitleSmall.copyWith(
            color: AppColors.glassOnSurface,
            fontSize: 22,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.glassOnSurfaceMuted,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Action sheet ────────────────────────────────────────────────────────────

class GlassSheetAction {
  final String label;
  final IconData icon;
  final bool destructive;
  final VoidCallback onTap;

  const GlassSheetAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });
}

/// A titled list of actions for one item. Each action closes the sheet
/// first, then runs.
Future<void> showGlassActionSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<GlassSheetAction> actions,
}) {
  return showGlassSheet<void>(
    context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 16),
        for (final action in actions)
          _ActionRow(
            action: action,
            onSelected: () {
              Navigator.of(sheetContext).pop();
              action.onTap();
            },
          ),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final GlassSheetAction action;
  final VoidCallback onSelected;

  const _ActionRow({required this.action, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final color = action.destructive
        ? AppColors.glassDestructive
        : AppColors.glassOnSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.glassSurface,
        borderRadius: AppRadius.radiusXL,
        child: InkWell(
          borderRadius: AppRadius.radiusXL,
          onTap: onSelected,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusXL,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Icon(action.icon, color: color, size: 20),
                const SizedBox(width: 12),
                Text(
                  action.label,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Form sheet ──────────────────────────────────────────────────────────────

/// A text input in a [showGlassFormSheet]. Its trimmed value is returned to
/// `onSubmit` under [key].
class GlassFormField {
  final String key;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool required;
  final String initialValue;

  /// Hide what is typed (passwords).
  final bool obscure;

  /// Extra validation for a non-empty value; returns an error message or null.
  final String? Function(String value)? validator;

  const GlassFormField({
    required this.key,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.required = true,
    this.initialValue = '',
    this.obscure = false,
    this.validator,
  });
}

/// A pick-one row of chips in a [showGlassFormSheet]. The selected option is
/// returned to `onSubmit` under [key].
class GlassFormChoice {
  final String key;
  final String label;
  final List<String> options;
  final int initialIndex;

  const GlassFormChoice({
    required this.key,
    required this.label,
    required this.options,
    this.initialIndex = 0,
  });
}

/// Shows a validated form in a bottom sheet.
///
/// [onSubmit] does the actual save and returns an error message, or null on
/// success. On failure the sheet stays open with the message and the user's
/// input intact, so a failed save never costs them what they typed.
/// Resolves to true if the form was saved, false if it was dismissed.
Future<bool> showGlassFormSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required String submitLabel,
  List<GlassFormField> fields = const [],
  List<GlassFormChoice> choices = const [],
  required Future<String?> Function(Map<String, String> values) onSubmit,
}) async {
  final saved = await showGlassSheet<bool>(
    context,
    // No drag-to-dismiss: it can't be blocked while a save is in flight.
    enableDrag: false,
    builder: (_) => _GlassFormSheet(
      title: title,
      subtitle: subtitle,
      submitLabel: submitLabel,
      fields: fields,
      choices: choices,
      onSubmit: onSubmit,
    ),
  );
  return saved ?? false;
}

class _GlassFormSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String submitLabel;
  final List<GlassFormField> fields;
  final List<GlassFormChoice> choices;
  final Future<String?> Function(Map<String, String> values) onSubmit;

  const _GlassFormSheet({
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.fields,
    required this.choices,
    required this.onSubmit,
  });

  @override
  State<_GlassFormSheet> createState() => _GlassFormSheetState();
}

class _GlassFormSheetState extends State<_GlassFormSheet> {
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields)
      field.key: TextEditingController(text: field.initialValue),
  };
  late final Map<String, int> _selected = {
    for (final choice in widget.choices) choice.key: choice.initialIndex,
  };

  Map<String, String> _errors = {};
  String? _submitError;
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final values = <String, String>{
      for (final field in widget.fields)
        field.key: _controllers[field.key]!.text.trim(),
      for (final choice in widget.choices)
        choice.key: choice.options[_selected[choice.key]!],
    };

    final errors = <String, String>{};
    for (final field in widget.fields) {
      final value = values[field.key]!;
      if (value.isEmpty) {
        if (field.required) errors[field.key] = '${field.label} is required';
      } else {
        final problem = field.validator?.call(value);
        if (problem != null) errors[field.key] = problem;
      }
    }

    setState(() {
      _errors = errors;
      _submitError = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _submitting = true);
    final failure = await widget.onSubmit(values);
    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _submitError = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Don't let back/scrim dismiss the sheet mid-save.
      canPop: !_submitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(title: widget.title, subtitle: widget.subtitle),
          const SizedBox(height: 20),
          for (final field in widget.fields) ...[
            GlassTextField(
              controller: _controllers[field.key],
              label: field.label,
              hintText: field.hint,
              keyboardType: field.keyboardType,
              obscureText: field.obscure,
              errorText: _errors[field.key],
            ),
            const SizedBox(height: 16),
          ],
          for (final choice in widget.choices) ...[
            Text(
              choice.label.toUpperCase(),
              style: AppTextStyles.overline.copyWith(
                color: AppColors.glassOnSurfaceMuted,
              ),
            ),
            const SizedBox(height: 8),
            GlassFilterChips(
              labels: choice.options,
              selectedIndex: _selected[choice.key]!,
              onSelected: (index) {
                if (_submitting) return;
                setState(() => _selected[choice.key] = index);
              },
            ),
            const SizedBox(height: 16),
          ],
          if (_submitError != null) ...[
            Text(
              _submitError!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.glassDestructive,
              ),
            ),
            const SizedBox(height: 12),
          ],
          GlassPrimaryButton(
            text: _submitting ? 'Saving...' : widget.submitLabel,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

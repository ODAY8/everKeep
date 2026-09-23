import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/countries.dart';
import 'glass_search_bar.dart';

/// Lets the user search and pick a country (for its phone dial code). A
/// virtualized list, so it stays smooth over all ~245 entries.
///
/// Resolves to the chosen [Country], or `null` if dismissed without one.
Future<Country?> showCountryPickerSheet(BuildContext context) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.glassSurfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _CountryPickerSheet(),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  List<Country> get _filtered {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return kCountries;
    return kCountries
        .where(
          (c) =>
              c.name.toLowerCase().contains(needle) ||
              c.dialCode.contains(needle.replaceAll('+', '')),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a Country',
              style: AppTextStyles.serifTitleSmall.copyWith(
                color: AppColors.glassOnSurface,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 14),
            GlassSearchBar(
              hintText: 'Search countries or codes...',
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No countries match "${_query.trim()}".',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.glassOnSurfaceMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final country = filtered[index];
                        return _CountryRow(
                          country: country,
                          onTap: () => Navigator.of(context).pop(country),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  final Country country;
  final VoidCallback onTap;

  const _CountryRow({required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('country-${country.isoCode.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                country.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.glassOnSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${country.dialCode}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.glassOnSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

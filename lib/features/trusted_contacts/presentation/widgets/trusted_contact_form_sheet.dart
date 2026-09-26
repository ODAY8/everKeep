import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/trusted_contact_item.dart';
import '../../../../providers/trusted_contact_provider.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/glass/glass_sheet.dart';

const List<String> contactAccessLevels = [
  'View Only',
  'On Release',
  'Full Access',
  'Verification Role',
];

/// Displays the glass form sheet for creating or updating a trusted contact.
Future<bool> showTrustedContactFormSheet(
  BuildContext context, {
  TrustedContactItem? existing,
}) async {
  final contactProv = context.read<TrustedContactProvider>();
  final isEditing = existing != null;
  final initialAccessLevel = existing?.accessLevel ?? contactAccessLevels.first;
  var initialAccessLevelIndex = contactAccessLevels.indexOf(initialAccessLevel);
  if (initialAccessLevelIndex == -1) initialAccessLevelIndex = 0;

  final saved = await showGlassFormSheet(
    context,
    title: isEditing ? 'Edit Trusted Person' : 'Add Trusted Person',
    subtitle: isEditing
        ? 'Update contact details or access level for this person.'
        : 'Choose someone you trust to carry out your wishes.',
    submitLabel: isEditing ? 'Save Changes' : 'Add Person',
    fields: [
      GlassFormField(
        key: 'name',
        label: 'Full name',
        hint: 'e.g. Jordan Lee',
        initialValue: existing?.name ?? '',
      ),
      GlassFormField(
        key: 'relationship',
        label: 'Relationship',
        hint: 'e.g. Sibling, Attorney',
        initialValue: existing?.relationship ?? '',
      ),
    ],
    choices: [
      GlassFormChoice(
        key: 'accessLevel',
        label: 'Access level',
        options: contactAccessLevels,
        initialIndex: initialAccessLevelIndex,
      ),
    ],
    onSubmit: (values) async {
      if (isEditing) {
        final updated = existing.copyWith(
          name: values['name']!,
          relationship: values['relationship']!,
          accessLevel: values['accessLevel']!,
        );
        final ok = await contactProv.updateContact(updated);
        return ok ? null : contactProv.error ?? 'Could not update this person.';
      } else {
        final added = await contactProv.addContact(
          TrustedContactItem(
            id: '',
            name: values['name']!,
            relationship: values['relationship']!,
            accessLevel: values['accessLevel']!,
            avatarUrl: '',
          ),
        );
        return added ? null : contactProv.error ?? 'Could not add this person.';
      }
    },
  );

  if (saved && context.mounted) {
    showAppSnackBar(
      context,
      isEditing ? 'Trusted person updated' : 'Trusted person added',
    );
  }

  return saved;
}

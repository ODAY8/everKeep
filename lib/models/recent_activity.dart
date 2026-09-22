import 'account_item.dart';
import 'document_item.dart';
import 'trusted_contact_item.dart';

enum ActivityKind {
  document('Documents'),
  account('Accounts'),
  contact('Trusted People');

  final String label;
  const ActivityKind(this.label);
}

/// One line in Home's "Recent activity": something the user really added.
class ActivityItem {
  final ActivityKind kind;
  final String title;
  final DateTime at;

  const ActivityItem({required this.kind, required this.title, required this.at});
}

/// The newest [limit] things the user added across documents, accounts and
/// trusted people, newest first. Items with no timestamp are left out (there is
/// nothing honest to say about when they happened).
List<ActivityItem> buildRecentActivity({
  required Iterable<DocumentItem> documents,
  required Iterable<AccountItem> accounts,
  required Iterable<TrustedContactItem> contacts,
  int limit = 3,
}) {
  final items = <ActivityItem>[
    for (final d in documents)
      if (d.dateAdded != null)
        ActivityItem(
          kind: ActivityKind.document,
          title: '${d.title} added',
          at: d.dateAdded!,
        ),
    for (final a in accounts)
      if (a.createdAt != null)
        ActivityItem(
          kind: ActivityKind.account,
          title: '${a.title} saved',
          at: a.createdAt!,
        ),
    for (final c in contacts)
      if (c.createdAt != null)
        ActivityItem(
          kind: ActivityKind.contact,
          title: '${c.name} added as a trusted person',
          at: c.createdAt!,
        ),
  ]..sort((a, b) => b.at.compareTo(a.at));

  return items.take(limit).toList();
}

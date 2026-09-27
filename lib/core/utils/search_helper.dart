import '../../models/account_item.dart';
import '../../models/document_item.dart';
import '../../models/memory_item.dart';
import '../../models/trusted_contact_item.dart';

/// Container for unified multi-entity search results across EverKeep.
class SearchResults {
  final List<DocumentItem> documents;
  final List<AccountItem> accounts;
  final List<MemoryItem> memories;
  final List<TrustedContactItem> contacts;

  const SearchResults({
    this.documents = const [],
    this.accounts = const [],
    this.memories = const [],
    this.contacts = const [],
  });

  bool get isEmpty =>
      documents.isEmpty &&
      accounts.isEmpty &&
      memories.isEmpty &&
      contacts.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get totalCount =>
      documents.length + accounts.length + memories.length + contacts.length;
}

/// A pure-Dart matching and tokenization engine for EverKeep client-side search.
///
/// Handles:
/// - Case-insensitive matching
/// - Multi-word token queries (e.g. "passport somalia")
/// - Substring matching
/// - Safe handling of null, empty, and optional metadata fields
/// - Safe handling of Unicode characters, emojis, and symbols
/// - Whitespace trimming
class SearchMatcher {
  const SearchMatcher._();

  /// Tokenizes a query string into lowercase, whitespace-split tokens.
  /// Empty or whitespace-only queries return an empty list.
  static List<String> tokenize(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  /// Returns true if [tokens] is empty, OR if for every token in [tokens],
  /// at least one non-null field in [fields] contains that token as a substring.
  static bool matchesTokens(
    Iterable<String?> fields,
    List<String> tokens,
  ) {
    if (tokens.isEmpty) return true;

    final nonNullFields = fields
        .where((f) => f != null && f.trim().isNotEmpty)
        .map((f) => f!.toLowerCase())
        .toList();

    if (nonNullFields.isEmpty) return false;

    for (final token in tokens) {
      var found = false;
      for (final field in nonNullFields) {
        if (field.contains(token)) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }

    return true;
  }

  /// Checks whether [doc] matches [query] (or pre-tokenized [tokens]).
  static bool matchesDocument(
    DocumentItem doc, {
    String? query,
    List<String>? tokens,
  }) {
    final t = tokens ?? (query != null ? tokenize(query) : const []);
    if (t.isEmpty) return true;

    final fileName = doc.filePath != null && doc.filePath!.isNotEmpty
        ? doc.filePath!.split('/').last
        : null;

    final fields = <String?>[
      doc.title,
      doc.category,
      doc.documentType,
      doc.displayType,
      doc.typeInfo.label,
      doc.documentNumber,
      doc.country,
      doc.institution,
      doc.notes,
      doc.description,
      doc.ocrText,
      fileName,
    ];

    return matchesTokens(fields, t);
  }

  /// Checks whether [item] (Memory or Wish) matches [query] (or [tokens]).
  static bool matchesMemory(
    MemoryItem item, {
    String? query,
    List<String>? tokens,
  }) {
    final t = tokens ?? (query != null ? tokenize(query) : const []);
    if (t.isEmpty) return true;

    String? monthName;
    if (item.date != null && item.date!.month >= 1 && item.date!.month <= 12) {
      const months = [
        'january', 'february', 'march', 'april', 'may', 'june',
        'july', 'august', 'september', 'october', 'november', 'december'
      ];
      monthName = months[item.date!.month - 1];
    }

    final fields = <String?>[
      item.title,
      item.content,
      item.location,
      item.tags,
      item.type,
      item.typeLabel,
      item.formattedDate,
      item.date?.year.toString(),
      monthName,
      ...item.tagList,
    ];

    return matchesTokens(fields, t);
  }

  /// Checks whether [acc] matches [query] (or [tokens]).
  static bool matchesAccount(
    AccountItem acc, {
    String? query,
    List<String>? tokens,
  }) {
    final t = tokens ?? (query != null ? tokenize(query) : const []);
    if (t.isEmpty) return true;

    final fields = <String?>[
      acc.title,
      acc.category,
      acc.username,
      acc.website,
      acc.notes,
      acc.subtitle,
    ];

    return matchesTokens(fields, t);
  }

  /// Checks whether [contact] matches [query] (or [tokens]).
  static bool matchesContact(
    TrustedContactItem contact, {
    String? query,
    List<String>? tokens,
  }) {
    final t = tokens ?? (query != null ? tokenize(query) : const []);
    if (t.isEmpty) return true;

    final fields = <String?>[
      contact.name,
      contact.relationship,
      contact.accessLevel,
    ];

    return matchesTokens(fields, t);
  }

  /// Searches across all provided collections simultaneously.
  /// Query is tokenized once for high performance.
  static SearchResults searchAll({
    required List<DocumentItem> documents,
    required List<AccountItem> accounts,
    List<MemoryItem> memories = const [],
    List<TrustedContactItem> contacts = const [],
    required String query,
  }) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return const SearchResults();

    return SearchResults(
      documents: documents
          .where((d) => matchesDocument(d, tokens: tokens))
          .toList(),
      accounts: accounts
          .where((a) => matchesAccount(a, tokens: tokens))
          .toList(),
      memories: memories
          .where((m) => matchesMemory(m, tokens: tokens))
          .toList(),
      contacts: contacts
          .where((c) => matchesContact(c, tokens: tokens))
          .toList(),
    );
  }
}

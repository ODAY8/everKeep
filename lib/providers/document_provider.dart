import 'package:flutter/foundation.dart';
import '../models/document_item.dart';
import '../models/document_upload.dart';
import '../repositories/document_repository.dart';
import 'session_scoped.dart';

class DocumentProvider extends ChangeNotifier with SessionScoped {
  final DocumentRepository _documentRepository;

  List<DocumentItem> _documents = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  DocumentProvider({DocumentRepository? documentRepository})
      : _documentRepository = documentRepository ?? DocumentRepositoryImpl();

  List<DocumentItem> get documents => List.unmodifiable(_documents);
  int get count => _documents.length;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  bool get isEmpty => _documents.isEmpty;

  /// Documents that expire soon (within 90 days) and are not expired yet.
  List<DocumentItem> get expiringSoonDocuments =>
      _documents.where((d) => d.isExpiringSoon).toList();

  /// Documents that are past their expiry date.
  List<DocumentItem> get expiredDocuments =>
      _documents.where((d) => d.isExpired).toList();

  /// All documents needing attention (expired or expiring soon), sorted by urgency.
  List<DocumentItem> get attentionDocuments {
    final list =
        _documents.where((d) => d.isExpired || d.isExpiringSoon).toList();
    list.sort((a, b) {
      if (a.isExpired && !b.isExpired) return -1;
      if (!a.isExpired && b.isExpired) return 1;
      final aDate = a.expiryDate ?? DateTime(2100);
      final bDate = b.expiryDate ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });
    return list;
  }

  /// Documents that do not have an expiration date set.
  List<DocumentItem> get noExpiryDocuments =>
      _documents.where((d) => !d.hasExpiryDate).toList();

  /// Checks whether [doc] matches the search [needle].
  bool _matchesQuery(DocumentItem doc, String needle) {
    if (needle.isEmpty) return true;
    if (doc.title.toLowerCase().contains(needle)) return true;
    if (doc.displayType.toLowerCase().contains(needle)) return true;
    if (doc.documentType != null &&
        doc.documentType!.toLowerCase().contains(needle)) {
      return true;
    }
    if (doc.documentNumber != null &&
        doc.documentNumber!.toLowerCase().contains(needle)) {
      return true;
    }
    if (doc.country != null && doc.country!.toLowerCase().contains(needle)) {
      return true;
    }
    if (doc.institution != null &&
        doc.institution!.toLowerCase().contains(needle)) {
      return true;
    }
    if (doc.notes != null && doc.notes!.toLowerCase().contains(needle)) {
      return true;
    }
    return false;
  }

  /// Documents in [category] ("All" or empty for every category) whose metadata
  /// matches [query] (ignoring case).
  List<DocumentItem> filterByCategory(String category, {String query = ''}) {
    final needle = query.trim().toLowerCase();
    final anyCategory = category.isEmpty || category == 'All';
    return _documents.where((doc) {
      if (!anyCategory &&
          doc.category.toLowerCase() != category.toLowerCase() &&
          doc.displayType.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      return _matchesQuery(doc, needle);
    }).toList();
  }

  /// Filters documents based on a status/organization filter ('All', 'Expiring Soon',
  /// 'Expired', 'No Expiry', or category), optional [documentType], and search [query].
  List<DocumentItem> filterDocuments({
    String filter = 'All',
    String? documentType,
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();
    return _documents.where((doc) {
      switch (filter) {
        case 'All':
          break;
        case 'Expiring Soon':
          if (!doc.isExpiringSoon) return false;
          break;
        case 'Expired':
          if (!doc.isExpired) return false;
          break;
        case 'No Expiry':
          if (doc.hasExpiryDate) return false;
          break;
        default:
          if (doc.category.toLowerCase() != filter.toLowerCase() &&
              doc.displayType.toLowerCase() != filter.toLowerCase()) {
            return false;
          }
      }

      if (documentType != null &&
          documentType.isNotEmpty &&
          documentType != 'All') {
        final matchesType = doc.typeInfo.code == documentType ||
            doc.typeInfo.label.toLowerCase() == documentType.toLowerCase();
        if (!matchesType) return false;
      }

      return _matchesQuery(doc, needle);
    }).toList();
  }

  /// A short-lived link to view [document]'s stored file, or null (with
  /// [error] set) if it has no file or the link couldn't be made.
  Future<String?> downloadUrlFor(DocumentItem document) async {
    final path = document.filePath;
    if (path == null) return null;
    final epoch = sessionEpoch;
    try {
      final url = await _documentRepository.createDownloadUrl(path);
      return isStale(epoch) ? null : url;
    } catch (e) {
      if (isStale(epoch)) return null;
      _error = errorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<void> fetchDocuments() async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _documentRepository.fetchDocuments();
      if (isStale(epoch)) return;
      _documents = fetched;
      _hasFetched = true;
    } catch (e) {
      if (isStale(epoch)) return;
      _error = errorMessage(e);
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Saves a document. If [upload] is given its file goes to private Storage
  /// and the document points at it.
  Future<bool> addDocument(
    DocumentItem document, {
    DocumentUpload? upload,
  }) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final added = await _documentRepository.addDocument(
        document,
        upload: upload,
      );
      if (isStale(epoch)) return false;
      _documents.insert(0, added);
      return true;
    } catch (e) {
      if (isStale(epoch)) return false;
      _error = errorMessage(e);
      return false;
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Updates an existing document's metadata.
  Future<bool> updateDocument(DocumentItem document) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _documentRepository.updateDocument(document);
      if (isStale(epoch)) return false;
      final index = _documents.indexWhere((d) => d.id == updated.id);
      if (index != -1) {
        _documents[index] = updated;
      }
      return true;
    } catch (e) {
      if (isStale(epoch)) return false;
      _error = errorMessage(e);
      return false;
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> deleteDocument(String id) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _documentRepository.deleteDocument(id);
      if (isStale(epoch)) return false;
      _documents.removeWhere((doc) => doc.id == id);
      return true;
    } catch (e) {
      if (isStale(epoch)) return false;
      _error = errorMessage(e);
      return false;
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Drops everything held for the previous user (called on sign-out).
  void reset() {
    invalidateSession();
    _documents = [];
    _isLoading = false;
    _error = null;
    _hasFetched = false;
    notifyListeners();
  }
}

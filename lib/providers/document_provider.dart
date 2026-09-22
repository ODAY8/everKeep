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

  /// Documents in [category] ("All" or empty for every category) whose title
  /// contains [query] (ignoring case).
  List<DocumentItem> filterByCategory(String category, {String query = ''}) {
    final needle = query.trim().toLowerCase();
    final anyCategory = category.isEmpty || category == 'All';
    return _documents.where((doc) {
      if (!anyCategory && doc.category.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      return needle.isEmpty || doc.title.toLowerCase().contains(needle);
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

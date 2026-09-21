import 'package:flutter/foundation.dart';
import '../models/document_item.dart';
import '../repositories/document_repository.dart';

class DocumentProvider extends ChangeNotifier {
  final DocumentRepository _documentRepository;

  List<DocumentItem> _documents = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  DocumentProvider({DocumentRepository? documentRepository})
      : _documentRepository = documentRepository ?? DocumentRepositoryImpl();

  List<DocumentItem> get documents => List.unmodifiable(_documents);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  bool get isEmpty => _documents.isEmpty;

  List<DocumentItem> filterByCategory(String category) {
    if (category.isEmpty || category == 'All') {
      return documents;
    }
    return _documents
        .where((doc) => doc.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  Future<void> fetchDocuments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _documents = await _documentRepository.fetchDocuments();
      _hasFetched = true;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addDocument(DocumentItem document) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final added = await _documentRepository.addDocument(document);
      _documents.insert(0, added);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDocument(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _documentRepository.deleteDocument(id);
      _documents.removeWhere((doc) => doc.id == id);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

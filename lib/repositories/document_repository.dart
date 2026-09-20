import '../models/document_item.dart';
import '../services/document_service.dart';

abstract class DocumentRepository {
  Future<List<DocumentItem>> fetchDocuments();
  Future<DocumentItem> addDocument(DocumentItem document);
  Future<void> deleteDocument(String id);
}

class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentService _documentService;

  DocumentRepositoryImpl({DocumentService? documentService})
    : _documentService = documentService ?? DocumentServiceImpl();

  @override
  Future<List<DocumentItem>> fetchDocuments() {
    return _documentService.fetchDocuments();
  }

  @override
  Future<DocumentItem> addDocument(DocumentItem document) {
    return _documentService.addDocument(document);
  }

  @override
  Future<void> deleteDocument(String id) {
    return _documentService.deleteDocument(id);
  }
}

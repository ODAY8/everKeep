import '../models/document_item.dart';
import '../models/document_upload.dart';
import '../services/document_service.dart';

abstract class DocumentRepository {
  Future<List<DocumentItem>> fetchDocuments();
  Future<DocumentItem> addDocument(
    DocumentItem document, {
    DocumentUpload? upload,
  });
  Future<DocumentItem> updateDocument(DocumentItem document);
  Future<void> deleteDocument(String id);
  Future<String> createDownloadUrl(String filePath);
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
  Future<DocumentItem> addDocument(
    DocumentItem document, {
    DocumentUpload? upload,
  }) {
    return _documentService.addDocument(document, upload: upload);
  }

  @override
  Future<DocumentItem> updateDocument(DocumentItem document) {
    return _documentService.updateDocument(document);
  }

  @override
  Future<void> deleteDocument(String id) {
    return _documentService.deleteDocument(id);
  }

  @override
  Future<String> createDownloadUrl(String filePath) {
    return _documentService.createDownloadUrl(filePath);
  }
}

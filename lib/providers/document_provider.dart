import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/utils/search_helper.dart';
import '../features/documents/models/ocr_result.dart';
import '../features/documents/services/ocr_service.dart';
import '../models/document_item.dart';
import '../models/document_upload.dart';
import '../repositories/document_repository.dart';
import '../services/notification_service.dart';
import 'session_scoped.dart';

class DocumentProvider extends ChangeNotifier with SessionScoped {
  final DocumentRepository _documentRepository;
  final NotificationService? _notificationService;
  final OcrService _ocrService;

  List<DocumentItem> _documents = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  final Set<String> _processingOcrDocIds = {};
  final Map<String, double> _ocrProgress = {};
  final Map<String, String> _ocrStatus = {};
  final Map<String, String> _ocrErrors = {};

  DocumentProvider({
    DocumentRepository? documentRepository,
    NotificationService? notificationService,
    OcrService? ocrService,
  })  : _documentRepository = documentRepository ?? DocumentRepositoryImpl(),
        _notificationService =
            notificationService ?? NotificationService.instance,
        _ocrService = ocrService ?? MlKitOcrService();

  List<DocumentItem> get documents => List.unmodifiable(_documents);
  int get count => _documents.length;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  bool get isEmpty => _documents.isEmpty;

  bool isOcrProcessing(String docId) => _processingOcrDocIds.contains(docId);
  double getOcrProgress(String docId) => _ocrProgress[docId] ?? 0.0;
  String? getOcrStatusMessage(String docId) => _ocrStatus[docId];
  String? getOcrError(String docId) => _ocrErrors[docId];

  void clearOcrError(String docId) {
    if (_ocrErrors.remove(docId) != null) {
      notifyListeners();
    }
  }

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

  /// Checks whether [doc] matches the search [query].
  bool matchesQuery(DocumentItem doc, String query) {
    return SearchMatcher.matchesDocument(doc, query: query);
  }

  /// Documents in [category] ("All" or empty for every category) whose metadata
  /// matches [query] (ignoring case).
  List<DocumentItem> filterByCategory(String category, {String query = ''}) {
    final tokens = SearchMatcher.tokenize(query);
    final anyCategory = category.isEmpty || category == 'All';
    return _documents.where((doc) {
      if (!anyCategory &&
          doc.category.toLowerCase() != category.toLowerCase() &&
          doc.displayType.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      return SearchMatcher.matchesDocument(doc, tokens: tokens);
    }).toList();
  }

  /// Filters documents based on a status/organization filter ('All', 'Expiring Soon',
  /// 'Expired', 'No Expiry', or category), optional [documentType], and search [query].
  List<DocumentItem> filterDocuments({
    String filter = 'All',
    String? documentType,
    String query = '',
  }) {
    final tokens = SearchMatcher.tokenize(query);
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

      return SearchMatcher.matchesDocument(doc, tokens: tokens);
    }).toList();
  }

  final Map<String, (String url, DateTime expiresAt)> _signedUrlCache = {};

  /// A short-lived link to view [document]'s stored file, or null (with
  /// [error] set) if it has no file or the link couldn't be made.
  ///
  /// Caches the signed URL for the session to prevent redundant network trips.
  /// Set [forceRefresh] to true to bypass cache and fetch a fresh signed URL.
  Future<String?> downloadUrlFor(
    DocumentItem document, {
    bool forceRefresh = false,
  }) async {
    final path = document.filePath;
    if (path == null) return null;
    final epoch = sessionEpoch;

    if (!forceRefresh) {
      final cached = _signedUrlCache[path];
      if (cached != null &&
          DateTime.now().isBefore(cached.$2.subtract(const Duration(seconds: 30)))) {
        return cached.$1;
      }
    }

    try {
      final url = await _documentRepository.createDownloadUrl(path);
      if (isStale(epoch)) return null;
      _signedUrlCache[path] = (
        url,
        DateTime.now().add(const Duration(seconds: 270)),
      );
      return url;
    } catch (e) {
      _signedUrlCache.remove(path);
      if (isStale(epoch)) return null;
      _error = errorMessage(e);
      notifyListeners();
      return null;
    }
  }

  /// Invalidates the cached signed URL for [filePath] or wipes the whole cache if omitted.
  void invalidateSignedUrlCache([String? filePath]) {
    if (filePath != null) {
      _signedUrlCache.remove(filePath);
    } else {
      _signedUrlCache.clear();
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
      unawaited(_notificationService?.reconcileDocumentReminders(_documents));
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
      unawaited(_notificationService?.scheduleDocumentReminders(added));
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
      unawaited(_notificationService?.scheduleDocumentReminders(updated));
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
      unawaited(_notificationService?.cancelDocumentReminders(id));
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

  /// Performs OCR on [document], either using provided in-memory [rawBytes] (e.g. from
  /// a freshly captured scan) or by downloading its stored file from Storage.
  ///
  /// Updates document.ocrText and saves the record in the vault.
  Future<OcrDocumentResult?> extractTextForDocument(
    DocumentItem document, {
    Uint8List? rawBytes,
  }) async {
    if (_processingOcrDocIds.contains(document.id)) {
      return null; // Prevent duplicate concurrent runs
    }

    final epoch = sessionEpoch;
    _processingOcrDocIds.add(document.id);
    _ocrErrors.remove(document.id);
    _ocrProgress[document.id] = 0.05;
    _ocrStatus[document.id] = 'Preparing document...';
    notifyListeners();

    try {
      Uint8List bytes;
      if (rawBytes != null && rawBytes.isNotEmpty) {
        bytes = rawBytes;
      } else {
        if (!document.hasFile) {
          throw const OcrException('This document has no attached file to scan.');
        }
        _ocrStatus[document.id] = 'Fetching document...';
        notifyListeners();

        final url = await downloadUrlFor(document);
        if (isStale(epoch)) return null;
        if (url == null || url.isEmpty) {
          throw OcrException(_error ?? 'Could not obtain secure link to document.');
        }

        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw OcrException('Failed to download document bytes (HTTP ${response.statusCode}).');
        }
        bytes = response.bodyBytes;
      }

      if (isStale(epoch)) return null;

      final OcrDocumentResult result;
      if (document.isPdf) {
        result = await _ocrService.processPdfBytes(
          bytes,
          onProgress: (p, s) {
            if (isStale(epoch)) return;
            _ocrProgress[document.id] = p;
            _ocrStatus[document.id] = s;
            notifyListeners();
          },
        );
      } else {
        result = await _ocrService.processImageBytes(
          bytes,
          onProgress: (p, s) {
            if (isStale(epoch)) return;
            _ocrProgress[document.id] = p;
            _ocrStatus[document.id] = s;
            notifyListeners();
          },
        );
      }

      if (isStale(epoch)) return null;

      // Save the extracted text to document
      final updated = document.copyWith(
        ocrText: result.combinedText,
      );
      final saved = await updateDocument(updated);
      if (!saved) {
        throw OcrException(_error ?? 'Failed to save extracted OCR text to document.');
      }

      return result;
    } catch (e) {
      if (!isStale(epoch)) {
        _ocrErrors[document.id] = errorMessage(e);
      }
      return null;
    } finally {
      if (!isStale(epoch)) {
        _processingOcrDocIds.remove(document.id);
        _ocrProgress.remove(document.id);
        _ocrStatus.remove(document.id);
        notifyListeners();
      }
    }
  }

  /// Saves user-corrected OCR text for [document].
  Future<bool> saveOcrText(DocumentItem document, String newText) async {
    final updated = document.copyWith(ocrText: newText.trim());
    return updateDocument(updated);
  }

  /// Drops everything held for the previous user (called on sign-out).
  void reset() {
    invalidateSession();
    _signedUrlCache.clear();
    _processingOcrDocIds.clear();
    _ocrProgress.clear();
    _ocrStatus.clear();
    _ocrErrors.clear();
    _documents = [];
    _isLoading = false;
    _error = null;
    _hasFetched = false;
    unawaited(_notificationService?.cancelAll());
    notifyListeners();
  }
}

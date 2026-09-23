import 'package:flutter/foundation.dart';
import '../models/document_upload.dart';
import '../models/memory_item.dart';
import '../repositories/memory_repository.dart';
import 'session_scoped.dart';

class MemoryProvider extends ChangeNotifier with SessionScoped {
  final MemoryRepository _memoryRepository;

  List<MemoryItem> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  MemoryProvider({MemoryRepository? memoryRepository})
    : _memoryRepository = memoryRepository ?? MemoryRepositoryImpl();

  List<MemoryItem> get items => List.unmodifiable(_items);
  List<MemoryItem> get memories =>
      List.unmodifiable(_items.where((item) => item.isMemory));
  List<MemoryItem> get wishes =>
      List.unmodifiable(_items.where((item) => item.isWish));
  int get count => _items.length;
  int get memoriesCount => _items.where((item) => item.isMemory).length;
  int get wishesCount => _items.where((item) => item.isWish).length;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFetched => _hasFetched;
  bool get isEmpty => _items.isEmpty;

  /// Items of [type] ('memory' or 'wish') whose title or content contains
  /// [query] (ignoring case).
  List<MemoryItem> filterByType(String type, {String query = ''}) {
    final needle = query.trim().toLowerCase();
    return _items.where((item) {
      if (item.type.toLowerCase() != type.toLowerCase()) return false;
      if (needle.isEmpty) return true;
      return item.title.toLowerCase().contains(needle) ||
          item.content.toLowerCase().contains(needle);
    }).toList();
  }

  Future<void> fetchMemories() async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _memoryRepository.fetchMemories();
      if (isStale(epoch)) return;
      _items = fetched;
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

  /// Saves a memory or wish. If [upload] is given its file goes to private
  /// Storage and the item points at it.
  Future<bool> createMemory(MemoryItem item, {DocumentUpload? upload}) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final added = await _memoryRepository.createMemory(
        item,
        upload: upload,
      );
      if (isStale(epoch)) return false;
      _items.insert(0, added);
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

  /// Saves edits to title, content, type or date.
  Future<bool> updateMemory(MemoryItem item) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saved = await _memoryRepository.updateMemory(item);
      if (isStale(epoch)) return false;
      final index = _items.indexWhere((m) => m.id == saved.id);
      if (index != -1) _items[index] = saved;
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

  Future<bool> deleteMemory(String id) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _memoryRepository.deleteMemory(id);
      if (isStale(epoch)) return false;
      _items.removeWhere((m) => m.id == id);
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

  /// Adds or replaces [id]'s attachment.
  Future<bool> uploadAttachment(String id, DocumentUpload upload) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saved = await _memoryRepository.uploadAttachment(id, upload);
      if (isStale(epoch)) return false;
      final index = _items.indexWhere((m) => m.id == saved.id);
      if (index != -1) _items[index] = saved;
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

  /// Removes [id]'s attachment, keeping the memory or wish itself.
  Future<bool> removeAttachment(String id) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saved = await _memoryRepository.deleteAttachment(id);
      if (isStale(epoch)) return false;
      final index = _items.indexWhere((m) => m.id == saved.id);
      if (index != -1) _items[index] = saved;
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

  /// A short-lived link to view [item]'s stored file, or null (with [error]
  /// set) if it has no file or the link couldn't be made.
  Future<String?> downloadUrlFor(MemoryItem item) async {
    final path = item.filePath;
    if (path == null) return null;
    final epoch = sessionEpoch;
    try {
      final url = await _memoryRepository.createDownloadUrl(path);
      return isStale(epoch) ? null : url;
    } catch (e) {
      if (isStale(epoch)) return null;
      _error = errorMessage(e);
      notifyListeners();
      return null;
    }
  }

  /// Drops everything held for the previous user (called on sign-out).
  void reset() {
    invalidateSession();
    _items = [];
    _isLoading = false;
    _error = null;
    _hasFetched = false;
    notifyListeners();
  }
}

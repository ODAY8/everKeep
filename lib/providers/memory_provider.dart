import 'package:flutter/foundation.dart';
import '../models/document_upload.dart';
import '../models/memory_item.dart';
import '../models/memory_media_item.dart';
import '../repositories/memory_repository.dart';
import 'session_scoped.dart';

enum MemorySortOption {
  memoryDateDesc,
  memoryDateAsc,
  createdDateDesc,
  titleAsc,
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  const _CachedUrl(this.url, this.expiresAt);

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class MemoryProvider extends ChangeNotifier with SessionScoped {
  final MemoryRepository _memoryRepository;

  List<MemoryItem> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _hasFetched = false;

  /// Cache of signed URLs keyed by filePath with a 240s validity window.
  final Map<String, _CachedUrl> _signedUrlCache = {};

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

  /// Set of all unique tags used across memories, sorted alphabetically.
  List<String> get allMemoryTags {
    final tagSet = <String>{};
    for (final item in _items) {
      if (item.isMemory) {
        for (final tag in item.tagList) {
          if (tag.isNotEmpty) tagSet.add(tag);
        }
      }
    }
    final list = tagSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

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

  /// Advanced search & filter matching query, optional tag, and sort order.
  List<MemoryItem> getFilteredMemories({
    String query = '',
    String? tag,
    MemorySortOption sort = MemorySortOption.memoryDateDesc,
    String type = 'memory',
  }) {
    final q = query.trim().toLowerCase();
    final selectedTag = tag?.trim().toLowerCase().replaceAll('#', '');

    final filtered = _items.where((item) {
      if (item.type.toLowerCase() != type.toLowerCase()) return false;
      if (q.isNotEmpty && !item.matchesQuery(q)) return false;
      if (selectedTag != null &&
          selectedTag.isNotEmpty &&
          selectedTag != 'all') {
        if (!item.hasTag(selectedTag)) return false;
      }
      return true;
    }).toList();

    switch (sort) {
      case MemorySortOption.memoryDateDesc:
        filtered.sort((a, b) => b.timelineDate.compareTo(a.timelineDate));
        break;
      case MemorySortOption.memoryDateAsc:
        filtered.sort((a, b) => a.timelineDate.compareTo(b.timelineDate));
        break;
      case MemorySortOption.createdDateDesc:
        filtered.sort((a, b) {
          final aCreated =
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bCreated =
              b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bCreated.compareTo(aCreated);
        });
        break;
      case MemorySortOption.titleAsc:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
    }

    return filtered;
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

  /// Saves a memory or wish with optional legacy single-attachment upload.
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

  /// Creates a memory and uploads multiple media items in a single safe sequence.
  Future<bool> createMemoryWithMedia(
    MemoryItem item,
    List<DocumentUpload> uploads, {
    List<String>? captions,
    List<int?>? durations,
  }) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final added = await _memoryRepository.createMemoryWithMedia(
        item,
        uploads,
        captions: captions,
        durations: durations,
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

  /// Adds a media item (photo, video, or audio) to an existing memory.
  Future<MemoryMediaItem?> addMedia(
    String memoryId,
    DocumentUpload upload, {
    String? caption,
    int? displayOrder,
    int? durationSeconds,
  }) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final mediaItem = await _memoryRepository.addMedia(
        memoryId,
        upload,
        caption: caption,
        displayOrder: displayOrder,
        durationSeconds: durationSeconds,
      );
      if (isStale(epoch)) return null;

      final index = _items.indexWhere((m) => m.id == memoryId);
      if (index != -1) {
        final current = _items[index];
        final updatedMedia = List<MemoryMediaItem>.from(current.media)
          ..add(mediaItem);
        _items[index] = current.copyWith(media: updatedMedia);
      }
      return mediaItem;
    } catch (e) {
      if (isStale(epoch)) return null;
      _error = errorMessage(e);
      return null;
    } finally {
      if (!isStale(epoch)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Deletes a specific media item and removes it from its parent memory in state.
  Future<bool> deleteMedia(String mediaId) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _memoryRepository.deleteMedia(mediaId);
      if (isStale(epoch)) return false;

      for (var i = 0; i < _items.length; i++) {
        final matchIndex = _items[i].media.indexWhere((m) => m.id == mediaId);
        if (matchIndex != -1) {
          final removed = _items[i].media[matchIndex];
          _signedUrlCache.remove(removed.filePath);
          final updatedMedia = List<MemoryMediaItem>.from(_items[i].media)
            ..removeAt(matchIndex);
          _items[i] = _items[i].copyWith(media: updatedMedia);
          break;
        }
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

  /// Updates media display ordering for [memoryId] in the repository and local state.
  Future<bool> reorderMedia(
    String memoryId,
    List<String> orderedMediaIds,
  ) async {
    final epoch = sessionEpoch;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _memoryRepository.reorderMedia(memoryId, orderedMediaIds);
      if (isStale(epoch)) return false;

      final index = _items.indexWhere((m) => m.id == memoryId);
      if (index != -1) {
        final current = _items[index];
        final mediaMap = {for (final m in current.media) m.id: m};
        final reordered = <MemoryMediaItem>[];
        for (var i = 0; i < orderedMediaIds.length; i++) {
          final m = mediaMap[orderedMediaIds[i]];
          if (m != null) {
            reordered.add(m.copyWith(displayOrder: i));
          }
        }
        _items[index] = current.copyWith(media: reordered);
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

      final index = _items.indexWhere((m) => m.id == id);
      if (index != -1) {
        final item = _items[index];
        if (item.filePath != null) _signedUrlCache.remove(item.filePath!);
        for (final m in item.media) {
          _signedUrlCache.remove(m.filePath);
        }
      }

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

  /// Adds or replaces [id]'s legacy single attachment.
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

  /// Removes [id]'s legacy attachment, keeping the memory or wish itself.
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

  /// Returns a valid signed URL for [filePath], serving from cache if fresh (within 240s)
  /// or requesting a new signed URL from the repository.
  Future<String?> createSignedUrl(String filePath) async {
    if (filePath.trim().isEmpty) return null;
    final cached = _signedUrlCache[filePath];
    if (cached != null && cached.isValid) {
      return cached.url;
    }

    final epoch = sessionEpoch;
    try {
      final url = await _memoryRepository.createSignedUrl(filePath);
      if (isStale(epoch)) return null;
      _signedUrlCache[filePath] = _CachedUrl(
        url,
        DateTime.now().add(const Duration(seconds: 240)),
      );
      return url;
    } catch (e) {
      if (isStale(epoch)) return null;
      _error = errorMessage(e);
      notifyListeners();
      return null;
    }
  }

  /// Convenience method to retrieve a cached/fresh signed URL for a [MemoryMediaItem].
  Future<String?> signedUrlForMedia(MemoryMediaItem mediaItem) =>
      createSignedUrl(mediaItem.filePath);

  /// A short-lived link to view [item]'s stored file (legacy single attachment).
  Future<String?> downloadUrlFor(MemoryItem item) async {
    final path = item.filePath;
    if (path == null || path.isEmpty) return null;
    return createSignedUrl(path);
  }

  /// Drops everything held for the previous user (called on sign-out).
  void reset() {
    invalidateSession();
    _signedUrlCache.clear();
    _items = [];
    _isLoading = false;
    _error = null;
    _hasFetched = false;
    notifyListeners();
  }
}

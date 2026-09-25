import '../models/document_upload.dart';
import '../models/memory_item.dart';
import '../models/memory_media_item.dart';
import '../services/memory_service.dart';

abstract class MemoryRepository {
  Future<List<MemoryItem>> fetchMemories();
  Future<MemoryItem> fetchMemory(String id);
  Future<MemoryItem> createMemory(MemoryItem item, {DocumentUpload? upload});

  /// Creates a memory and uploads multiple media items in a single safe flow.
  Future<MemoryItem> createMemoryWithMedia(
    MemoryItem item,
    List<DocumentUpload> uploads, {
    List<String>? captions,
    List<int?>? durations,
  });

  /// Adds a single media item (photo, video, or audio) to an existing memory.
  Future<MemoryMediaItem> addMedia(
    String memoryId,
    DocumentUpload upload, {
    String? caption,
    int? displayOrder,
    int? durationSeconds,
  });

  /// Deletes a specific media item and its storage object.
  Future<void> deleteMedia(String mediaId);

  /// Updates display orders for media items in a memory.
  Future<void> reorderMedia(
    String memoryId,
    List<String> orderedMediaIds,
  );

  Future<MemoryItem> updateMemory(MemoryItem item);
  Future<void> deleteMemory(String id);
  Future<MemoryItem> uploadAttachment(String id, DocumentUpload upload);
  Future<MemoryItem> deleteAttachment(String id);
  Future<String> createDownloadUrl(String filePath);
  Future<String> createSignedUrl(String filePath);
}

class MemoryRepositoryImpl implements MemoryRepository {
  final MemoryService _memoryService;

  MemoryRepositoryImpl({MemoryService? memoryService})
      : _memoryService = memoryService ?? MemoryServiceImpl();

  @override
  Future<List<MemoryItem>> fetchMemories() => _memoryService.fetchMemories();

  @override
  Future<MemoryItem> fetchMemory(String id) => _memoryService.fetchMemory(id);

  @override
  Future<MemoryItem> createMemory(MemoryItem item, {DocumentUpload? upload}) {
    return _memoryService.createMemory(item, upload: upload);
  }

  @override
  Future<MemoryItem> createMemoryWithMedia(
    MemoryItem item,
    List<DocumentUpload> uploads, {
    List<String>? captions,
    List<int?>? durations,
  }) {
    return _memoryService.createMemoryWithMedia(
      item,
      uploads,
      captions: captions,
      durations: durations,
    );
  }

  @override
  Future<MemoryMediaItem> addMedia(
    String memoryId,
    DocumentUpload upload, {
    String? caption,
    int? displayOrder,
    int? durationSeconds,
  }) {
    return _memoryService.addMedia(
      memoryId,
      upload,
      caption: caption,
      displayOrder: displayOrder,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<void> deleteMedia(String mediaId) =>
      _memoryService.deleteMedia(mediaId);

  @override
  Future<void> reorderMedia(
    String memoryId,
    List<String> orderedMediaIds,
  ) {
    return _memoryService.reorderMedia(memoryId, orderedMediaIds);
  }

  @override
  Future<MemoryItem> updateMemory(MemoryItem item) =>
      _memoryService.updateMemory(item);

  @override
  Future<void> deleteMemory(String id) => _memoryService.deleteMemory(id);

  @override
  Future<MemoryItem> uploadAttachment(String id, DocumentUpload upload) =>
      _memoryService.uploadAttachment(id, upload);

  @override
  Future<MemoryItem> deleteAttachment(String id) =>
      _memoryService.deleteAttachment(id);

  @override
  Future<String> createDownloadUrl(String filePath) =>
      _memoryService.createDownloadUrl(filePath);

  @override
  Future<String> createSignedUrl(String filePath) =>
      _memoryService.createSignedUrl(filePath);
}

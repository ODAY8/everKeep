import '../models/document_upload.dart';
import '../models/memory_item.dart';
import '../services/memory_service.dart';

abstract class MemoryRepository {
  Future<List<MemoryItem>> fetchMemories();
  Future<MemoryItem> fetchMemory(String id);
  Future<MemoryItem> createMemory(MemoryItem item, {DocumentUpload? upload});
  Future<MemoryItem> updateMemory(MemoryItem item);
  Future<void> deleteMemory(String id);
  Future<MemoryItem> uploadAttachment(String id, DocumentUpload upload);
  Future<MemoryItem> deleteAttachment(String id);
  Future<String> createDownloadUrl(String filePath);
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
}

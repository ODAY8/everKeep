import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' as img;

import '../../../../core/utils/pick_upload.dart';
import '../../../../models/document_upload.dart';

/// Abstraction for selecting media files (photos, video, audio) for Memories.
abstract class MemoryMediaPicker {
  Future<List<DocumentUpload>> pickPhotos();
  Future<DocumentUpload?> pickVideo();
  Future<DocumentUpload?> pickAudio();
}

/// Default production media picker utilizing `image_picker` and `file_picker`.
class DefaultMemoryMediaPicker implements MemoryMediaPicker {
  final img.ImagePicker _imagePicker;

  DefaultMemoryMediaPicker({img.ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? img.ImagePicker();

  @override
  Future<List<DocumentUpload>> pickPhotos() async {
    final pickedList = await _imagePicker.pickMultiImage();
    if (pickedList.isEmpty) return const [];

    final uploads = <DocumentUpload>[];
    for (final file in pickedList) {
      final bytes = await file.readAsBytes();
      if (bytes.length > maxDocumentBytes) {
        throw const PickedTooLarge(maxDocumentBytes);
      }
      uploads.add(
        DocumentUpload(
          fileName: file.name,
          bytes: bytes,
          mimeType: mimeTypeForFileName(file.name),
        ),
      );
    }
    return uploads;
  }

  @override
  Future<DocumentUpload?> pickVideo() async {
    final file = await _imagePicker.pickVideo(
      source: img.ImageSource.gallery,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.length > maxDocumentBytes) {
      throw const PickedTooLarge(maxDocumentBytes);
    }
    return DocumentUpload(
      fileName: file.name,
      bytes: bytes,
      mimeType: mimeTypeForFileName(file.name),
    );
  }

  @override
  Future<DocumentUpload?> pickAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'm4a',
        'wav',
        'aac',
        'ogg',
        'opus',
        'flac',
        'wma',
      ],
    );
    if (result.isEmpty) return null;

    final file = result.first;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxDocumentBytes) {
      throw const PickedTooLarge(maxDocumentBytes);
    }
    return DocumentUpload(
      fileName: file.name,
      bytes: bytes,
      mimeType: mimeTypeForFileName(file.name),
    );
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import '../../models/document_upload.dart';

/// Largest document a user may attach. Matches the `documents` storage
/// bucket's limit, so a too-big file is refused here with a clear message
/// instead of failing halfway through an upload.
const int maxDocumentBytes = 25 * 1024 * 1024;

/// Side length avatars are shrunk to before upload.
const int avatarSize = 512;

class PickedTooLarge implements Exception {
  final int maxBytes;
  const PickedTooLarge(this.maxBytes);

  @override
  String toString() =>
      'That file is too large. The limit is ${maxBytes ~/ (1024 * 1024)} MB.';
}

/// Lets the user choose a file from the device. Returns null if they cancel.
/// Throws [PickedTooLarge] if it exceeds [maxDocumentBytes].
Future<DocumentUpload?> pickDocument() async {
  final file = await FilePicker.pickFile();
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.length > maxDocumentBytes) throw const PickedTooLarge(maxDocumentBytes);

  return DocumentUpload(
    fileName: file.name,
    bytes: bytes,
    mimeType: mimeTypeForFileName(file.name),
  );
}

/// Lets the user choose a photo and returns it shrunk to a small square-ish PNG
/// suitable for an avatar. Returns null if they cancel.
Future<DocumentUpload?> pickAvatar() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;

  final resized = await resizeForAvatar(await file.readAsBytes());
  return DocumentUpload(
    fileName: 'avatar.png',
    bytes: resized,
    mimeType: 'image/png',
  );
}

/// Decodes [imageBytes] at no more than [avatarSize] pixels on its longest
/// side and re-encodes as PNG. A phone photo is several MB; this brings it to a
/// few hundred KB, under the avatar bucket's 2 MB limit, without a new package.
Future<Uint8List> resizeForAvatar(Uint8List imageBytes) async {
  // Decode once to learn the orientation, then again at the target size so a
  // huge photo is never fully decoded into memory.
  final probe = await ui.instantiateImageCodec(imageBytes);
  final frame = await probe.getNextFrame();
  final width = frame.image.width;
  final height = frame.image.height;
  frame.image.dispose();
  probe.dispose();

  final landscape = width >= height;
  final codec = await ui.instantiateImageCodec(
    imageBytes,
    targetWidth: landscape ? avatarSize : null,
    targetHeight: landscape ? null : avatarSize,
  );
  final resized = (await codec.getNextFrame()).image;
  final data = await resized.toByteData(format: ui.ImageByteFormat.png);
  resized.dispose();
  codec.dispose();

  if (data == null) throw StateError('Could not encode the image.');
  return data.buffer.asUint8List();
}

const Map<String, String> _mimeTypes = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'heic': 'image/heic',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'zip': 'application/zip',
};

/// A best-effort MIME type from the file name; unknown extensions are sent as
/// a generic binary type.
String mimeTypeForFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
  return _mimeTypes[extension] ?? 'application/octet-stream';
}

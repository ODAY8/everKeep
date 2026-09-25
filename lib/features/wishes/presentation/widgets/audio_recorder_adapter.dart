import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../../models/document_upload.dart';

/// Adapter interface wrapping audio recording functionality for decoupling and testability.
abstract class AudioRecorderAdapter {
  Future<bool> hasPermission();
  Future<void> start();
  Future<DocumentUpload?> stop({int? durationSeconds});
  Future<void> cancel();
  Future<bool> isRecording();
  Future<void> dispose();
}

typedef AudioRecorderAdapterFactory = AudioRecorderAdapter Function();

/// Default implementation wrapping `package:record`.
class DefaultAudioRecorderAdapter implements AudioRecorderAdapter {
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String? path;
    if (!kIsWeb) {
      final tempDir = io.Directory.systemTemp.path;
      path = '$tempDir/voice_recording_$timestamp.m4a';
    }
    _recordingPath = path;

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path ?? '',
    );
  }

  @override
  Future<DocumentUpload?> stop({int? durationSeconds}) async {
    try {
      final resultPath = await _recorder.stop();
      final finalPath = resultPath ?? _recordingPath;
      if (finalPath == null || finalPath.isEmpty) return null;

      final xfile = XFile(finalPath);
      final bytes = await xfile.readAsBytes();
      if (bytes.isEmpty) return null;

      final fileName =
          'voice_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      return DocumentUpload(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'audio/mp4',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  @override
  Future<bool> isRecording() async {
    try {
      return await _recorder.isRecording();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}

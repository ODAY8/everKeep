import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../config/app_info.dart';

/// Adapter interface for saving export files, allowing platform abstraction and test mocking.
abstract class FileSaveAdapter {
  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
  });
}

/// Default implementation using [FilePicker.saveFile].
class PlatformFileSaveAdapter implements FileSaveAdapter {
  const PlatformFileSaveAdapter();

  @override
  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Save EverKeep Data Export',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );

    if (uri == null) return null;

    if (!kIsWeb) {
      try {
        final filePath = uri.hasScheme && uri.scheme == 'file'
            ? uri.toFilePath()
            : uri.path;
        if (filePath.isNotEmpty) {
          final file = File(filePath);
          if (!file.existsSync() || file.lengthSync() == 0) {
            await file.writeAsBytes(bytes);
          }
        }
      } catch (_) {
        // Storage Access Framework on Android or OS may have already written the bytes.
      }
    }
    return uri.toString();
  }
}

enum ExportSaveStatus {
  success,
  cancelled,
  failed,
}

class ExportSaveResult {
  final ExportSaveStatus status;
  final String? filePath;
  final String? message;

  const ExportSaveResult({
    required this.status,
    this.filePath,
    this.message,
  });

  bool get isSuccess => status == ExportSaveStatus.success;
  bool get isCancelled => status == ExportSaveStatus.cancelled;
  bool get isFailed => status == ExportSaveStatus.failed;
}

/// Helper for structuring, formatting, and saving EverKeep data exports.
class DataExportHelper {
  static const String currentExportVersion = '1.0.0';

  /// Standard file save adapter (swappable for testing).
  static FileSaveAdapter fileSaveAdapter = const PlatformFileSaveAdapter();

  /// Generates a standardized, filesystem-safe filename for an export.
  static String exportFileName([DateTime? timestamp]) {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return 'everkeep_export_$year$month${day}_$hour$minute$second.json';
  }

  /// Builds a fully-structured, standardized export payload dictionary.
  static Map<String, dynamic> buildExportPayload({
    required String userId,
    required String? userEmail,
    Map<String, dynamic>? profile,
    List<dynamic> documents = const [],
    List<dynamic> accounts = const [],
    List<dynamic> trustedContacts = const [],
    List<dynamic> memories = const [],
    List<dynamic> people = const [],
    Map<String, dynamic>? securitySettings,
    DateTime? exportedAt,
  }) {
    final timestamp = (exportedAt ?? DateTime.now()).toUtc().toIso8601String();

    final cleanProfile = profile != null ? _sanitizeMap(profile) : null;
    final cleanDocuments = documents.map(_sanitizeItem).toList();
    final cleanAccounts = accounts.map(_sanitizeItem).toList();
    final cleanTrustedContacts = trustedContacts.map(_sanitizeItem).toList();
    final cleanMemories = memories.map(_sanitizeItem).toList();
    final cleanPeople = people.map(_sanitizeItem).toList();
    final cleanSecuritySettings =
        securitySettings != null ? _sanitizeMap(securitySettings) : null;

    return {
      'exportVersion': currentExportVersion,
      'exportedAt': timestamp,
      'appName': appName,
      'appVersion': appVersion,
      'account': {
        'id': userId,
        'email': userEmail ?? '',
      },
      'profile': cleanProfile,
      'documents': cleanDocuments,
      'accounts': cleanAccounts,
      'importantInformation': cleanAccounts,
      'trustedContacts': cleanTrustedContacts,
      'memories': cleanMemories,
      'people': cleanPeople,
      'securitySettings': cleanSecuritySettings,
    };
  }

  /// Saves the given export JSON text to the device filesystem.
  static Future<ExportSaveResult> saveExportJson(
    String jsonText, {
    FileSaveAdapter? adapter,
    String? customFileName,
  }) async {
    try {
      final effectiveAdapter = adapter ?? fileSaveAdapter;
      final fileName = customFileName ?? exportFileName();
      final bytes = Uint8List.fromList(utf8.encode(jsonText));

      final savedPath = await effectiveAdapter.saveFile(
        fileName: fileName,
        bytes: bytes,
      );

      if (savedPath == null) {
        return const ExportSaveResult(
          status: ExportSaveStatus.cancelled,
          message: 'Export save cancelled.',
        );
      }

      return ExportSaveResult(
        status: ExportSaveStatus.success,
        filePath: savedPath,
        message: 'Export saved successfully.',
      );
    } catch (e) {
      return ExportSaveResult(
        status: ExportSaveStatus.failed,
        message: 'Could not save export file: ${e.toString()}',
      );
    }
  }

  static dynamic _sanitizeItem(dynamic item) {
    if (item is Map<String, dynamic>) {
      return _sanitizeMap(item);
    }
    if (item is Map) {
      return _sanitizeMap(Map<String, dynamic>.from(item));
    }
    return item;
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> source) {
    const sensitiveKeys = {
      'password',
      'encrypted_password',
      'encryptedpassword',
      'vault_key',
      'encryption_key',
      'master_key',
      'access_token',
      'refresh_token',
      'token',
      'jwt',
      'service_role',
      'api_key',
      'secret',
      'session',
    };

    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      if (sensitiveKeys.contains(entry.key.toLowerCase())) {
        continue;
      }
      if (entry.value is Map) {
        result[entry.key] =
            _sanitizeMap(Map<String, dynamic>.from(entry.value as Map));
      } else if (entry.value is List) {
        result[entry.key] = (entry.value as List).map(_sanitizeItem).toList();
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Available visual filters for scanned document pages.
enum PageFilter {
  original,
  documentHighContrast,
  grayscale,
  brighten;

  String get label => switch (this) {
        PageFilter.original => 'Original',
        PageFilter.documentHighContrast => 'Document',
        PageFilter.grayscale => 'Grayscale',
        PageFilter.brighten => 'Brighten',
      };

  IconData get icon => switch (this) {
        PageFilter.original => Icons.palette_outlined,
        PageFilter.documentHighContrast => Icons.document_scanner_outlined,
        PageFilter.grayscale => Icons.monochrome_photos_outlined,
        PageFilter.brighten => Icons.brightness_6_outlined,
      };
}

/// Represents a single captured and processed document page.
class ScannedPage {
  final String id;
  final Uint8List originalBytes;
  final Uint8List processedBytes;
  final int rotationDegrees;
  final PageFilter filter;
  final Rect? cropRect;
  final int? width;
  final int? height;

  const ScannedPage({
    required this.id,
    required this.originalBytes,
    required this.processedBytes,
    this.rotationDegrees = 0,
    this.filter = PageFilter.documentHighContrast,
    this.cropRect,
    this.width,
    this.height,
  });

  ScannedPage copyWith({
    String? id,
    Uint8List? originalBytes,
    Uint8List? processedBytes,
    int? rotationDegrees,
    PageFilter? filter,
    Rect? cropRect,
    int? width,
    int? height,
  }) {
    return ScannedPage(
      id: id ?? this.id,
      originalBytes: originalBytes ?? this.originalBytes,
      processedBytes: processedBytes ?? this.processedBytes,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      filter: filter ?? this.filter,
      cropRect: cropRect ?? this.cropRect,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

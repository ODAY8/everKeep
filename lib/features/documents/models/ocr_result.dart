import 'dart:convert';

/// Represents the OCR result for an individual document page.
class OcrPageResult {
  final int pageNumber;
  final String text;
  final double? confidence;

  const OcrPageResult({
    required this.pageNumber,
    required this.text,
    this.confidence,
  });

  bool get isEmpty => text.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toJson() => {
        'pageNumber': pageNumber,
        'text': text,
        if (confidence != null) 'confidence': confidence,
      };

  factory OcrPageResult.fromJson(Map<String, dynamic> json) => OcrPageResult(
        pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
        text: (json['text'] as String?) ?? '',
        confidence: (json['confidence'] as num?)?.toDouble(),
      );

  OcrPageResult copyWith({
    int? pageNumber,
    String? text,
    double? confidence,
  }) {
    return OcrPageResult(
      pageNumber: pageNumber ?? this.pageNumber,
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcrPageResult &&
          runtimeType == other.runtimeType &&
          pageNumber == other.pageNumber &&
          text == other.text &&
          confidence == other.confidence;

  @override
  int get hashCode => pageNumber.hashCode ^ text.hashCode ^ confidence.hashCode;

  @override
  String toString() =>
      'OcrPageResult(page: $pageNumber, length: ${text.length}, confidence: $confidence)';
}

/// Represents the complete OCR result for a single-page or multi-page document.
class OcrDocumentResult {
  final List<OcrPageResult> pages;
  final String combinedText;
  final DateTime processedAt;
  final bool isUserEdited;

  const OcrDocumentResult({
    required this.pages,
    required this.combinedText,
    required this.processedAt,
    this.isUserEdited = false,
  });

  int get pageCount => pages.length;
  bool get isEmpty => combinedText.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Creates a structured result from a list of page results, automatically
  /// formatting [combinedText] with page separators if there is more than 1 page.
  factory OcrDocumentResult.fromPages(
    List<OcrPageResult> pages, {
    DateTime? processedAt,
    bool isUserEdited = false,
  }) {
    final timestamp = processedAt ?? DateTime.now();
    if (pages.isEmpty) {
      return OcrDocumentResult(
        pages: const [],
        combinedText: '',
        processedAt: timestamp,
        isUserEdited: isUserEdited,
      );
    }

    if (pages.length == 1) {
      return OcrDocumentResult(
        pages: pages,
        combinedText: pages.first.text.trim(),
        processedAt: timestamp,
        isUserEdited: isUserEdited,
      );
    }

    final buffer = StringBuffer();
    for (var i = 0; i < pages.length; i++) {
      if (i > 0) buffer.write('\n\n');
      buffer.writeln('--- Page ${pages[i].pageNumber} ---');
      buffer.write(pages[i].text.trim());
    }

    return OcrDocumentResult(
      pages: pages,
      combinedText: buffer.toString(),
      processedAt: timestamp,
      isUserEdited: isUserEdited,
    );
  }

  /// Parses a combined text string, detecting page markers (`--- Page X ---`)
  /// if present, or producing a single-page result otherwise.
  factory OcrDocumentResult.fromCombinedText(
    String text, {
    DateTime? processedAt,
    bool isUserEdited = false,
  }) {
    final timestamp = processedAt ?? DateTime.now();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return OcrDocumentResult(
        pages: const [],
        combinedText: '',
        processedAt: timestamp,
        isUserEdited: isUserEdited,
      );
    }

    final pageMarkerRegex = RegExp(r'--- Page (\d+) ---');
    final matches = pageMarkerRegex.allMatches(trimmed).toList();

    if (matches.isEmpty) {
      return OcrDocumentResult(
        pages: [
          OcrPageResult(pageNumber: 1, text: trimmed),
        ],
        combinedText: trimmed,
        processedAt: timestamp,
        isUserEdited: isUserEdited,
      );
    }

    final parsedPages = <OcrPageResult>[];
    for (var i = 0; i < matches.length; i++) {
      final currentMatch = matches[i];
      final pageNum = int.tryParse(currentMatch.group(1) ?? '1') ?? (i + 1);
      final textStart = currentMatch.end;
      final textEnd =
          (i + 1 < matches.length) ? matches[i + 1].start : trimmed.length;

      final pageText = trimmed.substring(textStart, textEnd).trim();
      parsedPages.add(OcrPageResult(
        pageNumber: pageNum,
        text: pageText,
      ));
    }

    return OcrDocumentResult(
      pages: parsedPages,
      combinedText: trimmed,
      processedAt: timestamp,
      isUserEdited: isUserEdited,
    );
  }

  Map<String, dynamic> toJson() => {
        'pages': pages.map((p) => p.toJson()).toList(),
        'combinedText': combinedText,
        'processedAt': processedAt.toIso8601String(),
        'isUserEdited': isUserEdited,
      };

  factory OcrDocumentResult.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>? ?? const [];
    final pages = rawPages
        .whereType<Map<String, dynamic>>()
        .map(OcrPageResult.fromJson)
        .toList();
    final combinedText = (json['combinedText'] as String?) ?? '';
    final processedAt = json['processedAt'] != null
        ? DateTime.tryParse(json['processedAt'] as String) ?? DateTime.now()
        : DateTime.now();
    final isUserEdited = json['isUserEdited'] as bool? ?? false;

    if (pages.isEmpty && combinedText.isNotEmpty) {
      return OcrDocumentResult.fromCombinedText(
        combinedText,
        processedAt: processedAt,
        isUserEdited: isUserEdited,
      );
    }

    return OcrDocumentResult(
      pages: pages,
      combinedText: combinedText,
      processedAt: processedAt,
      isUserEdited: isUserEdited,
    );
  }

  OcrDocumentResult copyWith({
    List<OcrPageResult>? pages,
    String? combinedText,
    DateTime? processedAt,
    bool? isUserEdited,
  }) {
    return OcrDocumentResult(
      pages: pages ?? this.pages,
      combinedText: combinedText ?? this.combinedText,
      processedAt: processedAt ?? this.processedAt,
      isUserEdited: isUserEdited ?? this.isUserEdited,
    );
  }
}

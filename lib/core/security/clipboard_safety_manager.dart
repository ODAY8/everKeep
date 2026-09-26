import 'dart:async';
import 'package:flutter/services.dart';

/// Manages sensitive clipboard copies with automated timeout clearing to prevent
/// passwords from lingering on the system clipboard.
class ClipboardSafetyManager {
  static final ClipboardSafetyManager instance = ClipboardSafetyManager._();

  ClipboardSafetyManager._();

  factory ClipboardSafetyManager({Duration? defaultTimeout}) {
    if (defaultTimeout != null) {
      instance.defaultTimeout = defaultTimeout;
    }
    return instance;
  }

  Timer? _clearTimer;
  String? _lastCopiedSensitiveText;
  Duration defaultTimeout = const Duration(seconds: 30);

  bool get hasActiveTimer => _clearTimer != null && _clearTimer!.isActive;

  /// Copies sensitive [text] to the system clipboard and schedules an automatic wipe
  /// after [timeout].
  Future<void> copySensitiveText(
    String text, {
    Duration? timeout,
  }) async {
    cancel();

    _lastCopiedSensitiveText = text;
    await Clipboard.setData(ClipboardData(text: text));

    final effectiveTimeout = timeout ?? defaultTimeout;
    if (effectiveTimeout > Duration.zero) {
      _clearTimer = Timer(effectiveTimeout, () async {
        await _clearIfMatching(text);
      });
    }
  }

  Future<void> _clearIfMatching(String expectedText) async {
    try {
      if (_lastCopiedSensitiveText != expectedText) return;
      final currentData = await Clipboard.getData(Clipboard.kTextPlain);
      if (currentData?.text == expectedText) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (_) {
      // Platform clipboard access might fail on some platforms or tests
    } finally {
      _lastCopiedSensitiveText = null;
      _clearTimer = null;
    }
  }

  /// Cancels any scheduled clipboard clear operation.
  void cancel() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _lastCopiedSensitiveText = null;
  }
}

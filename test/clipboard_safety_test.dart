import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/core/security/clipboard_safety_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipboardSafetyManager', () {
    late ClipboardSafetyManager manager;
    String mockClipboard = '';

    setUp(() {
      manager = ClipboardSafetyManager.instance;
      manager.cancel();

      // Mock Clipboard
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          mockClipboard = (args['text'] as String?) ?? '';
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': mockClipboard};
        }
        return null;
      });
    });

    tearDown(() {
      manager.cancel();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('copies sensitive text to clipboard and starts auto-clear timer', () async {
      await manager.copySensitiveText(
        'SecretPassword123!',
        timeout: const Duration(milliseconds: 50),
      );

      expect(mockClipboard, 'SecretPassword123!');
      expect(manager.hasActiveTimer, isTrue);

      // Wait for timer to expire
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(mockClipboard, '');
      expect(manager.hasActiveTimer, isFalse);
    });

    test('cancel aborts the timer and preserves current clipboard', () async {
      await manager.copySensitiveText(
        'CancelTestPassword',
        timeout: const Duration(milliseconds: 100),
      );

      expect(manager.hasActiveTimer, isTrue);
      manager.cancel();
      expect(manager.hasActiveTimer, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(mockClipboard, 'CancelTestPassword');
    });

    test('does not clear clipboard if user copied something else in the meantime', () async {
      await manager.copySensitiveText(
        'OldPassword',
        timeout: const Duration(milliseconds: 50),
      );

      // User copies something else
      mockClipboard = 'UserOtherText';

      await Future<void>.delayed(const Duration(milliseconds: 70));
      // Should NOT wipe out user's new clipboard content
      expect(mockClipboard, 'UserOtherText');
    });
  });
}

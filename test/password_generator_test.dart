import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/core/security/password_generator.dart';

void main() {
  group('PasswordGenerator', () {
    test('generates password with default length 16', () {
      final pwd = PasswordGenerator.generate();
      expect(pwd.length, 16);
    });

    test('generates passwords of custom requested lengths', () {
      for (final len in [8, 12, 20, 28, 32, 64]) {
        final pwd = PasswordGenerator.generate(length: len);
        expect(pwd.length, len);
      }
    });

    test('clamps length between min 8 and max 64', () {
      final short = PasswordGenerator.generate(length: 4);
      expect(short.length, 8);

      final long = PasswordGenerator.generate(length: 100);
      expect(long.length, 64);
    });

    test('guarantees each selected character type is represented', () {
      for (var i = 0; i < 50; i++) {
        final pwd = PasswordGenerator.generate(
          length: 16,
          includeUppercase: true,
          includeLowercase: true,
          includeNumbers: true,
          includeSymbols: true,
        );

        expect(pwd.contains(RegExp(r'[A-Z]')), isTrue);
        expect(pwd.contains(RegExp(r'[a-z]')), isTrue);
        expect(pwd.contains(RegExp(r'[0-9]')), isTrue);
        expect(pwd.contains(RegExp(r'[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]')), isTrue);
      }
    });

    test('respects character exclusion options', () {
      final digitsOnly = PasswordGenerator.generate(
        length: 16,
        includeUppercase: false,
        includeLowercase: false,
        includeNumbers: true,
        includeSymbols: false,
      );
      expect(digitsOnly, matches(RegExp(r'^[0-9]+$')));

      final alphaOnly = PasswordGenerator.generate(
        length: 16,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: false,
        includeSymbols: false,
      );
      expect(alphaOnly, matches(RegExp(r'^[a-zA-Z]+$')));
    });

    test('falls back safely if all character options are false', () {
      final fallback = PasswordGenerator.generate(
        length: 16,
        includeUppercase: false,
        includeLowercase: false,
        includeNumbers: false,
        includeSymbols: false,
      );
      expect(fallback.length, 16);
      expect(fallback.isNotEmpty, isTrue);
    });

    test('produces unique random passwords across multiple runs', () {
      final set = <String>{};
      for (var i = 0; i < 100; i++) {
        set.add(PasswordGenerator.generate(length: 16));
      }
      expect(set.length, 100);
    });
  });
}

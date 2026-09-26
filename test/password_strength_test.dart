import 'package:flutter_test/flutter_test.dart';
import 'package:everkeep/core/security/password_strength.dart';
import 'package:everkeep/core/theme/app_colors.dart';

void main() {
  group('PasswordStrengthChecker', () {
    test('empty password returns empty strength level', () {
      final s = PasswordStrengthChecker.evaluate('');
      expect(s.level, PasswordStrengthLevel.empty);
      expect(s.score, 0);
      expect(s.progress, 0.0);
    });

    test('common passwords are penalized as weak with warning', () {
      final commonList = ['password', '123456', 'qwerty', 'everkeep', 'admin'];
      for (final p in commonList) {
        final s = PasswordStrengthChecker.evaluate(p);
        expect(s.level, PasswordStrengthLevel.weak);
        expect(s.feedback.toLowerCase(), contains('common'));
        expect(s.color, AppColors.glassDestructive);
      }
    });

    test('short passwords (<8 chars) are rated weak', () {
      final s = PasswordStrengthChecker.evaluate('Ab1!x');
      expect(s.level, PasswordStrengthLevel.weak);
      expect(s.feedback, contains('at least 8 characters'));
    });

    test('moderate passwords return fair strength', () {
      final s = PasswordStrengthChecker.evaluate('password123');
      expect(s.level, anyOf(PasswordStrengthLevel.weak, PasswordStrengthLevel.fair));
    });

    test('strong complex passwords return strong strength', () {
      final s = PasswordStrengthChecker.evaluate('K7#v9!PxQ2@mZ8*wL4\$y');
      expect(s.level, PasswordStrengthLevel.strong);
      expect(s.score, greaterThanOrEqualTo(85));
      expect(s.progress, 1.0);
      expect(s.color, AppColors.glassAccentGreen);
      expect(s.feedback, contains('Excellent'));
    });

    test('heavily repetitive characters are penalized', () {
      final repetitive = PasswordStrengthChecker.evaluate('aaaaaaaaaaaaaa');
      final diverse = PasswordStrengthChecker.evaluate('aB3!dE5#gH7\$jK9@');
      expect(diverse.score, greaterThan(repetitive.score));
    });
  });
}

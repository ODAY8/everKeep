import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PasswordStrengthLevel {
  empty,
  weak,
  fair,
  good,
  strong,
}

class PasswordStrength {
  final PasswordStrengthLevel level;
  final int score; // 0 - 100
  final String label;
  final String feedback;
  final Color color;
  final double progress; // 0.0 - 1.0

  const PasswordStrength({
    required this.level,
    required this.score,
    required this.label,
    required this.feedback,
    required this.color,
    required this.progress,
  });

  static const PasswordStrength empty = PasswordStrength(
    level: PasswordStrengthLevel.empty,
    score: 0,
    label: 'Empty',
    feedback: 'Enter a password',
    color: AppColors.glassOnSurfaceMuted,
    progress: 0.0,
  );
}

/// Evaluates password strength locally without sending text to any network or logs.
class PasswordStrengthChecker {
  static const Set<String> _commonPasswords = {
    'password',
    '123456',
    '12345678',
    '123456789',
    '12345',
    '111111',
    'qwerty',
    'abc123',
    'password123',
    'admin',
    'welcome',
    'everkeep',
  };

  /// Analyzes the [password] and returns its [PasswordStrength].
  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) {
      return PasswordStrength.empty;
    }

    final lower = password.toLowerCase();
    if (_commonPasswords.contains(lower)) {
      return const PasswordStrength(
        level: PasswordStrengthLevel.weak,
        score: 15,
        label: 'Very Weak',
        feedback: 'Common password — easily guessed',
        color: AppColors.glassDestructive,
        progress: 0.15,
      );
    }

    var score = 0;
    final length = password.length;

    // Length points (up to 40)
    if (length >= 16) {
      score += 40;
    } else if (length >= 12) {
      score += 30;
    } else if (length >= 8) {
      score += 20;
    } else {
      score += (length * 2);
    }

    // Character variety points (up to 45)
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSymbols = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/;]'));

    var varietyCount = 0;
    if (hasLower) varietyCount++;
    if (hasUpper) varietyCount++;
    if (hasDigits) varietyCount++;
    if (hasSymbols) varietyCount++;

    score += (varietyCount * 10);
    if (varietyCount == 4) score += 5; // Bonus for all 4

    // Entropy / uniqueness bonus (up to 15)
    final uniqueChars = password.split('').toSet().length;
    if (uniqueChars >= 10) {
      score += 15;
    } else if (uniqueChars >= 6) {
      score += 10;
    } else if (uniqueChars >= 4) {
      score += 5;
    }

    // Penalties
    if (uniqueChars <= 3 && length > 6) {
      score = (score * 0.5).round(); // Heavy repetitive pattern
    }

    score = score.clamp(0, 100);

    // Map to levels and feedback
    if (score < 40 || length < 8) {
      final feedback = length < 8
          ? 'Use at least 8 characters'
          : 'Mix uppercase, numbers, and symbols';
      return PasswordStrength(
        level: PasswordStrengthLevel.weak,
        score: score,
        label: 'Weak',
        feedback: feedback,
        color: AppColors.glassDestructive,
        progress: (score / 100).clamp(0.1, 0.35),
      );
    } else if (score < 65) {
      final feedback = !hasSymbols
          ? 'Add symbols for greater security'
          : 'Make it longer for stronger security';
      return PasswordStrength(
        level: PasswordStrengthLevel.fair,
        score: score,
        label: 'Fair',
        feedback: feedback,
        color: AppColors.glassWarningColor,
        progress: (score / 100).clamp(0.4, 0.65),
      );
    } else if (score < 85) {
      return PasswordStrength(
        level: PasswordStrengthLevel.good,
        score: score,
        label: 'Good',
        feedback: 'Good password. Add length for maximum protection.',
        color: AppColors.glassAccentBlue,
        progress: (score / 100).clamp(0.7, 0.85),
      );
    } else {
      return PasswordStrength(
        level: PasswordStrengthLevel.strong,
        score: score,
        label: 'Strong',
        feedback: 'Excellent! Very hard to compromise.',
        color: AppColors.glassAccentGreen,
        progress: 1.0,
      );
    }
  }
}

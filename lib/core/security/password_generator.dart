import 'dart:math';

/// Generates cryptographically secure, random passwords with customizable
/// length and character-set composition.
class PasswordGenerator {
  static const String uppercaseChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // Omits confusing 'I', 'O'
  static const String lowercaseChars = 'abcdefghijkmnopqrstuvwxyz'; // Omits confusing 'l'
  static const String numberChars = '23456789'; // Omits confusing '0', '1'
  static const String symbolChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

  static const int defaultLength = 16;
  static const int minLength = 8;
  static const int maxLength = 64;

  /// Generates a strong random password using [Random.secure].
  ///
  /// Guarantees at least one character from each enabled character set.
  static String generate({
    int length = defaultLength,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
    Random? customRandom,
  }) {
    final rand = customRandom ?? Random.secure();
    final effectiveLength = length.clamp(minLength, maxLength);

    // If all character sets are disabled, enable lowercase by default.
    final useUpper = includeUppercase;
    final useLower = includeLowercase || (!includeUppercase && !includeNumbers && !includeSymbols);
    final useNumbers = includeNumbers;
    final useSymbols = includeSymbols;

    final charPool = StringBuffer();
    final guaranteedChars = <String>[];

    if (useUpper) {
      charPool.write(uppercaseChars);
      guaranteedChars.add(uppercaseChars[rand.nextInt(uppercaseChars.length)]);
    }
    if (useLower) {
      charPool.write(lowercaseChars);
      guaranteedChars.add(lowercaseChars[rand.nextInt(lowercaseChars.length)]);
    }
    if (useNumbers) {
      charPool.write(numberChars);
      guaranteedChars.add(numberChars[rand.nextInt(numberChars.length)]);
    }
    if (useSymbols) {
      charPool.write(symbolChars);
      guaranteedChars.add(symbolChars[rand.nextInt(symbolChars.length)]);
    }

    final pool = charPool.toString();
    final remainingCount = effectiveLength - guaranteedChars.length;
    final result = List<String>.from(guaranteedChars);

    for (var i = 0; i < remainingCount; i++) {
      result.add(pool[rand.nextInt(pool.length)]);
    }

    // Fisher-Yates shuffle using cryptographically secure random.
    for (var i = result.length - 1; i > 0; i--) {
      final j = rand.nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }

    return result.join();
  }
}

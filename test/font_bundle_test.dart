import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app ships its fonts instead of downloading them (see configureFonts). This
/// makes sure that's actually true: every font weight the theme asks for must
/// have its file in the `google_fonts/` folder, and that folder must be declared
/// as an asset — otherwise that weight would fail (with downloading off) or
/// silently download (with it on).
///
/// It reads the files on disk rather than the test runner's asset cache, because
/// the cache keeps stale copies of files that have since been deleted.
void main() {
  const weightFiles = {
    300: 'Figtree-Light.ttf',
    400: 'Figtree-Regular.ttf',
    500: 'Figtree-Medium.ttf',
    600: 'Figtree-SemiBold.ttf',
    700: 'Figtree-Bold.ttf',
    800: 'Figtree-ExtraBold.ttf',
  };

  /// Every `FontWeight.wNNN` mentioned in the theme, plus Regular, which any
  /// unstyled text uses.
  Set<int> weightsUsedByTheme() {
    final weights = <int>{400};
    final pattern = RegExp(r'FontWeight\.w(\d{3})');
    for (final file in Directory(
      'lib/core/theme',
    ).listSync().whereType<File>()) {
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        weights.add(int.parse(match.group(1)!));
      }
    }
    return weights;
  }

  test('the theme only uses weights this test knows how to check', () {
    final unknown = weightsUsedByTheme().difference(weightFiles.keys.toSet());
    expect(
      unknown,
      isEmpty,
      reason:
          'The theme uses weights $unknown that have no entry here. Bundle '
          'the matching Figtree file in google_fonts/ and add it above.',
    );
  });

  test('every Figtree weight the theme uses is bundled', () {
    for (final weight in weightsUsedByTheme()) {
      final file = File('google_fonts/${weightFiles[weight]}');
      expect(file.existsSync(), isTrue, reason: 'w$weight needs ${file.path}');
      expect(
        file.lengthSync(),
        greaterThan(10000),
        reason: '${file.path} looks empty',
      );
    }
  });

  test('Young Serif (the headline font) is bundled', () {
    final file = File('google_fonts/YoungSerif-Regular.ttf');
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(10000));
  });

  test('the folder is declared as an asset, so a build actually ships it', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- google_fonts/'));
  });

  test('the font licenses travel with the fonts', () {
    for (final name in ['OFL-Figtree.txt', 'OFL-YoungSerif.txt']) {
      final text = File('google_fonts/$name').readAsStringSync();
      expect(text, contains('SIL OPEN FONT LICENSE'), reason: name);
    }
  });
}

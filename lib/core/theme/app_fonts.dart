import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Uses the fonts bundled in `google_fonts/` and never downloads any.
///
/// Every weight the app asks for is in that folder (a test checks this), so
/// text renders immediately on first launch and works offline. Turning runtime
/// fetching off also means a weight that is ever added to the design but not
/// bundled fails loudly in development instead of silently downloading.
///
/// Also registers the fonts' license text so it shows on the app's licenses page
/// (the SIL Open Font License asks for it to travel with the fonts).
void configureFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;

  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Figtree'],
      await rootBundle.loadString('google_fonts/OFL-Figtree.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      ['Young Serif'],
      await rootBundle.loadString('google_fonts/OFL-YoungSerif.txt'),
    );
  });
}

import 'package:google_fonts/google_fonts.dart';

import 'models/reading_preferences.dart';

/// Resolves a [ReadingFont] choice into the concrete `fontFamily` string the
/// `flutter_html` engine should use. System fonts use generic CSS family
/// names; Google Fonts go through the `google_fonts` package which returns
/// a runtime-registered family identifier.
String? resolveFontFamily(ReadingFont font) {
  switch (font) {
    case ReadingFont.systemSerif:
      return 'serif';
    case ReadingFont.systemSans:
      return 'sans-serif';
    case ReadingFont.merriweather:
      return GoogleFonts.merriweather().fontFamily;
    case ReadingFont.lora:
      return GoogleFonts.lora().fontFamily;
    case ReadingFont.ptSerif:
      return GoogleFonts.ptSerif().fontFamily;
    case ReadingFont.inter:
      return GoogleFonts.inter().fontFamily;
    case ReadingFont.openSans:
      return GoogleFonts.openSans().fontFamily;
  }
}

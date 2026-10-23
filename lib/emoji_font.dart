import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled Noto Color Emoji, web only. Without it Flutter web downloads emoji
/// glyphs from fonts.gstatic.com. Android/iOS skip the asset (see pubspec) and
/// use the system emoji; the fallback name is then simply not found.
const String kEmojiFont = 'NotoColorEmoji';
/// Roboto first: otherwise letters and spaces fall to the emoji font on web
/// (its space glyph is wide). Flutter web ships Roboto itself.
const List<String> kEmojiFallback = ['Roboto', kEmojiFont];

const String _fontAsset = 'assets/fonts/NotoColorEmoji.ttf';
const String _licenseAsset = 'assets/fonts/NotoColorEmoji-LICENSE.txt';

/// Best effort: if loading fails the app still runs (emoji may show as boxes).
Future<void> loadEmojiFont() async {
  if (!kIsWeb) return;
  try {
    await (FontLoader(kEmojiFont)..addFont(rootBundle.load(_fontAsset))).load();
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString(_licenseAsset);
      yield LicenseEntryWithLineBreaks(const ['Noto Color Emoji'], text);
    });
  } catch (_) {
    // Ignore: drawing must never break because of a font.
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:readlivra/features/reader/data/models/reading_preferences.dart';
import 'package:readlivra/features/reader/data/reading_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReadingPreferences', () {
    test('defaults round-trip through JSON', () {
      final json = ReadingPreferences.defaults.toJson();
      final back = ReadingPreferences.fromJson(json);
      expect(back.font, ReadingPreferences.defaults.font);
      expect(back.fontSize, ReadingPreferences.defaults.fontSize);
      expect(back.lineHeight, ReadingPreferences.defaults.lineHeight);
      expect(back.letterSpacing, ReadingPreferences.defaults.letterSpacing);
      expect(
          back.paragraphSpacing, ReadingPreferences.defaults.paragraphSpacing);
    });

    test('clamps out-of-range numeric fields when reading json', () {
      final back = ReadingPreferences.fromJson({
        'font': 'merriweather',
        'fontSize': 9999,
        'lineHeight': -10,
        'letterSpacing': 1000,
        'paragraphSpacing': -1,
      });
      expect(back.font, ReadingFont.merriweather);
      expect(back.fontSize, ReadingPreferences.fontSizeRange.max);
      expect(back.lineHeight, ReadingPreferences.lineHeightRange.min);
      expect(back.letterSpacing, ReadingPreferences.letterSpacingRange.max);
      expect(back.paragraphSpacing,
          ReadingPreferences.paragraphSpacingRange.min);
    });

    test('unknown font id falls back to systemSerif', () {
      final back =
          ReadingPreferences.fromJson({'font': '__nonexistent__'});
      expect(back.font, ReadingFont.systemSerif);
    });
  });

  group('SharedPrefsReadingPreferencesRepository', () {
    test('returns defaults when nothing is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsReadingPreferencesRepository(prefs);
      final read = await repo.get();
      final value = read.valueOrNull!;
      expect(value.font, ReadingPreferences.defaults.font);
      expect(value.fontSize, ReadingPreferences.defaults.fontSize);
    });

    test('save then get round-trips', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsReadingPreferencesRepository(prefs);
      const target = ReadingPreferences(
        font: ReadingFont.lora,
        fontSize: 19,
        lineHeight: 1.7,
        letterSpacing: 0.5,
        paragraphSpacing: 22,
      );
      await repo.save(target);

      final read = (await repo.get()).valueOrNull!;
      expect(read.font, target.font);
      expect(read.fontSize, target.fontSize);
      expect(read.lineHeight, target.lineHeight);
      expect(read.letterSpacing, target.letterSpacing);
      expect(read.paragraphSpacing, target.paragraphSpacing);
    });
  });
}

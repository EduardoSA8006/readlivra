import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/reader_palette.dart';
import '../data/font_resolver.dart';
import '../data/models/reading_preferences.dart';
import '../providers.dart';

Future<void> showReadingPreferencesSheet(BuildContext context) {
  final palette =
      ProviderScope.containerOf(context).read(readerPaletteProvider);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: palette.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ReadingPreferencesSheet(),
  );
}

class _ReadingPreferencesSheet extends ConsumerWidget{
  const _ReadingPreferencesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    final async = ref.watch(readingPreferencesProvider);
    final vm = ref.read(readingPreferencesProvider.notifier);
    final prefs = async.value ?? ReadingPreferences.defaults;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Preferências de leitura',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => vm.resetToDefaults(),
                  child: const Text('Restaurar padrão'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _SectionLabel('Tema'),
            const SizedBox(height: 8),
            _ThemePicker(
              current: prefs.theme,
              onPick: (t) => vm.patch(theme: t),
            ),
            const SizedBox(height: 18),
            const _SectionLabel('Fonte'),
            const SizedBox(height: 8),
            _FontPicker(
              current: prefs.font,
              onPick: (f) => vm.patch(font: f),
            ),
            const SizedBox(height: 18),
            _PreviewBlock(prefs: prefs),
            const SizedBox(height: 18),
            _SliderRow(
              icon: Icons.format_size_rounded,
              label: 'Tamanho',
              value: prefs.fontSize,
              min: ReadingPreferences.fontSizeRange.min,
              max: ReadingPreferences.fontSizeRange.max,
              suffix: '${prefs.fontSize.toStringAsFixed(0)} pt',
              onChanged: (v) => vm.patch(fontSize: v),
            ),
            _SliderRow(
              icon: Icons.density_medium_rounded,
              label: 'Espaçamento das linhas',
              value: prefs.lineHeight,
              min: ReadingPreferences.lineHeightRange.min,
              max: ReadingPreferences.lineHeightRange.max,
              suffix: prefs.lineHeight.toStringAsFixed(2),
              onChanged: (v) => vm.patch(lineHeight: v),
            ),
            _SliderRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Espaçamento das letras',
              value: prefs.letterSpacing,
              min: ReadingPreferences.letterSpacingRange.min,
              max: ReadingPreferences.letterSpacingRange.max,
              suffix: '${prefs.letterSpacing.toStringAsFixed(1)} px',
              onChanged: (v) => vm.patch(letterSpacing: v),
            ),
            _SliderRow(
              icon: Icons.format_line_spacing_rounded,
              label: 'Espaçamento dos parágrafos',
              value: prefs.paragraphSpacing,
              min: ReadingPreferences.paragraphSpacingRange.min,
              max: ReadingPreferences.paragraphSpacingRange.max,
              suffix: '${prefs.paragraphSpacing.toStringAsFixed(0)} px',
              onChanged: (v) => vm.patch(paragraphSpacing: v),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends ConsumerWidget{
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        color: palette.textSecondary,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FontPicker extends ConsumerWidget{
  const _FontPicker({required this.current, required this.onPick});
  final ReadingFont current;
  final ValueChanged<ReadingFont> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: ReadingFont.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final font = ReadingFont.values[i];
          final selected = font == current;
          return InkWell(
            onTap: () => onPick(font),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? palette.textPrimary : palette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? palette.textPrimary
                      : const Color(0xFFEDE7DD),
                ),
              ),
              child: Text(
                font.label,
                style: TextStyle(
                  fontFamily: resolveFontFamily(font),
                  color: selected ? Colors.white : palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreviewBlock extends ConsumerWidget{
  const _PreviewBlock({required this.prefs});
  final ReadingPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE7DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pré-visualização',
            style: TextStyle(
              fontFamily: resolveFontFamily(prefs.font),
              fontSize: prefs.fontSize + 2,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
              letterSpacing: prefs.letterSpacing,
            ),
          ),
          SizedBox(height: prefs.paragraphSpacing.clamp(6.0, 24.0)),
          Text(
            'Era uma vez, no fim do mundo, um leitor que ajustou a tipografia '
            'até cada linha respirar como deveria.',
            style: TextStyle(
              fontFamily: resolveFontFamily(prefs.font),
              fontSize: prefs.fontSize,
              height: prefs.lineHeight,
              color: palette.textPrimary,
              letterSpacing: prefs.letterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends ConsumerWidget{
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: palette.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                suffix,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: palette.textPrimary,
              thumbColor: palette.textPrimary,
              inactiveTrackColor: const Color(0xFFEDE7DD),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.current, required this.onPick});
  final ReadingTheme current;
  final ValueChanged<ReadingTheme> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < ReadingTheme.values.length; i++) ...[
          Expanded(
            child: _ThemePreviewCard(
              theme: ReadingTheme.values[i],
              selected: ReadingTheme.values[i] == current,
              onTap: () => onPick(ReadingTheme.values[i]),
            ),
          ),
          if (i < ReadingTheme.values.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ReadingTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(theme);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.accent : palette.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              theme.label,
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

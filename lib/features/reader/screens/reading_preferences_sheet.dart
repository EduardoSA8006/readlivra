import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/font_resolver.dart';
import '../data/models/reading_preferences.dart';
import '../providers.dart';

Future<void> showReadingPreferencesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ReadingPreferencesSheet(),
  );
}

class _ReadingPreferencesSheet extends ConsumerWidget {
  const _ReadingPreferencesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const Expanded(
                  child: Text(
                    'Preferências de leitura',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        color: AppTheme.textSecondary,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FontPicker extends StatelessWidget {
  const _FontPicker({required this.current, required this.onPick});
  final ReadingFont current;
  final ValueChanged<ReadingFont> onPick;

  @override
  Widget build(BuildContext context) {
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
                color: selected ? AppTheme.textPrimary : AppTheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? AppTheme.textPrimary
                      : const Color(0xFFEDE7DD),
                ),
              ),
              child: Text(
                font.label,
                style: TextStyle(
                  fontFamily: resolveFontFamily(font),
                  color: selected ? Colors.white : AppTheme.textPrimary,
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

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({required this.prefs});
  final ReadingPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
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
              color: AppTheme.textPrimary,
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
              color: AppTheme.textPrimary,
              letterSpacing: prefs.letterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                suffix,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.textPrimary,
              thumbColor: AppTheme.textPrimary,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_mode_repository.dart';
import '../../../core/theme/theme_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final modeAsync = ref.watch(themeModeProvider);
    final mode = modeAsync.value ?? AppThemeMode.system;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Ajustes',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _SectionLabel(label: 'APARÊNCIA', color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            _ThemeModeSelector(
              current: mode,
              onChanged: (m) => ref
                  .read(themeModeProvider.notifier)
                  .setMode(m),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: color,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.current, required this.onChanged});

  final AppThemeMode current;
  final ValueChanged<AppThemeMode> onChanged;

  static const _options = <(AppThemeMode, String, IconData)>[
    (AppThemeMode.system, 'Sistema', Icons.brightness_auto_rounded),
    (AppThemeMode.light, 'Claro', Icons.light_mode_rounded),
    (AppThemeMode.dark, 'Escuro', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            _ThemeOptionTile(
              mode: _options[i].$1,
              label: _options[i].$2,
              icon: _options[i].$3,
              selected: current == _options[i].$1,
              onTap: () => onChanged(_options[i].$1),
            ),
            if (i < _options.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: scheme.outline,
              ),
          ],
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.mode,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: scheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

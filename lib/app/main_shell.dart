import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/screens/home_screen.dart';
import '../features/library/screens/library_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/stats/screens/stats_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    HomeScreen(),
    LibraryScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  static const _items = <_NavSpec>[
    _NavSpec('Início', Icons.home_outlined, Icons.home_rounded),
    _NavSpec('Biblioteca', Icons.menu_book_outlined, Icons.menu_book_rounded),
    _NavSpec('Estatísticas', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    _NavSpec('Ajustes', Icons.settings_outlined, Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: Color(0xFFEDE7DD))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavButton(
                      spec: _items[i],
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.textPrimary : AppTheme.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? spec.activeIcon : spec.icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            spec.label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

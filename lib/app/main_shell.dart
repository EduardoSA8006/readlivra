import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../features/home/screens/home_screen.dart';
import '../features/library/screens/library_screen.dart';
import '../features/library/viewmodels/library_ui_notifier.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/stats/screens/stats_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    HomeScreen(),
    LibraryScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  static const _items = <_NavSpec>[
    _NavSpec('Início', Icons.home_outlined, Icons.home_rounded),
    _NavSpec('Biblioteca', Icons.menu_book_outlined, Icons.menu_book_rounded),
    _NavSpec('Estatísticas', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    _NavSpec('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Boa noite';
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isHome = _index == 0;
    final isLibrary = _index == 1;
    final libraryUi = ref.watch(libraryUiProvider);
    final libraryUiNotifier = ref.read(libraryUiProvider.notifier);
    return Scaffold(
      drawer: isHome ? const _AppDrawer() : null,
      drawerEnableOpenDragGesture: isHome,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
        automaticallyImplyLeading: isHome,
        toolbarHeight: isHome ? 76 : 56,
        title: isHome
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pronto para continuar a leitura?',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              )
            : Text(
                _items[_index].label,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
        centerTitle: false,
        actions: _appBarActions(
          isHome: isHome,
          isLibrary: isLibrary,
          scheme: scheme,
          libraryUi: libraryUi,
          libraryUiNotifier: libraryUiNotifier,
        ),
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outline)),
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

  List<Widget>? _appBarActions({
    required bool isHome,
    required bool isLibrary,
    required ColorScheme scheme,
    required LibraryUiState libraryUi,
    required LibraryUiNotifier libraryUiNotifier,
  }) {
    if (isHome) {
      return [
        IconButton(
          icon: Icon(Icons.settings_rounded, color: scheme.onSurface),
          tooltip: 'Ajustes',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        const SizedBox(width: 4),
      ];
    }
    if (isLibrary) {
      return [
        IconButton(
          tooltip: libraryUi.searchVisible ? 'Fechar busca' : 'Buscar',
          onPressed: libraryUiNotifier.toggleSearch,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: Icon(
              libraryUi.searchVisible
                  ? Icons.close_rounded
                  : Icons.search_rounded,
              key: ValueKey<bool>(libraryUi.searchVisible),
              color: scheme.onSurface,
            ),
          ),
        ),
        IconButton(
          tooltip: libraryUi.viewMode == LibraryViewMode.grid
              ? 'Visualizar em lista'
              : 'Visualizar em grade',
          onPressed: libraryUiNotifier.toggleViewMode,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween<double>(begin: 0.85, end: 1).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              libraryUi.viewMode == LibraryViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              key: ValueKey<LibraryViewMode>(libraryUi.viewMode),
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ];
    }
    return null;
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DrawerHeader(),
            const SizedBox(height: 8),
            _DrawerTile(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            _DrawerTile(
              icon: Icons.info_outline_rounded,
              label: 'Sobre o readlivra',
              onTap: () {
                Navigator.of(context).pop();
                showAboutDialog(
                  context: context,
                  applicationName: 'readlivra',
                  applicationVersion: '0.1.0',
                  applicationLegalese:
                      'Leitor pessoal de EPUBs com sincronização local.',
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Text(
                'readlivra · 0.1.0',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppPalette.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.menu_book_rounded, color: Colors.white, size: 32),
          SizedBox(height: 12),
          Text(
            'readlivra',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Sua biblioteca pessoal',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.onSurface),
      title: Text(
        label,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
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
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
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

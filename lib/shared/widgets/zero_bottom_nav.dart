import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class ZeroBottomNav extends StatelessWidget {
  const ZeroBottomNav({super.key});

  static const _paths = ['/home', '/reports', '/history', '/settings'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _paths.indexWhere((path) => location.startsWith(path));
    return index >= 0 ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BottomNavigationBar(
      currentIndex: _currentIndex(context),
      onTap: (index) => context.go(_paths[index]),
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home),
          label: l10n.nav_home,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.bar_chart_outlined),
          activeIcon: const Icon(Icons.bar_chart),
          label: l10n.nav_reports,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.calendar_today_outlined),
          activeIcon: const Icon(Icons.calendar_today),
          label: l10n.nav_history,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined),
          activeIcon: const Icon(Icons.settings),
          label: l10n.nav_settings,
        ),
      ],
      type: BottomNavigationBarType.fixed,
    );
  }
}

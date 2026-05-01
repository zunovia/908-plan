import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ZeroBottomNav extends StatelessWidget {
  const ZeroBottomNav({super.key});

  static const _items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'ホーム',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart),
      label: 'レポート',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today_outlined),
      activeIcon: Icon(Icons.calendar_today),
      label: '履歴',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: '設定',
    ),
  ];

  static const _paths = ['/home', '/reports', '/history', '/settings'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _paths.indexWhere((path) => location.startsWith(path));
    return index >= 0 ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentIndex(context),
      onTap: (index) => context.go(_paths[index]),
      items: _items,
      type: BottomNavigationBarType.fixed,
    );
  }
}

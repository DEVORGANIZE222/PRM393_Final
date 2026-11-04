import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Lab 2 *Bottom navigation*: 4 top-level destinations; the selected one has an
/// indicator pill and a darker label (not colour alone). Nested screens keep
/// the bar hidden and show Back instead (Lab 2 IA).
class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({super.key, required this.shell, this.unreadAlerts = 0});

  final StatefulNavigationShell shell;
  final int unreadAlerts;

  static const _destinations = [
    (id: 'nav_home', icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
    (id: 'nav_browse', icon: Icons.search, selected: Icons.search, label: 'Browse'),
    (id: 'nav_team', icon: Icons.groups_outlined, selected: Icons.groups, label: 'My Team'),
    (id: 'nav_settings', icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          for (var i = 0; i < _destinations.length; i++)
            Semantics(
              identifier: _destinations[i].id,
              child: NavigationDestination(
                icon: Icon(_destinations[i].icon),
                selectedIcon: Icon(_destinations[i].selected),
                label: _destinations[i].label,
                tooltip: _destinations[i].label,
              ),
            ),
        ],
      ),
    );
  }
}

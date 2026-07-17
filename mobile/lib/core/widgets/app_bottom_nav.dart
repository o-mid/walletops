import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared shell chrome for primary tabs. Route jobs unchanged.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.selectedIndex});

  /// 0 = Events, 1 = Rules
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        if (i == selectedIndex) {
          return;
        }
        if (i == 0) {
          context.go('/events');
        } else if (i == 1) {
          context.go('/rules');
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.inbox_outlined),
          selectedIcon: Icon(Icons.inbox),
          label: 'Events',
        ),
        NavigationDestination(
          icon: Icon(Icons.rule_outlined),
          selectedIcon: Icon(Icons.rule),
          label: 'Rules',
        ),
      ],
    );
  }
}

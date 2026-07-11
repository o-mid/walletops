import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EventsStubPage extends StatelessWidget {
  const EventsStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: const Center(
        child: Text('Event feed comes next.'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 1) {
            context.go('/rules');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.rule_outlined),
            label: 'Rules',
          ),
        ],
      ),
    );
  }
}

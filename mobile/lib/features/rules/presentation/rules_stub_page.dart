import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RulesStubPage extends StatelessWidget {
  const RulesStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert rules')),
      body: const Center(
        child: Text('Alert rules UI comes next.'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (i) {
          if (i == 0) {
            context.go('/events');
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

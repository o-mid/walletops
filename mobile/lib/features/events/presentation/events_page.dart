import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../data/event_models.dart';
import 'cubit/events_cubit.dart';
import 'cubit/events_state.dart';
import 'widgets/status_chip.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          PopupMenuButton<String?>(
            tooltip: 'Filter status',
            onSelected: (value) =>
                context.read<EventsCubit>().setFilter(value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: null, child: Text('All')),
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(value: 'processing', child: Text('Processing')),
              PopupMenuItem(value: 'processed', child: Text('Processed')),
              PopupMenuItem(value: 'failed', child: Text('Failed')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: BlocBuilder<EventsCubit, EventsState>(
        builder: (context, state) {
          return switch (state.status) {
            EventsStatus.initial || EventsStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
            EventsStatus.empty => RefreshIndicator(
                onRefresh: () => context.read<EventsCubit>().refresh(),
                child: ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No events yet')),
                  ],
                ),
              ),
            EventsStatus.error => RefreshIndicator(
                onRefresh: () => context.read<EventsCubit>().refresh(),
                child: ListView(
                  children: [
                    const SizedBox(height: 120),
                    Center(child: Text(state.errorMessage ?? 'Failed to load')),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => context.read<EventsCubit>().refresh(),
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            EventsStatus.ready => RefreshIndicator(
                onRefresh: () => context.read<EventsCubit>().refresh(),
                child: EventsListView(items: state.items),
              ),
          };
        },
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

class EventsListView extends StatelessWidget {
  const EventsListView({super.key, required this.items});

  final List<OpsEvent> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = items[index];
        return ListTile(
          title: Text(event.type),
          subtitle: Text(event.idempotencyKey),
          trailing: StatusChip(status: event.status),
          onTap: () => context.push('/events/${event.id}'),
        );
      },
    );
  }
}

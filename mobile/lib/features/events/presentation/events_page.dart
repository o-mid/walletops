import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/ops_list_row.dart';
import '../data/event_models.dart';
import 'cubit/events_cubit.dart';
import 'cubit/events_state.dart';
import 'widgets/status_chip.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  static const _filters = <FilterOption<String?>>[
    FilterOption(value: null, label: 'All'),
    FilterOption(value: 'pending', label: 'Pending'),
    FilterOption(value: 'processing', label: 'Processing'),
    FilterOption(value: 'processed', label: 'Processed'),
    FilterOption(value: 'failed', label: 'Failed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<EventsCubit>().refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<EventsCubit, EventsState>(
            buildWhen: (prev, next) => prev.filter != next.filter,
            builder: (context, state) {
              return FilterChipBar<String?>(
                options: _filters,
                selected: state.filter,
                onSelected: (value) =>
                    context.read<EventsCubit>().setFilter(value),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<EventsCubit, EventsState>(
              builder: (context, state) {
                return switch (state.status) {
                  EventsStatus.initial || EventsStatus.loading =>
                    const LoadingState(label: 'Loading events'),
                  EventsStatus.empty => RefreshIndicator(
                      onRefresh: () => context.read<EventsCubit>().refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.55,
                            child: EmptyState(
                              title: 'No events yet',
                              message: state.filter == null
                                  ? 'Seed demo webhooks, then pull to refresh:\n'
                                      './scripts/seed_webhooks.sh\n\n'
                                      'Flow: HMAC ingest → pending → worker claim → processed.'
                                  : 'No events match this status filter.',
                              actionLabel: 'Refresh',
                              onAction: () =>
                                  context.read<EventsCubit>().refresh(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  EventsStatus.error => RefreshIndicator(
                      onRefresh: () => context.read<EventsCubit>().refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.55,
                            child: ErrorState(
                              message: state.errorMessage ?? 'Failed to load',
                              onRetry: () =>
                                  context.read<EventsCubit>().refresh(),
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
        return OpsListRow(
          title: event.type,
          subtitle: '${event.listSubtitle}\n${event.idempotencyKey}',
          trailing: StatusChip(status: event.status),
          onTap: () => context.push('/events/${event.id}'),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
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
      floatingActionButton: BlocBuilder<EventsCubit, EventsState>(
        buildWhen: (p, n) => p.demoBusy != n.demoBusy,
        builder: (context, state) {
          return FloatingActionButton.extended(
            onPressed: state.demoBusy
                ? null
                : () => _confirmGuidedDemo(context),
            icon: state.demoBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(state.demoBusy ? 'Demo running…' : 'Run live demo'),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ProcessGuideBanner(),
          BlocBuilder<EventsCubit, EventsState>(
            buildWhen: (p, n) =>
                p.journeyMessage != n.journeyMessage ||
                p.liveWatching != n.liveWatching ||
                p.demoBusy != n.demoBusy,
            builder: (context, state) {
              if (state.journeyMessage == null && !state.liveWatching) {
                return const SizedBox.shrink();
              }
              return _JourneyBanner(
                message: state.journeyMessage ??
                    'Live refresh on — watching PENDING / PROCESSING…',
                live: state.liveWatching || state.demoBusy,
              );
            },
          ),
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
                            height: MediaQuery.sizeOf(context).height * 0.45,
                            child: EmptyState(
                              title: 'No events yet',
                              message: state.filter == null
                                  ? 'Tap “Run live demo” to inject webhooks one by one '
                                      'and watch PENDING → PROCESSING → PROCESSED.\n\n'
                                      'Or seed from the Mac:\n./scripts/seed_webhooks.sh'
                                  : 'No events match this status filter.',
                              actionLabel: state.filter == null
                                  ? 'Run live demo'
                                  : 'Refresh',
                              onAction: () {
                                if (state.filter == null) {
                                  _confirmGuidedDemo(context);
                                } else {
                                  context.read<EventsCubit>().refresh();
                                }
                              },
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

  Future<void> _confirmGuidedDemo(BuildContext context) async {
    final cubit = context.read<EventsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Run live webhook demo?'),
          content: Text(
            'This will:\n'
            '1. Ensure a “Demo balance watch” alert rule exists\n'
            '2. Inject 3 simulated partner webhooks one by one\n'
            '3. Auto-refresh so you can see PENDING → PROCESSING → PROCESSED\n\n'
            'Stay on this screen while it runs (~20–40 seconds with the demo worker delay).',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Start demo'),
            ),
          ],
        );
      },
    );
    if (ok == true && context.mounted) {
      await cubit.runGuidedDemo();
    }
  }
}

class _ProcessGuideBanner extends StatelessWidget {
  const _ProcessGuideBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HOW THE PIPELINE WORKS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Partner webhook → HMAC verify → PENDING queue → worker '
              'SKIP LOCKED claim → PROCESSING → match rules → PROCESSED '
              '→ optional Explain summary.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyBanner extends StatelessWidget {
  const _JourneyBanner({required this.message, required this.live});

  final String message;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              live ? Icons.sensors : Icons.info_outline,
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = items[index];
        return OpsListRow(
          title: event.type,
          subtitle:
              '${event.listSubtitle}\n${_ageLabel(event)} · ${event.idempotencyKey}',
          trailing: StatusChip(status: event.status),
          onTap: () => context.push('/events/${event.id}'),
        );
      },
    );
  }

  String _ageLabel(OpsEvent event) {
    final end = event.processedAt ?? DateTime.now().toUtc();
    final ms = end.difference(event.receivedAt.toUtc()).inMilliseconds;
    if (ms < 1000) {
      return '${ms}ms in pipeline';
    }
    return '${(ms / 1000).toStringAsFixed(1)}s in pipeline';
  }
}

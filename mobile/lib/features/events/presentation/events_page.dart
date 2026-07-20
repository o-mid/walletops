import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/loading_state.dart';
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
            onPressed:
                state.demoBusy ? null : () => _confirmGuidedDemo(context),
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
                p.demoBusy != n.demoBusy ||
                p.demoStep != n.demoStep ||
                p.demoTotal != n.demoTotal,
            builder: (context, state) {
              if (state.journeyMessage == null &&
                  !state.liveWatching &&
                  !state.demoBusy) {
                return const SizedBox.shrink();
              }
              return _JourneyBanner(state: state);
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
                                  ? 'Start the guided demo to inject webhooks '
                                      'one by one and watch the queue move.\n\n'
                                      'Path of least effort: tap Run live demo below.'
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
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Run live webhook demo?', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Confirmation before a multi-step action — you’ll see each '
                'status change before the next webhook is injected.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _ConfirmStep(
                index: '1',
                title: 'Ensure demo alert rule',
                detail: 'Creates “Demo balance watch” if missing',
              ),
              const _ConfirmStep(
                index: '2',
                title: 'Inject 3 webhooks slowly',
                detail: '~8s processing hold + pause between each',
              ),
              const _ConfirmStep(
                index: '3',
                title: 'Watch the queue live',
                detail: 'PENDING → PROCESSING → PROCESSED with auto-refresh',
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Start demo'),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
    if (ok == true && context.mounted) {
      await cubit.runGuidedDemo();
    }
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.index,
    required this.title,
    required this.detail,
  });

  final String index;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            ),
            child: Text(
              index,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
              'PIPELINE OVERVIEW',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Webhook → verify → PENDING → worker claim → PROCESSING → '
              'match rules → PROCESSED → Explain',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyBanner extends StatelessWidget {
  const _JourneyBanner({required this.state});

  final EventsState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final live = state.liveWatching || state.demoBusy;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
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
            if (state.demoTotal > 0) ...[
              Row(
                children: [
                  Text(
                    'DEMO PROGRESS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${state.demoStep.clamp(0, state.demoTotal)} / ${state.demoTotal}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: state.demoBusy
                      ? (state.demoStep + 0.35) / state.demoTotal
                      : state.demoProgress,
                  minHeight: 6,
                  backgroundColor: scheme.surface.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
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
                    state.journeyMessage ??
                        'Live refresh on — watching PENDING / PROCESSING…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = items[index];
        return _EventRow(event: event);
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final OpsEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = switch (event.status) {
      'pending' => scheme.secondary,
      'processing' => scheme.tertiary,
      'processed' => scheme.primary,
      'failed' => scheme.error,
      _ => scheme.outline,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/events/${event.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.type.replaceAll('_', ' '),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              event.listSubtitle,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_ageLabel(event)}  ·  ${event.idempotencyKey}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusChip(status: event.status),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ageLabel(OpsEvent event) {
    final end = event.processedAt ?? DateTime.now().toUtc();
    final ms = end.difference(event.receivedAt.toUtc()).inMilliseconds;
    if (ms < 1000) {
      return '${ms}ms';
    }
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }
}

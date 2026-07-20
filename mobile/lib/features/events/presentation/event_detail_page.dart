import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../data/event_models.dart';
import 'cubit/event_detail_cubit.dart';
import 'cubit/event_detail_state.dart';
import 'widgets/status_chip.dart';

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: BlocBuilder<EventDetailCubit, EventDetailState>(
        builder: (context, state) {
          return switch (state.status) {
            EventDetailStatus.initial || EventDetailStatus.loading =>
              const LoadingState(label: 'Loading event'),
            EventDetailStatus.error => ErrorState(
                message: state.errorMessage ?? 'Failed to load',
                onRetry: () => context.read<EventDetailCubit>().load(eventId),
              ),
            EventDetailStatus.ready => _DetailBody(state: state),
          };
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.state});

  final EventDetailState state;

  @override
  Widget build(BuildContext context) {
    final event = state.event!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                event.type,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusChip(status: event.status),
          ],
        ),
        if (event.amount != null || event.asset != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              if (event.amount != null) '${event.amount}',
              if (event.asset != null) event.asset!,
              if (event.addressLabel != null) '· ${event.addressLabel}',
            ].join(' '),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Backend pipeline', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'What the Go API and worker did with this webhook.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _PipelineCard(event: event),
        const SizedBox(height: AppSpacing.lg),
        Text('Identifiers', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _MetaBlock(
          children: [
            _MetaLine(label: 'Event id', value: event.id),
            _MetaLine(label: 'Idempotency key', value: event.idempotencyKey),
            _MetaLine(label: 'Attempt count', value: '${event.attemptCount}'),
            _MetaLine(label: 'Received', value: _fmt(event.receivedAt)),
            if (event.processedAt != null)
              _MetaLine(
                label: 'Processed / last transition',
                value: _fmt(event.processedAt!),
              ),
            if (event.matchedRuleId != null)
              _MetaLine(label: 'Matched rule id', value: event.matchedRuleId!),
          ],
        ),
        if (event.lastError != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last worker error',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  event.lastError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Webhook payload', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Stored as jsonb after HMAC verification. Explain uses allowlisted '
          'fields only (type, amount, status, rule name).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: SelectableText(
            event.prettyPayload,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.45,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonal(
          onPressed: () => context.push('/explain?ids=${event.id}'),
          child: const Text('Explain with schema summary'),
        ),
      ],
    );
  }

  String _fmt(DateTime value) {
    final local = value.toLocal();
    return '${local.toIso8601String().replaceFirst('T', ' ').split('.').first} '
        '(local)';
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.event});

  final OpsEvent event;

  @override
  Widget build(BuildContext context) {
    final steps = _steps(event);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Container(
                    width: 2,
                    height: 12,
                    color: scheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: steps[i].done
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    steps[i].done ? Icons.check : Icons.circle,
                    size: steps[i].done ? 14 : 8,
                    color: steps[i].done
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: steps[i].active
                              ? scheme.primary
                              : scheme.onSurface,
                        ),
                      ),
                      Text(
                        steps[i].detail,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<_PipeStep> _steps(OpsEvent event) {
    final pending = event.status == 'pending';
    final processing = event.status == 'processing';
    final processed = event.status == 'processed';
    final failed = event.status == 'failed';
    final pastQueue = processing || processed || failed;

    return [
      const _PipeStep(
        title: '1. Webhook accepted',
        detail: 'POST /v1/webhooks/events · HMAC verified · idempotent insert',
        done: true,
        active: false,
      ),
      _PipeStep(
        title: '2. Queued as pending',
        detail: pending
            ? 'Waiting for FOR UPDATE SKIP LOCKED claim'
            : 'Left the pending queue',
        done: pastQueue || pending,
        active: pending,
      ),
      _PipeStep(
        title: '3. Worker claim',
        detail: processing
            ? 'status=processing · claim lease held'
            : processed || failed
                ? 'Claim completed · attempts=${event.attemptCount}'
                : 'Not claimed yet',
        done: processing || processed || failed,
        active: processing,
      ),
      _PipeStep(
        title: '4. Match rules / validate payload',
        detail: processed
            ? (event.matchedRuleId != null
                ? 'Rule matched · id ${event.matchedRuleId}'
                : 'No enabled rule matched this type/threshold')
            : failed
                ? 'Validation or processing error recorded'
                : 'Runs inside the worker after claim',
        done: processed || failed,
        active: false,
      ),
      _PipeStep(
        title: failed ? '5. Marked failed' : '5. Marked processed',
        detail: processed
            ? 'Ready for Explain · schema-checked summary'
            : failed
                ? (event.lastError ??
                    'Will retry with backoff until max attempts')
                : 'Final status not reached',
        done: processed || failed,
        active: processed || failed,
      ),
    ];
  }
}

class _PipeStep {
  const _PipeStep({
    required this.title,
    required this.detail,
    required this.done,
    required this.active,
  });

  final String title;
  final String detail;
  final bool done;
  final bool active;
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

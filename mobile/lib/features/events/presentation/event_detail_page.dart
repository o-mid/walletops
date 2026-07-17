import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
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
        const SizedBox(height: AppSpacing.md),
        _MetaBlock(
          children: [
            _MetaLine(label: 'Key', value: event.idempotencyKey),
            _MetaLine(
              label: 'Received',
              value: event.receivedAt.toLocal().toString(),
            ),
            if (event.processedAt != null)
              _MetaLine(
                label: 'Processed',
                value: event.processedAt!.toLocal().toString(),
              ),
            if (event.matchedRuleId != null)
              _MetaLine(label: 'Matched rule', value: event.matchedRuleId!),
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
                  'Last error',
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
        Text('Payload', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
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
          child: const Text('Explain'),
        ),
      ],
    );
  }
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
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

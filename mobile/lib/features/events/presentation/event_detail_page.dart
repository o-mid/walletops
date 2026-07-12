import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'cubit/event_detail_cubit.dart';
import 'cubit/event_detail_state.dart';
import 'widgets/status_chip.dart';

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event detail')),
      body: BlocBuilder<EventDetailCubit, EventDetailState>(
        builder: (context, state) {
          return switch (state.status) {
            EventDetailStatus.initial ||
            EventDetailStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            EventDetailStatus.error => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.errorMessage ?? 'Failed to load'),
                    TextButton(
                      onPressed: () =>
                          context.read<EventDetailCubit>().load(eventId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                event.type,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            StatusChip(status: event.status),
          ],
        ),
        const SizedBox(height: 8),
        Text('Key: ${event.idempotencyKey}'),
        Text('Received: ${event.receivedAt.toLocal()}'),
        if (event.processedAt != null)
          Text('Processed: ${event.processedAt!.toLocal()}'),
        if (event.matchedRuleId != null)
          Text('Matched rule: ${event.matchedRuleId}'),
        if (event.lastError != null) ...[
          const SizedBox(height: 8),
          Text(
            'Last error: ${event.lastError}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Text('Payload', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SelectableText(
          event.prettyPayload,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        const SizedBox(height: 24),
        FilledButton.tonal(
          onPressed: () => context.push('/explain?ids=${event.id}'),
          child: const Text('Explain'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/explain_cubit.dart';
import 'cubit/explain_state.dart';

class ExplainPage extends StatelessWidget {
  const ExplainPage({super.key, required this.eventIds});

  final List<String> eventIds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explain')),
      body: BlocBuilder<ExplainCubit, ExplainState>(
        builder: (context, state) {
          return switch (state.status) {
            ExplainStatus.initial || ExplainStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
            ExplainStatus.error => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.errorMessage ?? 'Failed to summarize'),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.read<ExplainCubit>().retry(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ExplainStatus.ready => _SummaryBody(state: state),
          };
        },
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.state});

  final ExplainState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary!;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(summary.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            label: Text('Risk: ${summary.riskLevel}'),
            backgroundColor: switch (summary.riskLevel) {
              'high' => scheme.errorContainer,
              'medium' => scheme.tertiaryContainer,
              'low' => scheme.primaryContainer,
              _ => scheme.surfaceContainerHighest,
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Summary', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final bullet in summary.summaryBullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(bullet)),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('Follow-ups', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in summary.followUps)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('→ '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Events: ${summary.eventIds.length}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

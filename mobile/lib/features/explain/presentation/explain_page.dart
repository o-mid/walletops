import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
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
            ExplainStatus.initial || ExplainStatus.loading =>
              const LoadingState(label: 'Summarizing'),
            ExplainStatus.error => ErrorState(
                message: state.errorMessage ?? 'Failed to summarize',
                onRetry: () => context.read<ExplainCubit>().retry(),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(summary.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: _RiskChip(level: summary.riskLevel),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Summary', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final bullet in summary.summaryBullets)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(bullet, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text('Follow-ups', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < summary.followUps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}.',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    summary.followUps[i],
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Events: ${summary.eventIds.length}',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (level) {
      'high' => (scheme.errorContainer, scheme.onErrorContainer),
      'medium' => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      'low' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        'Risk: $level',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

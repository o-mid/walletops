import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/ops_list_row.dart';
import 'cubit/rules_cubit.dart';
import 'cubit/rules_state.dart';
import 'rule_form_sheet.dart';

class RulesPage extends StatelessWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<RulesCubit>().refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showRuleFormSheet(context),
        tooltip: 'New rule',
        child: const Icon(Icons.add),
      ),
      body: BlocConsumer<RulesCubit, RulesState>(
        listener: (context, state) {
          if (state.errorMessage != null && state.status != RulesStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          return switch (state.status) {
            RulesStatus.initial || RulesStatus.loading =>
              const LoadingState(label: 'Loading rules'),
            RulesStatus.empty => RefreshIndicator(
                onRefresh: () => context.read<RulesCubit>().refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.55,
                      child: EmptyState(
                        title: 'No alert rules yet',
                        message:
                            'Rules run in the Go worker after claim.\n'
                            'Seed creates “Demo balance watch” (balance_drop ≤ 150).',
                        icon: Icons.rule_outlined,
                        actionLabel: 'New rule',
                        onAction: () => showRuleFormSheet(context),
                      ),
                    ),
                  ],
                ),
              ),
            RulesStatus.error => RefreshIndicator(
                onRefresh: () => context.read<RulesCubit>().refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.55,
                      child: ErrorState(
                        message: state.errorMessage ?? 'Failed to load',
                        onRetry: () => context.read<RulesCubit>().refresh(),
                      ),
                    ),
                  ],
                ),
              ),
            RulesStatus.ready => RefreshIndicator(
                onRefresh: () => context.read<RulesCubit>().refresh(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: state.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final rule = state.items[index];
                    return OpsListRow(
                      title: rule.name,
                      subtitle: [
                        rule.eventType,
                        if (rule.threshold != null) '≤ ${rule.threshold}',
                        rule.enabled ? 'enabled' : 'disabled',
                        'matched by worker',
                      ].join(' · '),
                      onTap: () => showRuleFormSheet(context, existing: rule),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: Icon(
                          Icons.delete_outline,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: () =>
                            context.read<RulesCubit>().remove(rule.id),
                      ),
                    );
                  },
                ),
              ),
          };
        },
      ),
    );
  }
}

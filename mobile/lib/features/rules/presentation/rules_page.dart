import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'cubit/rules_cubit.dart';
import 'cubit/rules_state.dart';
import 'rule_form_sheet.dart';

class RulesPage extends StatelessWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert rules')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showRuleFormSheet(context),
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
            RulesStatus.initial || RulesStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
            RulesStatus.empty => RefreshIndicator(
                onRefresh: () => context.read<RulesCubit>().refresh(),
                child: ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No alert rules yet')),
                  ],
                ),
              ),
            RulesStatus.error => RefreshIndicator(
                onRefresh: () => context.read<RulesCubit>().refresh(),
                child: ListView(
                  children: [
                    const SizedBox(height: 120),
                    Center(child: Text(state.errorMessage ?? 'Failed to load')),
                    Center(
                      child: TextButton(
                        onPressed: () => context.read<RulesCubit>().refresh(),
                        child: const Text('Retry'),
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
                    return ListTile(
                      title: Text(rule.name),
                      subtitle: Text(
                        [
                          rule.eventType,
                          if (rule.threshold != null) '≤ ${rule.threshold}',
                          rule.enabled ? 'enabled' : 'disabled',
                        ].join(' · '),
                      ),
                      onTap: () => showRuleFormSheet(context, existing: rule),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (i) {
          if (i == 0) {
            context.go('/events');
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

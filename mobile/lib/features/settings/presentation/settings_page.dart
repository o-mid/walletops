import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/demo_credentials.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../../ops/presentation/widgets/ops_status_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthCubit>().state.user?.email ?? '—';
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const OpsStatusBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              'Account',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _SettingsTile(label: 'Signed in as', value: email),
          _SettingsTile(label: 'API base', value: kApiBase),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              'Local demo',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _SettingsTile(label: 'Demo email', value: kDemoEmail, copyable: true),
          _SettingsTile(
            label: 'Demo password',
            value: kDemoPassword,
            copyable: true,
          ),
          _SettingsTile(
            label: 'Webhook user_ref',
            value: kDemoUserRef,
            copyable: true,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              '1) docker compose up --build -d\n'
              '2) ./scripts/seed_webhooks.sh\n'
              '3) Sign in with the demo account\n'
              '4) Watch Events status move pending → processed\n'
              '5) Open an event for the backend pipeline + Explain',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text(
              'Log out',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              await context.read<AuthCubit>().logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: 'Copy',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied $label')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined, size: 18),
            ),
        ],
      ),
    );
  }
}

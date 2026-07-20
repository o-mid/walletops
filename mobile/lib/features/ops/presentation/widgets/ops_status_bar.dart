import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/health_models.dart';
import '../cubit/ops_health_cubit.dart';
import '../cubit/ops_health_state.dart';

class OpsStatusBar extends StatelessWidget {
  const OpsStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OpsHealthCubit, OpsHealthState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final ok = state.ok;
        final health = state.health;

        return Material(
          color: ok
              ? scheme.surfaceContainerLow
              : scheme.errorContainer.withValues(alpha: 0.55),
          child: InkWell(
            onTap: () => context.read<OpsHealthCubit>().refresh(),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                  left: BorderSide(
                    color: ok ? scheme.primary : scheme.error,
                    width: 3,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      ok ? Icons.monitor_heart_outlined : Icons.cloud_off_outlined,
                      size: 18,
                      color: ok ? scheme.primary : scheme.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _headline(state),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: ok ? scheme.onSurface : scheme.error,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _detail(state, health),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _headline(OpsHealthState state) {
    if (state.status == OpsHealthStatus.loading && state.health == null) {
      return 'Checking API…';
    }
    if (state.errorMessage != null && state.health == null) {
      return state.errorMessage!;
    }
    final health = state.health;
    if (health == null) {
      return 'API unknown';
    }
    final tick = health.worker?.lastTick;
    final tickLabel = tick == null ? 'no tick yet' : _ago(tick);
    return 'API ${health.status} · worker $tickLabel';
  }

  String _detail(OpsHealthState state, OpsHealth? health) {
    if (health?.queue == null) {
      return 'Tap to refresh · webhook → queue → worker → mobile';
    }
    final q = health!.queue!;
    final worker = health.worker;
    final totals = worker == null
        ? ''
        : ' · worker processed ${worker.processedTotal}, errors ${worker.errorTotal}';
    final oldest = q.oldestPendingSeconds == null
        ? ''
        : ' · oldest pending ${q.oldestPendingSeconds!.round()}s';
    return 'Queue pending ${q.count('pending')} · '
        'processing ${q.count('processing')} · '
        'processed ${q.count('processed')} · '
        'failed ${q.count('failed')}$totals$oldest';
  }

  String _ago(DateTime when) {
    final seconds = DateTime.now().difference(when).inSeconds;
    if (seconds < 5) {
      return 'just now';
    }
    if (seconds < 60) {
      return '${seconds}s ago';
    }
    return '${when.hour.toString().padLeft(2, '0')}:'
        '${when.minute.toString().padLeft(2, '0')}';
  }
}

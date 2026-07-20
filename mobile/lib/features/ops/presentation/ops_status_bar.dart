import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/health_api.dart';
import '../data/health_models.dart';

/// Live strip of API / worker / queue state from `GET /v1/health`.
class OpsStatusBar extends StatefulWidget {
  const OpsStatusBar({super.key});

  @override
  State<OpsStatusBar> createState() => _OpsStatusBarState();
}

class _OpsStatusBarState extends State<OpsStatusBar> {
  OpsHealth? _health;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final health = await getIt<HealthApi>().fetch();
      if (!mounted) {
        return;
      }
      setState(() {
        _health = health;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'API unreachable';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final health = _health;
    final ok = _error == null && (health?.ok ?? false);

    return Material(
      color: ok
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : scheme.errorContainer.withValues(alpha: 0.45),
      child: InkWell(
        onTap: _refresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                ok ? Icons.dns_outlined : Icons.cloud_off_outlined,
                size: 18,
                color: ok ? scheme.primary : scheme.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _error ?? _headline(health),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: ok ? scheme.onSurface : scheme.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _detail(health),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _headline(OpsHealth? health) {
    if (health == null) {
      return 'Checking API…';
    }
    final tick = health.worker?.lastTick;
    final tickLabel = tick == null ? 'no tick yet' : _ago(tick);
    return 'API ${health.status} · worker $tickLabel';
  }

  String _detail(OpsHealth? health) {
    if (health?.queue == null) {
      return 'Tap to refresh · webhook → queue → worker → mobile';
    }
    final q = health!.queue!;
    final pending = q.count('pending');
    final processing = q.count('processing');
    final processed = q.count('processed');
    final failed = q.count('failed');
    final worker = health.worker;
    final totals = worker == null
        ? ''
        : ' · worker processed ${worker.processedTotal}, errors ${worker.errorTotal}';
    final oldest = q.oldestPendingSeconds == null
        ? ''
        : ' · oldest pending ${q.oldestPendingSeconds!.round()}s';
    return 'Queue pending $pending · processing $processing · '
        'processed $processed · failed $failed$totals$oldest';
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

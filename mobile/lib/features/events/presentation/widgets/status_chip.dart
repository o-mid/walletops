import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      'processed' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      'failed' => (scheme.errorContainer, scheme.onErrorContainer),
      'processing' => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      'pending' => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

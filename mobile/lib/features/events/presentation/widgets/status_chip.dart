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
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

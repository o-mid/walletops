import 'package:flutter/material.dart';

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
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    return Chip(
      label: Text(status),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg, fontSize: 12),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

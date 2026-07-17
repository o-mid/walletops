import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class FilterOption<T> {
  const FilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Horizontal filter chips — same selection model as a popup menu.
class FilterChipBar<T> extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          itemCount: options.length,
          separatorBuilder: (context, index) {
            return const SizedBox(width: AppSpacing.xs);
          },
          itemBuilder: (context, index) {
            final option = options[index];
            final isSelected = option.value == selected;
            return FilterChip(
              label: Text(option.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(option.value),
              selectedColor: scheme.primaryContainer,
              backgroundColor: scheme.surface,
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
              side: BorderSide(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.35)
                    : scheme.outlineVariant.withValues(alpha: 0.7),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          },
        ),
      ),
    );
  }
}

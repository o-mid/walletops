import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_spacing.dart';

abstract final class AppColors {
  static const ink = Color(0xFF0B1220);
  static const slate = Color(0xFF1A2433);
  static const graphite = Color(0xFF243044);
  static const mistBlue = Color(0xFFE8EEF4);
  static const panelLight = Color(0xFFF4F7FA);
  static const cyan = Color(0xFF0E7490);
  static const cyanBright = Color(0xFF22D3EE);
  static const amber = Color(0xFFB45309);
  static const amberBright = Color(0xFFFBBF24);
  static const danger = Color(0xFFDC2626);
  static const outlineLight = Color(0xFFC5D0DC);
  static const outlineDark = Color(0xFF3A4A5E);
}

ThemeData buildAppTheme() => _buildTheme(Brightness.light);

ThemeData buildAppDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: isLight ? AppColors.cyan : AppColors.cyanBright,
    onPrimary: isLight ? Colors.white : AppColors.ink,
    primaryContainer:
        isLight ? const Color(0xFFCFF4FC) : const Color(0xFF164E63),
    onPrimaryContainer:
        isLight ? const Color(0xFF083344) : const Color(0xFFCFFAFE),
    secondary: isLight ? AppColors.amber : AppColors.amberBright,
    onSecondary: isLight ? Colors.white : AppColors.ink,
    secondaryContainer:
        isLight ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
    onSecondaryContainer:
        isLight ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
    tertiary: isLight ? const Color(0xFF0369A1) : const Color(0xFF7DD3FC),
    onTertiary: isLight ? Colors.white : AppColors.ink,
    tertiaryContainer:
        isLight ? const Color(0xFFBAE6FD) : const Color(0xFF0C4A6E),
    onTertiaryContainer:
        isLight ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE),
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer:
        isLight ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D),
    onErrorContainer:
        isLight ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
    surface: isLight ? Colors.white : AppColors.slate,
    onSurface: isLight ? AppColors.ink : const Color(0xFFE8EEF4),
    onSurfaceVariant:
        isLight ? const Color(0xFF4B5C6E) : const Color(0xFFA8B8C8),
    outline: isLight ? AppColors.outlineLight : AppColors.outlineDark,
    outlineVariant: isLight
        ? const Color(0xFFD5DEE8)
        : const Color(0xFF2E3C4F),
    surfaceContainerLowest:
        isLight ? Colors.white : const Color(0xFF0A1018),
    surfaceContainerLow:
        isLight ? AppColors.panelLight : const Color(0xFF121A26),
    surfaceContainer:
        isLight ? const Color(0xFFEDF2F7) : AppColors.graphite,
    surfaceContainerHigh:
        isLight ? const Color(0xFFE2E9F0) : const Color(0xFF2C3A4E),
    surfaceContainerHighest:
        isLight ? const Color(0xFFD6E0EA) : const Color(0xFF35465C),
    inverseSurface: isLight ? AppColors.ink : AppColors.mistBlue,
    onInverseSurface: isLight ? AppColors.mistBlue : AppColors.ink,
    inversePrimary: isLight ? AppColors.cyanBright : AppColors.cyan,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: isLight ? AppColors.cyan : AppColors.cyanBright,
  );

  final textTheme = _textTheme(scheme);
  final scaffold = isLight ? AppColors.mistBlue : AppColors.ink;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    textTheme: textTheme,
    dividerColor: scheme.outlineVariant.withValues(alpha: 0.8),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
      systemOverlayStyle:
          isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0.3,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 22,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: BorderSide(color: scheme.error),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        textStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      labelStyle: textTheme.labelMedium!,
      secondaryLabelStyle: textTheme.labelMedium!,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
      ),
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      minVerticalPadding: AppSpacing.xs,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      iconColor: scheme.onSurfaceVariant,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusMd),
        ),
      ),
      showDragHandle: true,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      circularTrackColor: scheme.primaryContainer,
    ),
  );
}

TextTheme _textTheme(ColorScheme scheme) {
  final base = Typography.material2021(
    platform: TargetPlatform.android,
  ).black.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return base.copyWith(
    headlineLarge: base.headlineLarge?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.1,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.15,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.2,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.25,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.15,
      height: 1.3,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: scheme.onSurface,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.35,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.45,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.55,
      color: scheme.onSurfaceVariant,
    ),
  );
}

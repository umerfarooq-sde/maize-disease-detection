import 'package:flutter/material.dart';
import 'design_tokens.dart';

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.forest,
      onPrimary: Colors.white,
      primaryContainer: AppColors.sage,
      onPrimaryContainer: AppColors.forestDark,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.mist,
      onSecondaryContainer: AppColors.blue,
      tertiary: AppColors.amber,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.wheat,
      onTertiaryContainer: AppColors.amber,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.muted,
      outlineVariant: AppColors.outline,
      error: AppColors.error,
      errorContainer: AppColors.errorSurface,
      onErrorContainer: AppColors.error,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 36,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
          labelLarge: const TextStyle(
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(
          fontFamily: 'Roboto',
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.small),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.outline),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSizing.touchTarget, AppSizing.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSizing.touchTarget, AppSizing.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: shape,
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizing.touchTarget, AppSizing.touchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.muted),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.sage,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.sage,
        selectedLabelTextStyle: text.labelMedium,
        unselectedLabelTextStyle: text.labelMedium,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        space: AppSpacing.xl,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.forest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
        backgroundColor: AppColors.ink,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';

abstract final class AppTheme {
  static const _lightScheme = ColorScheme.light(
    primary: AppColors.forest,
    onPrimary: Colors.white,
    primaryContainer: AppColors.sage,
    onPrimaryContainer: AppColors.forestDeep,
    secondary: AppColors.blue,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.blueLight,
    onSecondaryContainer: AppColors.blueDark,
    tertiary: AppColors.gold,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.goldLight,
    onTertiaryContainer: AppColors.goldDark,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: AppColors.ivorySurface,
    onSurface: AppColors.charcoal,
    onSurfaceVariant: Color(0xFF45514B),
    outline: Color(0xFF68736D),
    outlineVariant: Color(0xFFC4CCC6),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF5F3EC),
    surfaceContainer: Color(0xFFEFEEE7),
    surfaceContainerHigh: Color(0xFFE9E8E1),
    surfaceContainerHighest: Color(0xFFE3E2DB),
    inverseSurface: Color(0xFF2D322F),
    onInverseSurface: Color(0xFFF1F1EB),
    inversePrimary: AppColors.forestLight,
    shadow: Color(0xFF101814),
    scrim: Colors.black,
  );

  static const _darkScheme = ColorScheme.dark(
    primary: AppColors.forestLight,
    onPrimary: Color(0xFF003829),
    primaryContainer: Color(0xFF15513D),
    onPrimaryContainer: Color(0xFFB9F5DA),
    secondary: Color(0xFFA6CEE0),
    onSecondary: Color(0xFF073546),
    secondaryContainer: AppColors.blueDark,
    onSecondaryContainer: AppColors.blueLight,
    tertiary: Color(0xFFE8C36F),
    onTertiary: Color(0xFF402D00),
    tertiaryContainer: AppColors.goldDark,
    onTertiaryContainer: AppColors.goldLight,
    error: AppColors.errorDark,
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF111916),
    onSurface: Color(0xFFE0E6E1),
    onSurfaceVariant: Color(0xFFC0C9C2),
    outline: Color(0xFF89928C),
    outlineVariant: Color(0xFF3E4943),
    surfaceContainerLowest: Color(0xFF0C110F),
    surfaceContainerLow: Color(0xFF18211E),
    surfaceContainer: AppColors.charcoalSurface,
    surfaceContainerHigh: Color(0xFF2A3430),
    surfaceContainerHighest: Color(0xFF35403A),
    inverseSurface: Color(0xFFE0E6E1),
    onInverseSurface: Color(0xFF2D322F),
    inversePrimary: AppColors.forest,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static final ThemeData light = _build(_lightScheme);
  static final ThemeData dark = _build(_darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
    );
    final text = base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 36,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
          headlineLarge: const TextStyle(
            fontSize: 32,
            height: 1.16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.55,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: const TextStyle(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.55),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
          bodySmall: const TextStyle(fontSize: 12, height: 1.45),
          labelLarge: const TextStyle(
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.25,
          ),
        )
        .apply(
          fontFamily: 'Roboto',
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
    );
    final cardShape = RoundedRectangleBorder(
      side: BorderSide(color: scheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadii.card),
    );
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: scheme.surface,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: scheme.outlineVariant,
    );
    final semantic = dark
        ? const AppSemanticColors(
            success: AppColors.successDark,
            onSuccess: Color(0xFF003919),
            successContainer: Color(0xFF12512E),
            onSuccessContainer: Color(0xFFA7F3BD),
            info: Color(0xFFA6CEE0),
            onInfo: Color(0xFF073546),
            infoContainer: AppColors.blueDark,
            onInfoContainer: AppColors.blueLight,
            warning: Color(0xFFE8C36F),
            onWarning: Color(0xFF402D00),
            warningContainer: AppColors.goldDark,
            onWarningContainer: AppColors.goldLight,
            hero: Color(0xFF153D31),
            onHero: Color(0xFFE7FFF3),
          )
        : const AppSemanticColors(
            success: AppColors.success,
            onSuccess: Colors.white,
            successContainer: Color(0xFFD3F2DD),
            onSuccessContainer: Color(0xFF0B3B20),
            info: AppColors.blue,
            onInfo: Colors.white,
            infoContainer: AppColors.blueLight,
            onInfoContainer: AppColors.blueDark,
            warning: AppColors.gold,
            onWarning: Colors.white,
            warningContainer: AppColors.goldLight,
            onWarningContainer: AppColors.goldDark,
            hero: AppColors.forestDeep,
            onHero: Colors.white,
          );

    return base.copyWith(
      scaffoldBackgroundColor: dark ? const Color(0xFF0F1714) : AppColors.ivory,
      canvasColor: scheme.surface,
      disabledColor: scheme.onSurface.withValues(alpha: 0.38),
      textTheme: text,
      primaryTextTheme: text,
      extensions: [semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF0F1714) : AppColors.ivory,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.level0,
        scrolledUnderElevation: AppElevation.level0,
        centerTitle: false,
        titleSpacing: AppSpacing.lg,
        titleTextStyle: text.titleMedium,
        systemOverlayStyle: overlay,
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.level0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSizing.touchTarget, AppSizing.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: controlShape,
          textStyle: text.labelLarge,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(AppSizing.touchTarget, AppSizing.touchTarget),
          elevation: AppElevation.level1,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: controlShape,
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
          shape: controlShape,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizing.touchTarget, AppSizing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSizing.touchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: AppElevation.level2,
        focusElevation: AppElevation.level2,
        hoverElevation: AppElevation.level3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
        ),
        helperStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.18),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizing.navigationHeight,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: AppElevation.level1,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.level3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.hero),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: scheme.scrim.withValues(alpha: 0.48),
        elevation: AppElevation.level3,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.hero),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        elevation: AppElevation.level2,
        shape: controlShape,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: AppSpacing.xl,
        thickness: AppSizing.divider,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
        ),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: scheme.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.level2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
    );
  }

  static SystemUiOverlayStyle systemOverlayStyle(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.colorScheme.surface,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: theme.colorScheme.outlineVariant,
    );
  }
}

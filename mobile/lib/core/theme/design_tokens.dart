import 'package:flutter/material.dart';

abstract final class AppColors {
  // Raw palette values belong in themes. Widgets should consume ColorScheme or
  // AppSemanticColors so that they adapt to brightness and contrast changes.
  static const forest = Color(0xFF174C38);
  static const forestDeep = Color(0xFF103B2A);
  static const forestLight = Color(0xFF8AD5AC);
  static const leaf = Color(0xFF287551);
  static const leafDark = Color(0xFF9BDAB7);
  static const ivory = Color(0xFFF7F8F3);
  static const ivorySurface = Color(0xFFFFFFFF);
  static const charcoal = Color(0xFF172B22);
  static const charcoalSurface = Color(0xFF223329);
  static const sage = Color(0xFFE1EDDF);
  static const sageDark = Color(0xFF214D38);
  static const gold = Color(0xFF795A12);
  static const goldLight = Color(0xFFFFF0CA);
  static const goldDark = Color(0xFF493B19);
  static const blue = Color(0xFF2563A6);
  static const blueLight = Color(0xFFE6EFFA);
  static const blueDark = Color(0xFF173655);
  static const error = Color(0xFFB42333);
  static const errorDark = Color(0xFFFFB4B8);
  static const success = Color(0xFF246442);
  static const successDark = Color(0xFF8BD6A5);
  static const highlight = Color(0xFFE4F09A);
  static const highlightDark = Color(0xFF465020);
  // Decorative accent only: white body text on earth fails AA contrast.
  static const earth = Color(0xFFB67A49);
  static const earthDark = Color(0xFFD8A77F);

  static const lightScheme = ColorScheme.light(
    primary: forest,
    onPrimary: ivorySurface,
    primaryContainer: sage,
    onPrimaryContainer: charcoal,
    secondary: blue,
    onSecondary: ivorySurface,
    secondaryContainer: blueLight,
    onSecondaryContainer: Color(0xFF123B64),
    tertiary: leaf,
    onTertiary: ivorySurface,
    tertiaryContainer: highlight,
    onTertiaryContainer: charcoal,
    error: error,
    onError: ivorySurface,
    errorContainer: Color(0xFFFDE8E9),
    onErrorContainer: Color(0xFF68131E),
    surface: ivorySurface,
    onSurface: charcoal,
    onSurfaceVariant: Color(0xFF4B6255),
    outline: Color(0xFF6D8072),
    outlineVariant: Color(0xFFD5DED4),
    surfaceContainerLowest: ivorySurface,
    surfaceContainerLow: ivory,
    surfaceContainer: Color(0xFFEFF3EC),
    surfaceContainerHigh: Color(0xFFE7EEE4),
    surfaceContainerHighest: Color(0xFFDDE7DA),
    inverseSurface: charcoal,
    onInverseSurface: ivory,
    inversePrimary: forestLight,
    shadow: charcoal,
    scrim: Colors.black,
  );
  static const darkCanvas = Color(0xFF101A15);
  static const darkScheme = ColorScheme.dark(
    primary: forestLight,
    onPrimary: forestDeep,
    primaryContainer: sageDark,
    onPrimaryContainer: Color(0xFFD9F4E2),
    secondary: Color(0xFF9BC7FF),
    onSecondary: Color(0xFF123B64),
    secondaryContainer: blueDark,
    onSecondaryContainer: Color(0xFFD9E9FF),
    tertiary: leafDark,
    onTertiary: forestDeep,
    tertiaryContainer: highlightDark,
    onTertiaryContainer: Color(0xFFEDF4C5),
    error: errorDark,
    onError: Color(0xFF68131E),
    errorContainer: Color(0xFF5A2028),
    onErrorContainer: Color(0xFFFFDADD),
    surface: Color(0xFF18251D),
    onSurface: Color(0xFFE5EFE8),
    onSurfaceVariant: Color(0xFFBACBBF),
    outline: Color(0xFF819487),
    outlineVariant: Color(0xFF3B4C40),
    surfaceContainerLowest: darkCanvas,
    surfaceContainerLow: Color(0xFF18251D),
    surfaceContainer: charcoalSurface,
    surfaceContainerHigh: Color(0xFF293D31),
    surfaceContainerHighest: Color(0xFF31493A),
    inverseSurface: ivory,
    onInverseSurface: charcoal,
    inversePrimary: forest,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static const lightSemantics = AppSemanticColors(
    success: success,
    onSuccess: ivorySurface,
    successContainer: Color(0xFFDDF0E2),
    onSuccessContainer: Color(0xFF173B27),
    info: blue,
    onInfo: ivorySurface,
    infoContainer: blueLight,
    onInfoContainer: Color(0xFF123B64),
    warning: gold,
    onWarning: ivorySurface,
    warningContainer: goldLight,
    onWarningContainer: Color(0xFF49350A),
    hero: forest,
    onHero: ivorySurface,
  );
  static const darkSemantics = AppSemanticColors(
    success: successDark,
    onSuccess: Color(0xFF173B27),
    successContainer: Color(0xFF1C432D),
    onSuccessContainer: Color(0xFFCBF0D6),
    info: Color(0xFF9BC7FF),
    onInfo: Color(0xFF123B64),
    infoContainer: blueDark,
    onInfoContainer: Color(0xFFD9E9FF),
    warning: Color(0xFFE8C36F),
    onWarning: Color(0xFF49350A),
    warningContainer: goldDark,
    onWarningContainer: Color(0xFFFFE7AE),
    hero: sageDark,
    onHero: Color(0xFFD9F4E2),
  );
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.hero,
    required this.onHero,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color hero;
  final Color onHero;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? hero,
    Color? onHero,
  }) => AppSemanticColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    info: info ?? this.info,
    onInfo: onInfo ?? this.onInfo,
    infoContainer: infoContainer ?? this.infoContainer,
    onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    hero: hero ?? this.hero,
    onHero: onHero ?? this.onHero,
  );

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      hero: Color.lerp(hero, other.hero, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 48.0;
}

abstract final class AppRadii {
  static const small = 10.0;
  static const medium = 14.0;
  static const card = 20.0;
  static const hero = 24.0;
  static const pill = 100.0;
}

abstract final class AppElevation {
  static const level0 = 0.0;
  static const level1 = 1.0;
  static const level2 = 3.0;
  static const level3 = 6.0;
}

abstract final class AppSizing {
  static const touchTarget = 48.0;
  static const primaryButtonHeight = 56.0;
  static const readingMaxWidth = 720.0;
  static const authenticationMaxWidth = 480.0;
  static const formMaxWidth = 760.0;
  static const icon = 24.0;
  static const stateIcon = 36.0;
  static const iconTile = 48.0;
  static const emblem = 64.0;
  static const navigationHeight = 80.0;
  static const railWidth = 112.0;
  static const tabletBreakpoint = 840.0;
  static const compactBreakpoint = 360.0;
  static const twoColumnBreakpoint = 620.0;
  static const contentMaxWidth = 1120.0;
  static const comfortableTextScale = 1.5;
  static const divider = 1.0;
}

abstract final class AppMotion {
  static const button = Duration(milliseconds: 100);
  static const navigation = Duration(milliseconds: 180);
  static const reveal = Duration(milliseconds: 220);
  static const theme = Duration(milliseconds: 240);

  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

abstract final class AppTypography {
  static const family = 'Plus Jakarta Sans';
  static const fallback = ['Roboto', 'sans-serif'];
  static const hero = TextStyle(
    fontSize: 32,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  static const screenTitle = TextStyle(
    fontSize: 28,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const compactTitle = TextStyle(
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const section = TextStyle(
    fontSize: 20,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const cardTitle = TextStyle(
    fontSize: 18,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  static const supporting = TextStyle(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  static const label = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const metadata = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );
  static const metric = TextStyle(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const textTheme = TextTheme(
    displayLarge: hero,
    displayMedium: hero,
    displaySmall: hero,
    headlineLarge: hero,
    headlineMedium: screenTitle,
    headlineSmall: compactTitle,
    titleLarge: section,
    titleMedium: cardTitle,
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: supporting,
    labelLarge: label,
    labelMedium: label,
    labelSmall: metadata,
  );
}

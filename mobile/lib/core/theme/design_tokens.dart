import 'package:flutter/material.dart';

abstract final class AppColors {
  // Raw palette values belong in themes. Widgets should consume ColorScheme or
  // AppSemanticColors so that they adapt to brightness and contrast changes.
  static const forest = Color(0xFF1F5A45);
  static const forestDeep = Color(0xFF103D2F);
  static const forestLight = Color(0xFF78D5AE);
  static const ivory = Color(0xFFFAF8F1);
  static const ivorySurface = Color(0xFFFFFDF7);
  static const charcoal = Color(0xFF18211E);
  static const charcoalSurface = Color(0xFF202A26);
  static const sage = Color(0xFFD8E9DF);
  static const sageDark = Color(0xFF29483B);
  static const gold = Color(0xFF8A6418);
  static const goldLight = Color(0xFFFFDEA0);
  static const goldDark = Color(0xFF59430F);
  static const blue = Color(0xFF315D78);
  static const blueLight = Color(0xFFCDE8F7);
  static const blueDark = Color(0xFF193D51);
  static const error = Color(0xFFBA1A1A);
  static const errorDark = Color(0xFFFFB4AB);
  static const success = Color(0xFF28633F);
  static const successDark = Color(0xFF8BD6A5);
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
  static const section = 40.0;
}

abstract final class AppRadii {
  static const small = 10.0;
  static const medium = 14.0;
  static const card = 18.0;
  static const hero = 26.0;
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

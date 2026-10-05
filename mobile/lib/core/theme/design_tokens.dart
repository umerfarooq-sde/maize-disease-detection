import 'package:flutter/material.dart';

abstract final class AppColors {
  static const forest = Color(0xFF245443);
  static const forestDark = Color(0xFF183D32);
  static const canvas = Color(0xFFF8F7F2);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF202D29);
  static const muted = Color(0xFF56665F);
  static const outline = Color(0xFFD9E0D9);
  static const sage = Color(0xFFE9F0E9);
  static const amber = Color(0xFF765616);
  static const wheat = Color(0xFFFAEBCB);
  static const blue = Color(0xFF315875);
  static const mist = Color(0xFFE9F0F7);
  static const error = Color(0xFFAA3535);
  static const errorSurface = Color(0xFFFFEDEB);
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
  static const small = 12.0;
  static const card = 20.0;
  static const hero = 28.0;
  static const pill = 100.0;
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

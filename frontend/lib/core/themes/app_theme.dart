import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_sizes.dart';

/// Global App Theme
class AppTheme {

  // =========================
  // Light Theme
  // =========================

  static ThemeData lightTheme = ThemeData(

    // Enable Material 3
    useMaterial3: true,

    // Global App Font
    fontFamily: 'Poppins',

    // Brightness
    brightness: Brightness.light,

    // Primary App Color
    primaryColor: AppColors.primary,

    // Background Color
    scaffoldBackgroundColor: AppColors.background,

    // AppBar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: AppTextStyles.headingMedium.copyWith(
        color: AppColors.white,
      ),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,

        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingLarge,
          vertical: AppSizes.paddingMedium,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radiusMedium,
          ),
        ),

        textStyle: AppTextStyles.button,
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(

      filled: true,
      fillColor: AppColors.white,

      contentPadding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radiusMedium,
        ),
        borderSide: BorderSide(
          color: AppColors.border,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radiusMedium,
        ),
        borderSide: BorderSide(
          color: AppColors.border,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radiusMedium,
        ),
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radiusMedium,
        ),
      ),
    ),

    // Text Theme
    textTheme: TextTheme(

      headlineLarge: AppTextStyles.headingLarge,

      headlineMedium: AppTextStyles.headingMedium,

      bodyLarge: AppTextStyles.bodyLarge,

      bodyMedium: AppTextStyles.bodyMedium,

      labelLarge: AppTextStyles.button,
    ),
  );
}
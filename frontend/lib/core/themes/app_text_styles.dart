import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';

/// Centralized text styles
/// Reuse everywhere to maintain consistency
class AppTextStyles {

  // =========================
  // Heading Styles
  // =========================

  static TextStyle headingLarge = TextStyle(
    fontSize: AppSizes.extraLarge,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle headingMedium = TextStyle(
    fontSize: AppSizes.large,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // =========================
  // Body Text Styles
  // =========================

  static TextStyle bodyLarge = TextStyle(
    fontSize: AppSizes.medium,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMedium = TextStyle(
    fontSize: AppSizes.small,
    color: AppColors.textSecondary,
  );

  // =========================
  // Button Text Style
  // =========================

  static TextStyle button = TextStyle(
    fontSize: AppSizes.medium,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  // =========================
  // Caption Style
  // =========================

  static TextStyle caption = TextStyle(
    fontSize: AppSizes.small,
    color: AppColors.grey,
  );
}
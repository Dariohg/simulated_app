import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.onBackground,
  );
  static const TextStyle headline6 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.onBackground,
  );
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    color: AppColors.onBackground,
  );
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    color: AppColors.onBackground,
  );
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.onPrimary,
    letterSpacing: 1.25,
  );
}
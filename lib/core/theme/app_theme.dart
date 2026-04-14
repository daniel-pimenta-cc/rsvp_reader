import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceVariant,
      ),
    );
  }
}

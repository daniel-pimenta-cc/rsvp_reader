import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Editorial typography: serif (Lora) for display/headline/title headings;
/// sans (Inter) for body and labels. Tabular figures on small labels so
/// numbers (progress %, WPM, remaining min) don't jitter.
abstract final class AppTypography {
  static TextTheme build(ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    final onSurfaceMuted = scheme.onSurfaceVariant;

    final serif = GoogleFonts.loraTextTheme(
      ThemeData(brightness: scheme.brightness).textTheme,
    );
    final sans = GoogleFonts.interTextTheme(
      ThemeData(brightness: scheme.brightness).textTheme,
    );

    return TextTheme(
      displayLarge: serif.displayLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.5,
      ),
      displayMedium: serif.displayMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        height: 1.12,
        letterSpacing: -0.4,
      ),
      displaySmall: serif.displaySmall?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
      headlineLarge: serif.headlineLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.2,
      ),
      headlineMedium: serif.headlineMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      headlineSmall: serif.headlineSmall?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleLarge: serif.titleLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: sans.titleMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: sans.titleSmall?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: sans.bodyLarge?.copyWith(
        color: onSurface,
        height: 1.5,
      ),
      bodyMedium: sans.bodyMedium?.copyWith(
        color: onSurface,
        height: 1.5,
      ),
      bodySmall: sans.bodySmall?.copyWith(
        color: onSurfaceMuted,
        height: 1.45,
      ),
      labelLarge: sans.labelLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: sans.labelMedium?.copyWith(
        color: onSurfaceMuted,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: sans.labelSmall?.copyWith(
        color: onSurfaceMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  /// Headline-like style with uppercase tracking used for section dividers
  /// in lists/settings — not a TextTheme slot because Material reserves those.
  static TextStyle sectionHeader(ColorScheme scheme) {
    return GoogleFonts.inter(
      color: scheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    );
  }
}

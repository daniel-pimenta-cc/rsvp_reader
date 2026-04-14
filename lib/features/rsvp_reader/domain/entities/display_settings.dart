import 'dart:ui';

import '../../../../core/constants/app_constants.dart';

class DisplaySettings {
  final int wpm;
  final double fontSize;
  final double contextFontSize;
  final int wordColorValue;
  final int orpColorValue;
  final int backgroundColorValue;
  final int highlightColorValue;
  final double verticalPosition;
  final double horizontalPosition;
  final String fontFamily;
  final bool showOrpHighlight;
  final bool smartTiming;
  final bool rampUp;
  final bool showFocusLine;
  final bool focusLineShowsProgress;

  const DisplaySettings({
    this.wpm = AppConstants.defaultWpm,
    this.fontSize = AppConstants.defaultFontSize,
    this.contextFontSize = AppConstants.defaultContextFontSize,
    this.wordColorValue = AppConstants.defaultWordColor,
    this.orpColorValue = AppConstants.defaultOrpColor,
    this.backgroundColorValue = AppConstants.defaultBackgroundColor,
    this.highlightColorValue = AppConstants.defaultHighlightColor,
    this.verticalPosition = AppConstants.defaultVerticalPosition,
    this.horizontalPosition = 0.5,
    this.fontFamily = AppConstants.defaultFontFamily,
    this.showOrpHighlight = true,
    this.smartTiming = true,
    this.rampUp = true,
    this.showFocusLine = true,
    this.focusLineShowsProgress = true,
  });

  Color get wordColor => Color(wordColorValue);
  Color get orpColor => Color(orpColorValue);
  Color get backgroundColor => Color(backgroundColorValue);
  Color get highlightColor => Color(highlightColorValue);

  DisplaySettings copyWith({
    int? wpm,
    double? fontSize,
    double? contextFontSize,
    int? wordColorValue,
    int? orpColorValue,
    int? backgroundColorValue,
    int? highlightColorValue,
    double? verticalPosition,
    double? horizontalPosition,
    String? fontFamily,
    bool? showOrpHighlight,
    bool? smartTiming,
    bool? rampUp,
    bool? showFocusLine,
    bool? focusLineShowsProgress,
  }) {
    return DisplaySettings(
      wpm: wpm ?? this.wpm,
      fontSize: fontSize ?? this.fontSize,
      contextFontSize: contextFontSize ?? this.contextFontSize,
      wordColorValue: wordColorValue ?? this.wordColorValue,
      orpColorValue: orpColorValue ?? this.orpColorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      highlightColorValue: highlightColorValue ?? this.highlightColorValue,
      verticalPosition: verticalPosition ?? this.verticalPosition,
      horizontalPosition: horizontalPosition ?? this.horizontalPosition,
      fontFamily: fontFamily ?? this.fontFamily,
      showOrpHighlight: showOrpHighlight ?? this.showOrpHighlight,
      smartTiming: smartTiming ?? this.smartTiming,
      rampUp: rampUp ?? this.rampUp,
      showFocusLine: showFocusLine ?? this.showFocusLine,
      focusLineShowsProgress:
          focusLineShowsProgress ?? this.focusLineShowsProgress,
    );
  }
}

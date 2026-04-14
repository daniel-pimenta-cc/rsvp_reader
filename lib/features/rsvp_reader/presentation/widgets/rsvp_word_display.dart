import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../domain/entities/display_settings.dart';

/// Renders a single word with the ORP letter highlighted.
///
/// The ORP letter is anchored at [horizontalPosition] of the available width.
/// If the word is too wide to fit, font size is scaled down automatically.
class RsvpWordDisplay extends StatelessWidget {
  final WordToken? word;
  final DisplaySettings settings;

  /// Reading progress (0..1). Used by the focus line when
  /// [DisplaySettings.focusLineShowsProgress] is enabled.
  final double progress;

  const RsvpWordDisplay({
    required this.word,
    required this.settings,
    this.progress = 0.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (word == null) return const SizedBox.shrink();

    final text = word!.text;
    final orpIdx = word!.orpIndex.clamp(0, text.length - 1);

    final beforeOrp = text.substring(0, orpIdx);
    final orpChar = text.substring(orpIdx, orpIdx + 1);
    final afterOrp = text.substring(orpIdx + 1);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          const margin = AppConstants.rsvpWordMargin;
          final usableWidth = maxWidth - margin * 2;
          final anchorX = margin + usableWidth * settings.horizontalPosition;

          // Find the right font size — start at configured, scale down if needed
          var fontSize = settings.fontSize;
          _Measurement m;
          while (true) {
            m = _measure(beforeOrp, orpChar, afterOrp, fontSize);
            if (m.totalWidth <= usableWidth ||
                fontSize <= AppConstants.rsvpMinFontSize) {
              break;
            }
            fontSize -= AppConstants.rsvpFontShrinkStep;
          }

          // Position word so ORP center aligns with anchorX
          final idealOffset = anchorX - m.beforeWidth - (m.orpWidth / 2);
          // Clamp so full word stays within margins
          const minOffset = margin;
          final maxOffset = maxWidth - m.totalWidth - margin;
          final offsetX = maxOffset >= minOffset
              ? idealOffset.clamp(minOffset, maxOffset)
              : max(margin, (maxWidth - m.totalWidth) / 2); // center fallback

          const notchHeight = AppConstants.rsvpNotchHeight;
          const notchGap = AppConstants.rsvpNotchGap;
          const focusLineGap = AppConstants.rsvpFocusLineGap;
          const focusLineHeight = AppConstants.rsvpFocusLineHeight;

          final showLine = settings.showFocusLine;
          final lineTotalSpace =
              showLine ? focusLineGap + focusLineHeight : 0.0;

          return SizedBox(
            width: maxWidth,
            height: m.textHeight + notchHeight + notchGap + lineTotalSpace,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Notch at anchor point
                Positioned(
                  left: anchorX - 4,
                  top: 0,
                  child: CustomPaint(
                    size: const Size(8, notchHeight),
                    painter: _NotchPainter(settings.orpColor.withAlpha(102)),
                  ),
                ),
                // The word
                Positioned(
                  left: offsetX,
                  top: notchHeight + notchGap,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: beforeOrp, style: m.baseStyle),
                        TextSpan(text: orpChar, style: m.orpStyle),
                        TextSpan(text: afterOrp, style: m.baseStyle),
                      ],
                    ),
                  ),
                ),
                // Focus / progress line below the word — full width
                if (showLine)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: notchHeight + notchGap + m.textHeight + focusLineGap,
                    height: focusLineHeight,
                    child: _FocusLine(
                      progress: progress,
                      showProgress: settings.focusLineShowsProgress,
                      filledColor: settings.orpColor,
                      restColor: settings.wordColor.withAlpha(60),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  _Measurement _measure(
    String before,
    String orp,
    String after,
    double fontSize,
  ) {
    final baseStyle = GoogleFonts.getFont(
      _mapFontFamily(settings.fontFamily),
      fontSize: fontSize,
      color: settings.wordColor,
      fontWeight: FontWeight.w400,
      letterSpacing: 2.0,
    );
    final orpStyle = baseStyle.copyWith(
      color: settings.showOrpHighlight ? settings.orpColor : settings.wordColor,
      fontWeight: settings.showOrpHighlight ? FontWeight.w700 : FontWeight.w400,
    );

    final bP = TextPainter(
      text: TextSpan(text: before, style: baseStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final oP = TextPainter(
      text: TextSpan(text: orp, style: orpStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final aP = TextPainter(
      text: TextSpan(text: after, style: baseStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    return _Measurement(
      beforeWidth: bP.width,
      orpWidth: oP.width,
      afterWidth: aP.width,
      totalWidth: bP.width + oP.width + aP.width,
      textHeight: bP.height,
      baseStyle: baseStyle,
      orpStyle: orpStyle,
    );
  }

  String _mapFontFamily(String family) {
    switch (family) {
      case 'RobotoMono':
        return 'Roboto Mono';
      case 'JetBrainsMono':
        return 'JetBrains Mono';
      case 'FiraCode':
        return 'Fira Code';
      case 'SourceCodePro':
        return 'Source Code Pro';
      default:
        return 'Roboto Mono';
    }
  }
}

class _Measurement {
  final double beforeWidth;
  final double orpWidth;
  final double afterWidth;
  final double totalWidth;
  final double textHeight;
  final TextStyle baseStyle;
  final TextStyle orpStyle;

  const _Measurement({
    required this.beforeWidth,
    required this.orpWidth,
    required this.afterWidth,
    required this.totalWidth,
    required this.textHeight,
    required this.baseStyle,
    required this.orpStyle,
  });
}

class _NotchPainter extends CustomPainter {
  final Color color;
  _NotchPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NotchPainter oldDelegate) => oldDelegate.color != color;
}

/// Thin horizontal line below the word.
///
/// When [showProgress] is true, fills from left up to [progress] in
/// [filledColor] and shows the remaining track in [restColor]. Otherwise
/// the entire line is rendered in [restColor] as a focus aid only.
class _FocusLine extends StatelessWidget {
  final double progress;
  final bool showProgress;
  final Color filledColor;
  final Color restColor;

  const _FocusLine({
    required this.progress,
    required this.showProgress,
    required this.filledColor,
    required this.restColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!showProgress) {
      return ColoredBox(color: restColor);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final p = progress.clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: restColor)),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: constraints.maxWidth * p,
              child: ColoredBox(color: filledColor),
            ),
          ],
        );
      },
    );
  }
}

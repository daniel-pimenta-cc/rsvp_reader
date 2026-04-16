import 'package:flutter/material.dart';

/// Minimal stadium-shaped progress bar used in book cards and list rows.
/// 2px thick, outline track, primary fill. Replaces LinearProgressIndicator
/// for a lighter, more editorial feel.
class ReadingProgressBar extends StatelessWidget {
  final double progress;
  final double height;

  const ReadingProgressBar({
    required this.progress,
    this.height = 2,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final fillWidth = constraints.maxWidth * clamped;
          return Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.outline.withAlpha(80),
                  borderRadius: BorderRadius.circular(height),
                ),
                child: const SizedBox.expand(),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: fillWidth,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

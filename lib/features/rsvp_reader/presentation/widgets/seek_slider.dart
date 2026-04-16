import 'package:flutter/material.dart';

import '../../domain/entities/rsvp_state.dart';

class SeekSlider extends StatelessWidget {
  final RsvpState state;
  final ValueChanged<int> onChanged;

  static const double _trackInset = 14.0;

  const SeekSlider({required this.state, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    final settings = state.displaySettings;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: settings.orpColor,
        thumbColor: settings.orpColor,
        inactiveTrackColor: settings.wordColor.withAlpha(40),
        showValueIndicator: ShowValueIndicator.onlyForContinuous,
        valueIndicatorColor: settings.orpColor,
        valueIndicatorTextStyle:
            const TextStyle(color: Colors.white, fontSize: 12),
      ),
      child: Slider(
        value: state.globalWordIndex.toDouble(),
        min: 0,
        max: (state.totalWords - 1).toDouble().clamp(1, double.infinity),
        label: state.currentChapterTitle ?? '',
        onChanged: (v) => onChanged(v.round()),
      ),
    );

    if (state.chapters.length <= 1 || state.totalWords <= 0) {
      return slider;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth - 2 * _trackInset;
        return Stack(
          alignment: Alignment.center,
          children: [
            slider,
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: _buildMarkers(trackWidth, settings.wordColor),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildMarkers(double trackWidth, Color color) {
    final markers = <Widget>[];
    int cumulative = 0;

    for (int i = 0; i < state.chapters.length - 1; i++) {
      cumulative += state.chapters[i].wordCount;
      final fraction = cumulative / state.totalWords;
      final x = _trackInset + fraction * trackWidth;

      markers.add(
        Positioned(
          left: x - 1,
          top: 0,
          bottom: 0,
          width: 2,
          child: Center(
            child: Container(
              width: 2,
              height: 8,
              decoration: BoxDecoration(
                color: color.withAlpha(90),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }
}

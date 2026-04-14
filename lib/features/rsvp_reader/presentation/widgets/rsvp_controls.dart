import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/rsvp_state.dart';
import '../providers/rsvp_engine_provider.dart';
import 'chapter_list_sheet.dart';

class RsvpControls extends ConsumerWidget {
  final String bookId;

  const RsvpControls({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rsvpEngineProvider(bookId));
    final engine = ref.read(rsvpEngineProvider(bookId).notifier);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: state.displaySettings.backgroundColor.withAlpha(230),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.currentChapterTitle ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: state.displaySettings.wordColor.withAlpha(153),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.minutesRemaining(state.estimatedMinutesRemaining),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: state.displaySettings.wordColor.withAlpha(153),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Seek slider with chapter markers
          _SeekSliderWithChapters(
            state: state,
            onChanged: engine.seekToWord,
          ),
          // Progress percentage
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.progressPercent((state.progress * 100).round()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: state.displaySettings.wordColor.withAlpha(153),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ChapterListSheet(bookId: bookId),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.chapters.isNotEmpty
                            ? l10n.chapterOf(
                                state.currentChapterIndex + 1,
                                state.chapters.length,
                              )
                            : '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: state.displaySettings.wordColor.withAlpha(153),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.list,
                        size: 14,
                        color: state.displaySettings.wordColor.withAlpha(120),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Skip backward
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  engine.skipBackward();
                },
                icon: Icon(
                  Icons.replay_10,
                  color: state.displaySettings.wordColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Play/Pause
              IconButton.filled(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  engine.togglePlayPause();
                },
                style: IconButton.styleFrom(
                  backgroundColor: state.displaySettings.orpColor,
                  fixedSize: const Size(56, 56),
                ),
                icon: Icon(
                  state.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              // Skip forward
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  engine.skipForward();
                },
                icon: Icon(
                  Icons.forward_10,
                  color: state.displaySettings.wordColor,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // WPM control
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  engine.decreaseWpm();
                },
                icon: Icon(
                  Icons.remove,
                  color: state.displaySettings.wordColor.withAlpha(179),
                  size: 20,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  l10n.wordsPerMinute(state.wpm),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: state.displaySettings.wordColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  engine.increaseWpm();
                },
                icon: Icon(
                  Icons.add,
                  color: state.displaySettings.wordColor.withAlpha(179),
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Slider with subtle vertical tick marks at each chapter boundary.
///
/// Markers are purely visual (IgnorePointer) so the slider's tap and drag
/// gestures work everywhere. Chapter title is surfaced via the slider's
/// value indicator, which appears above the thumb during interaction.
class _SeekSliderWithChapters extends StatelessWidget {
  final RsvpState state;
  final ValueChanged<int> onChanged;

  /// Horizontal inset of the slider track from the widget edges.
  /// Equals max(thumbRadius, overlayRadius) — see Material Slider source.
  static const double _trackInset = 14.0;

  const _SeekSliderWithChapters({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final settings = state.displaySettings;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: settings.orpColor,
        thumbColor: settings.orpColor,
        inactiveTrackColor: settings.wordColor.withAlpha(51),
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
            // Positioned.fill gives the inner stack the slider's bounds,
            // so its Positioned-only children can lay out correctly.
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children:
                      _buildMarkers(trackWidth, settings.wordColor),
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
          left: x - 1, // center the 2px line
          top: 0,
          bottom: 0,
          width: 2,
          child: Center(
            child: Container(
              width: 2,
              height: 7,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/rsvp_state.dart';
import '../providers/rsvp_engine_provider.dart';
import 'reader_floating_pill.dart';

/// Floating mode switcher, same family as the context view's lock pill.
///
/// Collapsed it shows the current mode's icon; tapping expands a labelled
/// stack of the available modes. It gets out of the way on its own — hidden
/// during playback and while the reader scrolls down — so the reading
/// surface stays clean without hiding the control behind a menu.
class ReaderModeFab extends ConsumerStatefulWidget {
  final String bookId;

  /// Whether the switcher should be on screen at all. The reader screen
  /// drives this from playback + scroll direction.
  final bool visible;

  const ReaderModeFab({
    required this.bookId,
    required this.visible,
    super.key,
  });

  @override
  ConsumerState<ReaderModeFab> createState() => _ReaderModeFabState();
}

class _ReaderModeFabState extends ConsumerState<ReaderModeFab> {
  bool _expanded = false;

  @override
  void didUpdateWidget(ReaderModeFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Collapse on the way out so it doesn't come back mid-expansion.
    if (!widget.visible && _expanded) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rsvpEngineProvider(widget.bookId));
    final settings = state.displaySettings;
    final l10n = AppLocalizations.of(context)!;
    final current = menuModeOf(state.mode);

    final modes = <(ReaderMode, IconData, String)>[
      (ReaderMode.rsvp, Icons.bolt, l10n.readerModeRsvp),
      (ReaderMode.ereader, Icons.menu_book_outlined, l10n.readerModeEreader),
      if (PlatformCapabilities.supportsTts)
        (ReaderMode.tts, Icons.volume_up_outlined, l10n.readerModeTts),
    ];

    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: AppDurations.base,
      curve: AppCurves.standard,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: AppDurations.base,
              curve: AppCurves.emphasized,
              alignment: Alignment.bottomLeft,
              child: _expanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (mode, icon, label) in modes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ModeOption(
                              icon: icon,
                              label: label,
                              selected: mode == current,
                              settings: settings,
                              onTap: () => _select(state.mode, mode),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            DecoratedBox(
              decoration: readerPillDecoration(
                backgroundColor: settings.backgroundColor,
                wordColor: settings.wordColor,
              ),
              child: IconButton(
                tooltip: l10n.readerModeTooltip,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _expanded = !_expanded);
                },
                icon: Icon(
                  _expanded ? Icons.close : _iconFor(current),
                  color: settings.wordColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(ReaderMode from, ReaderMode to) {
    HapticFeedback.selectionClick();
    setState(() => _expanded = false);
    switchReaderMode(
      ref.read(rsvpEngineProvider(widget.bookId).notifier),
      from,
      to,
    );
  }

  static IconData _iconFor(ReaderMode mode) {
    switch (mode) {
      case ReaderMode.rsvp:
      case ReaderMode.scroll:
        return Icons.bolt;
      case ReaderMode.ereader:
        return Icons.menu_book_outlined;
      case ReaderMode.tts:
        return Icons.volume_up_outlined;
    }
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final DisplaySettings settings;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? settings.orpColor : settings.wordColor.withAlpha(210);
    final radius = BorderRadius.circular(999);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: DecoratedBox(
          decoration: readerPillDecoration(
            backgroundColor: settings.backgroundColor,
            wordColor: selected ? settings.orpColor : settings.wordColor,
            borderRadius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapses [ReaderMode.scroll] into [ReaderMode.rsvp]: `scroll` is what
/// RSVP looks like while paused, not a mode the user picks.
ReaderMode menuModeOf(ReaderMode mode) =>
    mode == ReaderMode.scroll ? ReaderMode.rsvp : mode;

/// Performs a mode change. Each transition leaves the previous mode cleanly
/// (the engine handles its own flush / save bookkeeping), so callers don't
/// need to micro-manage it.
void switchReaderMode(
  RsvpEngineNotifier engine,
  ReaderMode from,
  ReaderMode to,
) {
  if (menuModeOf(from) == menuModeOf(to)) return;

  if (from == ReaderMode.ereader) {
    engine.exitEreaderMode();
  }
  if (from == ReaderMode.tts) {
    engine.exitTtsMode();
  }

  switch (to) {
    case ReaderMode.rsvp:
    case ReaderMode.scroll:
      // Picking "RSVP" lands on `scroll` (paused, ready to play); tapping
      // play then starts the ticker.
      break;
    case ReaderMode.ereader:
      engine.enterEreaderMode();
      break;
    case ReaderMode.tts:
      engine.enterTtsMode();
      break;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/rsvp_state.dart';
import '../providers/display_settings_provider.dart';
import '../providers/reader_side_panel_provider.dart';
import '../providers/rsvp_engine_provider.dart';
import '../widgets/context_scroll_view.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/reader_side_panel.dart';
import '../widgets/rsvp_controls.dart';
import '../widgets/rsvp_word_display.dart';

class RsvpReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  /// Optional override for the back button. When null, the reader uses
  /// `context.pop()` (standard route-based navigation). When provided, the
  /// reader calls this instead — used by the tablet-landscape master-detail
  /// host so the back button clears the selection in place instead of
  /// popping a non-existent route.
  final VoidCallback? onClose;

  const RsvpReaderScreen({
    required this.bookId,
    this.onClose,
    super.key,
  });

  @override
  ConsumerState<RsvpReaderScreen> createState() => _RsvpReaderScreenState();
}

class _RsvpReaderScreenState extends ConsumerState<RsvpReaderScreen>
    with TickerProviderStateMixin {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(rsvpEngineProvider(widget.bookId).notifier)
          .initialize(this);
      if (mounted) setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    // Reset side-panel state so switching between books doesn't keep a
    // panel open for an unrelated book.
    Future.microtask(() {
      if (mounted) return; // still mounted → another reader may need it
      ref.read(readerSidePanelProvider.notifier).state = ReaderSidePanelMode.none;
    });
    super.dispose();
  }

  bool _useSidePanel(BuildContext context) =>
      context.isTablet && context.isLandscape;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rsvpEngineProvider(widget.bookId));
    final engine = ref.read(rsvpEngineProvider(widget.bookId).notifier);

    if (state.isLoading || !_initialized) {
      // Engine hasn't populated its own copy of DisplaySettings yet, so its
      // palette is still the (dark) class default. Read the real settings
      // directly so the loading screen honours the user's theme instead of
      // flashing a dark card in light mode.
      final settings = ref.watch(displaySettingsProvider);
      return Scaffold(
        backgroundColor: settings.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: settings.orpColor),
        ),
      );
    }

    final readerBody = SafeArea(
      child: Column(
        children: [
          _buildTopBar(state, engine),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDurations.slow,
              switchInCurve: AppCurves.standard,
              switchOutCurve: AppCurves.standard,
              child: _buildModeArea(state, engine),
            ),
          ),
          if (state.mode != ReaderMode.ereader)
            RsvpControls(bookId: widget.bookId),
        ],
      ),
    );

    final useSidePanel = _useSidePanel(context);

    return Scaffold(
      backgroundColor: state.displaySettings.backgroundColor,
      body: useSidePanel
          ? Row(
              children: [
                Expanded(child: readerBody),
                ReaderSidePanel(
                  bookId: widget.bookId,
                  settings: state.displaySettings,
                ),
              ],
            )
          : readerBody,
    );
  }

  Widget _buildModeArea(RsvpState state, RsvpEngineNotifier engine) {
    switch (state.mode) {
      case ReaderMode.rsvp:
        return _buildRsvpArea(state, engine);
      case ReaderMode.scroll:
        return ContextScrollView(
          key: const ValueKey('scroll'),
          bookId: widget.bookId,
        );
      case ReaderMode.ereader:
        return ContextScrollView(
          key: const ValueKey('ereader'),
          bookId: widget.bookId,
          showHighlight: false,
        );
    }
  }

  Widget _buildRsvpArea(RsvpState state, RsvpEngineNotifier engine) {
    return GestureDetector(
      key: const ValueKey('rsvp'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        engine.togglePlayPause();
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) {
          engine.skipForward();
        } else if (details.primaryVelocity! > 200) {
          engine.skipBackward();
        }
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) {
          engine.increaseWpm();
        } else if (details.primaryVelocity! > 200) {
          engine.decreaseWpm();
        }
      },
      child: SizedBox.expand(
        child: Align(
          alignment:
              Alignment(0, (state.displaySettings.verticalPosition - 0.5) * 2),
          child: RsvpWordDisplay(
            word: state.currentWord,
            settings: state.displaySettings,
            progress: state.progress,
          ),
        ),
      ),
    );
  }

  void _openSettings(RsvpState state, RsvpEngineNotifier engine) {
    if (state.isPlaying) engine.pause();
    if (_useSidePanel(context)) {
      final current = ref.read(readerSidePanelProvider);
      ref.read(readerSidePanelProvider.notifier).state =
          current == ReaderSidePanelMode.settings
              ? ReaderSidePanelMode.none
              : ReaderSidePanelMode.settings;
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderSettingsSheet(bookId: widget.bookId),
    );
  }

  Widget _buildTopBar(RsvpState state, RsvpEngineNotifier engine) {
    final l10n = AppLocalizations.of(context)!;
    final isEreader = state.mode == ReaderMode.ereader;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (state.isPlaying) engine.pause();
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                context.pop();
              }
            },
            icon:
                Icon(Icons.arrow_back, color: state.displaySettings.wordColor),
          ),
          Expanded(
            child: Text(
              state.currentChapterTitle ?? '',
              style: theme.textTheme.titleSmall?.copyWith(
                color: state.displaySettings.wordColor.withAlpha(200),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: engine.toggleEreaderMode,
            tooltip:
                isEreader ? l10n.switchToRsvpMode : l10n.switchToEreaderMode,
            icon: Icon(
              isEreader ? Icons.bolt : Icons.menu_book_outlined,
              color: state.displaySettings.wordColor,
            ),
          ),
          IconButton(
            onPressed: () => _openSettings(state, engine),
            icon:
                Icon(Icons.tune, color: state.displaySettings.wordColor),
          ),
        ],
      ),
    );
  }
}

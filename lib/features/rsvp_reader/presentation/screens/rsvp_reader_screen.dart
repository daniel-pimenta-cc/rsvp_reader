import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/rsvp_state.dart';
import '../providers/rsvp_engine_provider.dart';
import '../widgets/context_scroll_view.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/rsvp_controls.dart';
import '../widgets/rsvp_word_display.dart';

class RsvpReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const RsvpReaderScreen({required this.bookId, super.key});

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
  Widget build(BuildContext context) {
    final state = ref.watch(rsvpEngineProvider(widget.bookId));
    final engine = ref.read(rsvpEngineProvider(widget.bookId).notifier);

    if (state.isLoading || !_initialized) {
      return Scaffold(
        backgroundColor: state.displaySettings.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: state.displaySettings.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(state, engine),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildModeArea(state, engine),
              ),
            ),
            if (state.mode != ReaderMode.ereader)
              RsvpControls(bookId: widget.bookId),
          ],
        ),
      ),
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

  /// RSVP mode — gesture detector only active here, doesn't interfere with scroll.
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

  Widget _buildTopBar(RsvpState state, RsvpEngineNotifier engine) {
    final l10n = AppLocalizations.of(context)!;
    final isEreader = state.mode == ReaderMode.ereader;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (state.isPlaying) engine.pause();
              context.pop();
            },
            icon:
                Icon(Icons.arrow_back, color: state.displaySettings.wordColor),
          ),
          Expanded(
            child: Text(
              state.currentChapterTitle ?? '',
              style: TextStyle(
                color: state.displaySettings.wordColor.withAlpha(179),
                fontSize: 14,
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
            onPressed: () {
              if (state.isPlaying) engine.pause();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ReaderSettingsSheet(bookId: widget.bookId),
              );
            },
            icon: Icon(Icons.tune, color: state.displaySettings.wordColor),
          ),
        ],
      ),
    );
  }
}

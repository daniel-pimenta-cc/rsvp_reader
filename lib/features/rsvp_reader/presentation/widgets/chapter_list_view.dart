import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../epub_import/domain/entities/chapter.dart';
import '../../domain/entities/display_settings.dart';
import '../providers/rsvp_engine_provider.dart';
import 'chapter_tile.dart';

/// Chapters below this word count are EPUB plumbing — split fragments,
/// empty anchors, stray `<section>`s — that show up in the TOC as rows like
/// "Text/index_split_003 · 1 word" and are useless to navigate to.
const int minNavigableWords = 5;

/// Fixed row height. Lets the list jump straight to the current chapter
/// without measuring, and keeps a 40-chapter book cheap to scroll.
const double chapterTileExtent = 64;

/// The `(originalIndex, chapter)` pairs worth listing. The original index is
/// carried along because [RsvpEngineNotifier.jumpToChapter] indexes the full
/// chapter list, not the filtered one.
///
/// Falls back to every chapter when the filter would empty the list — a book
/// of very short chapters should still be navigable.
List<(int, Chapter)> navigableChapters(List<Chapter> chapters) {
  final kept = <(int, Chapter)>[];
  for (var i = 0; i < chapters.length; i++) {
    if (chapters[i].wordCount >= minNavigableWords) kept.add((i, chapters[i]));
  }
  if (kept.isEmpty) {
    for (var i = 0; i < chapters.length; i++) {
      kept.add((i, chapters[i]));
    }
  }
  return kept;
}

/// Row to scroll to so [currentChapter] is visible: the current chapter, or
/// the nearest listed one before it when the current chapter was filtered
/// out. Returns 0 when there is nothing better to pick.
int chapterRowFor(List<(int, Chapter)> rows, int currentChapter) {
  final row = rows.lastIndexWhere((e) => e.$1 <= currentChapter);
  return row < 0 ? 0 : row;
}

/// Chapter list shared by the bottom sheet and the tablet side panel.
/// Opens scrolled to the chapter you're actually in — with 39 chapters,
/// landing on chapter 1 every time means scrolling before every jump.
class ChapterListView extends ConsumerStatefulWidget {
  final String bookId;
  final DisplaySettings settings;

  /// Scroll controller to drive the list with. The sheet passes the one
  /// from its [DraggableScrollableSheet] so drag-to-resize keeps working.
  final ScrollController? controller;

  /// Called after a chapter is picked — the sheet uses it to close itself.
  final VoidCallback? onJump;

  const ChapterListView({
    required this.bookId,
    required this.settings,
    this.controller,
    this.onJump,
    super.key,
  });

  @override
  ConsumerState<ChapterListView> createState() => _ChapterListViewState();
}

class _ChapterListViewState extends ConsumerState<ChapterListView> {
  ScrollController? _ownController;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _ownController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent());
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  void _revealCurrent() {
    if (!mounted) return;
    final controller = widget.controller ?? _ownController!;
    if (!controller.hasClients) return;
    final state = ref.read(rsvpEngineProvider(widget.bookId));
    final rows = navigableChapters(state.chapters);
    final row = chapterRowFor(rows, state.currentChapterIndex);
    // One row of lead-in so the current chapter doesn't sit flush against
    // the top edge and read like the start of the list.
    final target = (row - 1) * chapterTileExtent;
    controller.jumpTo(
      target.clamp(0.0, controller.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rsvpEngineProvider(widget.bookId));
    final engine = ref.read(rsvpEngineProvider(widget.bookId).notifier);
    final rows = navigableChapters(state.chapters);

    return ListView.builder(
      controller: widget.controller ?? _ownController,
      itemCount: rows.length,
      itemExtent: chapterTileExtent,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemBuilder: (context, row) {
        final (index, chapter) = rows[row];
        return ChapterTile(
          index: index,
          chapter: chapter,
          isCurrent: index == state.currentChapterIndex,
          settings: widget.settings,
          onTap: () {
            engine.jumpToChapter(index);
            widget.onJump?.call();
          },
        );
      },
    );
  }
}

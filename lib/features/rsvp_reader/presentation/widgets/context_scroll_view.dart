import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/responsive_defaults.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/font_mapper.dart';
import '../../../epub_import/domain/entities/chapter.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../domain/entities/display_settings.dart';
import '../providers/rsvp_engine_provider.dart';

/// A scroll item is either a chapter header or a paragraph of words.
class _ScrollItem {
  final String? chapterTitle; // non-null → header item
  final List<WordToken>? tokens; // non-null → paragraph item

  const _ScrollItem.header(this.chapterTitle) : tokens = null;
  const _ScrollItem.paragraph(this.tokens) : chapterTitle = null;

  bool get isHeader => chapterTitle != null;
}

/// Shows the full book text across all chapters.
///
/// When [showHighlight] is true (default), the current word is highlighted and
/// users can tap any word to seek. When false, renders plain text only — used
/// for the "ereader" reading mode.
class ContextScrollView extends ConsumerStatefulWidget {
  final String bookId;
  final bool showHighlight;

  const ContextScrollView({
    required this.bookId,
    this.showHighlight = true,
    super.key,
  });

  @override
  ConsumerState<ContextScrollView> createState() => _ContextScrollViewState();
}

class _ContextScrollViewState extends ConsumerState<ContextScrollView> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  late final ValueNotifier<int> _highlightIndex;

  List<_ScrollItem> _items = [];
  bool _didInitialScroll = false;
  bool _isUserScrolling = false;
  int _lastBuiltChapterCount = 0;

  // Smooth scroll tracking
  List<WordToken> _allTokens = [];
  Map<int, int> _tokenPositionMap = {}; // globalIndex → index in _allTokens
  List<int> _paragraphBoundaries = []; // indices in _allTokens (sorted)
  List<int> _sentenceBoundaries = []; // indices in _allTokens (sorted)
  double _smoothedVelocity = 0.0;
  DateTime _lastHighlightUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final state = ref.read(rsvpEngineProvider(widget.bookId));
    _highlightIndex = ValueNotifier(state.globalWordIndex);
    _buildItems(state.chapters);
    _positionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_onPositionsChanged);
    _highlightIndex.dispose();
    super.dispose();
  }

  /// Single-pass build of scroll items + flat token index.
  ///
  /// Walks every token exactly once and, as it goes, splits paragraphs via
  /// [WordToken.paragraphIndex], appends to `_allTokens`, records sentence
  /// boundaries, and emits `_ScrollItem.paragraph` whenever a paragraph
  /// closes. The previous implementation grouped paragraphs into a throwaway
  /// `List<List<WordToken>>` first and then walked the tokens a second time
  /// to fill the index — two passes and an extra allocation per paragraph.
  void _buildItems(List<Chapter> chapters) {
    final items = <_ScrollItem>[];
    final allTokens = <WordToken>[];
    final tokenPositionMap = HashMap<int, int>();
    final paragraphBoundaries = <int>[];
    final sentenceBoundaries = <int>[];

    for (final chapter in chapters) {
      items.add(_ScrollItem.header(chapter.title));
      final tokens = chapter.tokens;
      if (tokens.isEmpty) continue;

      List<WordToken>? currentParagraph;
      int currentParaIdx = -1;

      for (final token in tokens) {
        if (token.paragraphIndex != currentParaIdx) {
          if (currentParagraph != null) {
            items.add(_ScrollItem.paragraph(currentParagraph));
          }
          currentParagraph = <WordToken>[];
          currentParaIdx = token.paragraphIndex;
          final paraStart = allTokens.length;
          paragraphBoundaries.add(paraStart);
          sentenceBoundaries.add(paraStart);
        }
        final pos = allTokens.length;
        if (currentParagraph!.isNotEmpty &&
            _isSentenceEnd(currentParagraph.last.text)) {
          sentenceBoundaries.add(pos);
        }
        currentParagraph.add(token);
        tokenPositionMap[token.globalIndex] = pos;
        allTokens.add(token);
      }
      if (currentParagraph != null) {
        items.add(_ScrollItem.paragraph(currentParagraph));
      }
    }

    _items = items;
    _allTokens = allTokens;
    _tokenPositionMap = tokenPositionMap;
    _paragraphBoundaries = paragraphBoundaries;
    _sentenceBoundaries = sentenceBoundaries;
    _lastBuiltChapterCount = chapters.length;
  }

  void _onPositionsChanged() {
    if (!_isUserScrolling || _items.isEmpty || _allTokens.isEmpty) return;

    // Throttle updates for smooth movement
    final now = DateTime.now();
    if (now.difference(_lastHighlightUpdate).inMilliseconds < 80) return;
    _lastHighlightUpdate = now;

    final velocity = _smoothedVelocity.abs();
    if (velocity < 0.3) return;

    // Check if highlight is still in visible area; catch up if not
    final visiblePositions = _positionsListener.itemPositions.value;
    final highlightItemIdx = _findItemIndex(_highlightIndex.value);
    final highlightVisible =
        visiblePositions.any((p) => p.index == highlightItemIdx);

    if (!highlightVisible) {
      _catchUpToVisible(visiblePositions);
      return;
    }

    final direction = _smoothedVelocity > 0 ? 1 : -1;
    final currentPos = _tokenPositionMap[_highlightIndex.value] ?? 0;
    int newPos;

    if (velocity > 25) {
      // Fast scroll → jump by paragraph
      newPos =
          _findNextBoundary(currentPos, direction, _paragraphBoundaries);
    } else if (velocity > 8) {
      // Medium scroll → jump by sentence
      newPos =
          _findNextBoundary(currentPos, direction, _sentenceBoundaries);
    } else {
      // Slow scroll → word by word
      newPos = currentPos + direction;
    }

    newPos = newPos.clamp(0, _allTokens.length - 1);
    _highlightIndex.value = _allTokens[newPos].globalIndex;
  }

  void _syncToEngine() {
    ref
        .read(rsvpEngineProvider(widget.bookId).notifier)
        .seekToWord(_highlightIndex.value);
  }

  void _onWordTap(WordToken token) {
    _highlightIndex.value = token.globalIndex;
    ref
        .read(rsvpEngineProvider(widget.bookId).notifier)
        .seekToWord(token.globalIndex);
  }

  /// Find the item index in _items that contains globalWordIndex.
  int _findItemIndex(int globalWordIndex) {
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (!item.isHeader &&
          item.tokens != null &&
          item.tokens!.isNotEmpty &&
          globalWordIndex >= item.tokens!.first.globalIndex &&
          globalWordIndex <= item.tokens!.last.globalIndex) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rsvpEngineProvider(widget.bookId));

    // Rebuild item cache if chapters loaded or changed
    if (state.chapters.length != _lastBuiltChapterCount) {
      _buildItems(state.chapters);
      _didInitialScroll = false;
    }

    // Sync highlight from engine when not scrolling
    if (!_isUserScrolling) {
      final newHighlight = state.globalWordIndex;
      if (_highlightIndex.value != newHighlight) {
        _highlightIndex.value = newHighlight;
        if (_didInitialScroll && _scrollController.isAttached) {
          _scrollToHighlight(newHighlight, animate: true);
        }
      }
    }

    final settings = state.displaySettings;

    if (_items.isEmpty) return const SizedBox.shrink();

    if (!_didInitialScroll) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlight(state.globalWordIndex, animate: false);
      });
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final maxReadableWidth = ResponsiveDefaults.readableMaxWidth(context);
    final sidePadding = context.deviceType == DeviceType.compact ? 24.0 : 32.0;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          if (notification.direction != ScrollDirection.idle) {
            _isUserScrolling = true;
          } else {
            _isUserScrolling = false;
            _smoothedVelocity = 0.0;
            _snapToEndIfAtBottom();
            _syncToEngine();
          }
        } else if (notification is ScrollUpdateNotification &&
            _isUserScrolling) {
          final delta = notification.scrollDelta ?? 0.0;
          _smoothedVelocity = _smoothedVelocity * 0.7 + delta * 0.3;
        }
        return false;
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxReadableWidth),
          child: ScrollablePositionedList.builder(
        itemCount: _items.length,
        itemScrollController: _scrollController,
        itemPositionsListener: _positionsListener,
        initialScrollIndex: _findItemIndex(state.globalWordIndex),
        initialAlignment: AppConstants.contextFocusAlignment,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: screenHeight * (context.isTablet && context.isLandscape
              ? 0.22
              : 0.35),
          bottom: screenHeight *
              (context.isTablet && context.isLandscape ? 0.35 : 0.5),
          left: sidePadding,
          right: sidePadding,
        ),
        itemBuilder: (context, index) {
          final item = _items[index];

          if (item.isHeader) {
            return Padding(
              padding: const EdgeInsets.only(top: 32, bottom: 16),
              child: Text(
                item.chapterTitle!,
                style: GoogleFonts.getFont(
                  mapFontFamily(settings.fontFamily),
                  fontSize: settings.contextFontSize * 1.2,
                  color: settings.orpColor.withAlpha(200),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          if (!widget.showHighlight) {
            return _ParagraphWidget(
              tokens: item.tokens!,
              currentGlobalIndex: -1,
              settings: settings,
              onWordTap: null,
            );
          }

          return ValueListenableBuilder<int>(
            valueListenable: _highlightIndex,
            builder: (context, currentHighlight, _) {
              return _ParagraphWidget(
                tokens: item.tokens!,
                currentGlobalIndex: currentHighlight,
                settings: settings,
                onWordTap: _onWordTap,
              );
            },
          );
        },
          ),
        ),
      ),
    );
  }

  bool _isSentenceEnd(String word) {
    final trimmed = word.trimRight();
    return trimmed.endsWith('.') ||
        trimmed.endsWith('!') ||
        trimmed.endsWith('?');
  }

  /// Binary search for the next boundary in [direction] from [currentPos].
  int _findNextBoundary(
      int currentPos, int direction, List<int> boundaries) {
    if (boundaries.isEmpty) {
      return (currentPos + direction).clamp(0, _allTokens.length - 1);
    }

    // Find first boundary > currentPos
    int lo = 0, hi = boundaries.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (boundaries[mid] <= currentPos) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    if (direction > 0) {
      return lo < boundaries.length ? boundaries[lo] : _allTokens.length - 1;
    } else {
      final prevIdx = lo - 1;
      if (prevIdx >= 0 && boundaries[prevIdx] < currentPos) {
        return boundaries[prevIdx];
      } else if (prevIdx > 0) {
        return boundaries[prevIdx - 1];
      }
      return 0;
    }
  }

  double _wordFractionInItem(int globalWordIndex, int itemIdx) {
    if (itemIdx < 0 || itemIdx >= _items.length) return 0.0;
    final item = _items[itemIdx];
    if (item.isHeader || item.tokens == null || item.tokens!.isEmpty) {
      return 0.0;
    }
    final tokens = item.tokens!;
    final count = tokens.length;
    if (count <= 1) return 0.0;
    final local = globalWordIndex - tokens.first.globalIndex;
    return (local / (count - 1)).clamp(0.0, 1.0);
  }

  /// Two-pass scroll: first jump gets the paragraph laid out so
  /// [ItemPositionsListener] can report its viewport-fraction height, then a
  /// re-jump offsets by the word's depth inside the paragraph — otherwise
  /// long paragraphs would push the highlighted word off-screen.
  void _scrollToHighlight(int globalWordIndex, {required bool animate}) {
    if (!_scrollController.isAttached) return;
    final targetItem = _findItemIndex(globalWordIndex);
    final wordFraction = _wordFractionInItem(globalWordIndex, targetItem);
    final focus = AppConstants.contextFocusAlignment;

    void jumpOrScroll(double alignment) {
      if (animate) {
        _scrollController.scrollTo(
          index: targetItem,
          duration: const Duration(milliseconds: 250),
          alignment: alignment,
        );
      } else {
        _scrollController.jumpTo(
          index: targetItem,
          alignment: alignment,
        );
      }
    }

    jumpOrScroll(focus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.isAttached) return;
      final positions = _positionsListener.itemPositions.value;
      ItemPosition? pos;
      for (final p in positions) {
        if (p.index == targetItem) {
          pos = p;
          break;
        }
      }
      if (pos == null) return;
      final paragraphHeight = pos.itemTrailingEdge - pos.itemLeadingEdge;
      if (paragraphHeight <= 0) return;
      final adjusted = (focus - paragraphHeight * wordFraction)
          .clamp(-2.0, focus);
      if ((adjusted - focus).abs() < 0.005) return;
      jumpOrScroll(adjusted);
    });
  }

  void _snapToEndIfAtBottom() {
    if (_allTokens.isEmpty || _items.isEmpty) return;
    final lastGlobal = _allTokens.last.globalIndex;
    if (_highlightIndex.value == lastGlobal) return;
    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final lastItemIdx = _items.length - 1;
    final atBottom = positions.any(
      (p) => p.index == lastItemIdx && p.itemTrailingEdge <= 1.0,
    );
    if (atBottom) {
      _highlightIndex.value = lastGlobal;
    }
  }

  /// When the highlight falls off-screen, snap it to the visible area center.
  void _catchUpToVisible(Iterable<ItemPosition> visiblePositions) {
    const focusFraction = 0.4;
    final sorted = visiblePositions.toList()
      ..sort((a, b) {
        final aMid = (a.itemLeadingEdge + a.itemTrailingEdge) / 2;
        final bMid = (b.itemLeadingEdge + b.itemTrailingEdge) / 2;
        return (aMid - focusFraction)
            .abs()
            .compareTo((bMid - focusFraction).abs());
      });

    if (sorted.isNotEmpty && sorted.first.index < _items.length) {
      final item = _items[sorted.first.index];
      if (!item.isHeader && item.tokens != null && item.tokens!.isNotEmpty) {
        _highlightIndex.value = item.tokens!.first.globalIndex;
      }
    }
  }

}

class _ParagraphWidget extends StatelessWidget {
  final List<WordToken> tokens;
  final int currentGlobalIndex;
  final DisplaySettings settings;
  final ValueChanged<WordToken>? onWordTap;

  const _ParagraphWidget({
    required this.tokens,
    required this.currentGlobalIndex,
    required this.settings,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseFontSize = settings.contextFontSize;
    final baseStyle = GoogleFonts.getFont(
      mapFontFamily(settings.fontFamily),
      fontSize: baseFontSize,
      color: settings.wordColor.withAlpha(180),
      height: 1.8,
    );
    final highlightTextStyle = GoogleFonts.getFont(
      mapFontFamily(settings.fontFamily),
      fontSize: baseFontSize,
      color: settings.wordColor,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text.rich(
        TextSpan(
          children: tokens.map((token) {
            final isHighlighted = token.globalIndex == currentGlobalIndex;
            if (isHighlighted) {
              return WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: onWordTap == null ? null : () => onWordTap!(token),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: settings.highlightColor.withAlpha(
                          (settings.highlightColor.a * 255.0 * 0.7).round().clamp(0, 255)),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: settings.highlightColor.withAlpha(40),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(token.text, style: highlightTextStyle),
                  ),
                ),
              );
            }
            return TextSpan(
              text: '${token.text} ',
              style: baseStyle,
              recognizer: onWordTap == null
                  ? null
                  : (TapGestureRecognizer()..onTap = () => onWordTap!(token)),
            );
          }).toList(),
        ),
      ),
    );
  }

}

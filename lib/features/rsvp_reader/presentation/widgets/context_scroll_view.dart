import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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

  /// Build a flat list of items: chapter headers + paragraphs for ALL chapters.
  void _buildItems(List<Chapter> chapters) {
    final items = <_ScrollItem>[];
    for (final chapter in chapters) {
      items.add(_ScrollItem.header(chapter.title));
      final paragraphs = _groupByParagraph(chapter.tokens);
      for (final p in paragraphs) {
        items.add(_ScrollItem.paragraph(p));
      }
    }
    _items = items;
    _lastBuiltChapterCount = chapters.length;

    // Build flat token list and navigation boundaries
    _allTokens = [];
    _tokenPositionMap = {};
    _paragraphBoundaries = [];
    _sentenceBoundaries = [];

    for (final item in _items) {
      if (!item.isHeader && item.tokens != null && item.tokens!.isNotEmpty) {
        final paragraphStart = _allTokens.length;
        _paragraphBoundaries.add(paragraphStart);
        _sentenceBoundaries.add(paragraphStart);
        for (int i = 0; i < item.tokens!.length; i++) {
          final token = item.tokens![i];
          final pos = _allTokens.length;
          _tokenPositionMap[token.globalIndex] = pos;
          _allTokens.add(token);
          if (i > 0 && _isSentenceEnd(item.tokens![i - 1].text)) {
            _sentenceBoundaries.add(pos);
          }
        }
      }
    }
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
        // If the slider moved us to a different area, scroll there
        if (_didInitialScroll && _scrollController.isAttached) {
          final targetItem = _findItemIndex(newHighlight);
          _scrollController.scrollTo(
            index: targetItem,
            duration: const Duration(milliseconds: 300),
            alignment: 0.35,
          );
        }
      }
    }

    final settings = state.displaySettings;

    if (_items.isEmpty) return const SizedBox.shrink();

    // Jump to current position instantly on first show
    if (!_didInitialScroll) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetItem = _findItemIndex(state.globalWordIndex);
        if (_scrollController.isAttached) {
          _scrollController.jumpTo(
            index: targetItem,
            alignment: 0.35,
          );
        }
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

  List<List<WordToken>> _groupByParagraph(List<WordToken> tokens) {
    if (tokens.isEmpty) return [];

    final paragraphs = <List<WordToken>>[];
    var current = <WordToken>[];
    int lastIdx = tokens.first.paragraphIndex;

    for (final token in tokens) {
      if (token.paragraphIndex != lastIdx) {
        paragraphs.add(current);
        current = [];
        lastIdx = token.paragraphIndex;
      }
      current.add(token);
    }
    if (current.isNotEmpty) paragraphs.add(current);

    return paragraphs;
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

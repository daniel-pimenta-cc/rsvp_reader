import '../../features/epub_import/domain/entities/word_token.dart';
import 'orp_calculator.dart';
import 'word_timing.dart';

/// Converts clean text into a list of [WordToken]s with pre-calculated
/// ORP positions and timing multipliers.
class TextTokenizer {
  const TextTokenizer._();

  /// Tokenize [cleanText] into words.
  ///
  /// [chapterIndex]: which chapter this text belongs to.
  /// [globalOffset]: the starting global word index for this chapter.
  static List<WordToken> tokenize(
    String cleanText, {
    required int chapterIndex,
    required int globalOffset,
  }) {
    final tokens = <WordToken>[];
    final paragraphs = cleanText.split(RegExp(r'\n\s*\n'));
    int globalIndex = globalOffset;
    int paragraphIndex = 0;

    for (final paragraph in paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;

      final words = trimmed.split(RegExp(r'\s+'));

      for (int w = 0; w < words.length; w++) {
        final word = words[w].trim();
        if (word.isEmpty) continue;

        final bool isParagraphStart = (w == 0);
        final bool isChapterStart = (paragraphIndex == 0 && w == 0);

        tokens.add(WordToken(
          text: word,
          orpIndex: OrpCalculator.calculate(word),
          timingMultiplier: WordTiming.calculateMultiplier(
            word,
            isParagraphStart: isParagraphStart,
            isChapterStart: isChapterStart,
          ),
          globalIndex: globalIndex,
          chapterIndex: chapterIndex,
          paragraphIndex: paragraphIndex,
          isParagraphStart: isParagraphStart,
          isChapterStart: isChapterStart,
        ));
        globalIndex++;
      }

      paragraphIndex++;
    }

    return tokens;
  }
}

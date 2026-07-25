/// Conversions between a book-global word cursor and the
/// `(chapterIndex, wordIndex)` pair stored in `reading_progress`.
///
/// Sync ships the global cursor because the local pair only means something
/// inside one tokenization. The same EPUB parsed by a newer build can split
/// into a different number of chapters (image tokens, extra front-matter
/// sections), and then chapter 8 on one device is nowhere near chapter 8 on
/// the other — progress "syncs" but lands in the wrong place.
library;

/// Sums the chapters before [chapterIndex] and adds [wordIndex].
int localToGlobalWordIndex(
  List<int> chapterWordCounts,
  int chapterIndex,
  int wordIndex,
) {
  var global = 0;
  final upTo = chapterIndex < chapterWordCounts.length
      ? chapterIndex
      : chapterWordCounts.length;
  for (var i = 0; i < upTo; i++) {
    global += chapterWordCounts[i];
  }
  return global + wordIndex;
}

/// Walks [chapterWordCounts] to find which chapter [globalIndex] falls in.
///
/// A cursor past the end (the remote tokenization was longer than ours)
/// pins to the last word rather than overflowing — the caller would
/// otherwise index a chapter that doesn't exist locally.
(int chapterIndex, int wordIndex) globalToLocalWordIndex(
  List<int> chapterWordCounts,
  int globalIndex,
) {
  if (chapterWordCounts.isEmpty) return (0, 0);
  var remaining = globalIndex < 0 ? 0 : globalIndex;
  for (var i = 0; i < chapterWordCounts.length; i++) {
    if (remaining < chapterWordCounts[i]) return (i, remaining);
    remaining -= chapterWordCounts[i];
  }
  final last = chapterWordCounts.length - 1;
  final lastCount = chapterWordCounts[last];
  return (last, lastCount > 0 ? lastCount - 1 : 0);
}

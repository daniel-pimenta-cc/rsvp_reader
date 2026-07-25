import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/progress_index.dart';

void main() {
  group('localToGlobalWordIndex', () {
    test('sums the chapters before the cursor', () {
      expect(localToGlobalWordIndex([10, 20, 30], 2, 5), 35);
    });

    test('chapter 0 is just the word index', () {
      expect(localToGlobalWordIndex([10, 20], 0, 7), 7);
    });

    test('a chapter index past the end sums everything it has', () {
      expect(localToGlobalWordIndex([10, 20], 9, 3), 33);
    });
  });

  group('globalToLocalWordIndex', () {
    test('finds the chapter the cursor falls in', () {
      expect(globalToLocalWordIndex([10, 20, 30], 35), (2, 5));
    });

    test('the first word of a chapter is offset 0', () {
      expect(globalToLocalWordIndex([10, 20], 10), (1, 0));
    });

    test('pins to the last word when the cursor overshoots', () {
      expect(globalToLocalWordIndex([10, 20], 999), (1, 19));
    });

    test('empty book yields the origin', () {
      expect(globalToLocalWordIndex([], 42), (0, 0));
    });
  });

  test('round-trips across a re-split of the same book', () {
    // The real defect this exists for: the same EPUB parsed by two builds.
    // The newer one emits three extra chapters up front (image/front-matter
    // tokens), so `chapter 8` means different things on the two devices —
    // but the global cursor lands on the same word.
    const oldSplit = [59, 20, 55, 675, 252, 888, 2, 11131, 25052];
    const newSplit = [1, 1, 59, 20, 55, 675, 252, 888, 2, 5, 11131, 25052];

    final global = localToGlobalWordIndex(oldSplit, 8, 4940);
    expect(global, 18022);

    final (chapter, word) = globalToLocalWordIndex(newSplit, global);
    // Same word, expressed against the newer split: the 25052-word chapter
    // sits at index 11 there, not 8.
    expect(localToGlobalWordIndex(newSplit, chapter, word), global);
    expect(chapter, 11);
  });
}

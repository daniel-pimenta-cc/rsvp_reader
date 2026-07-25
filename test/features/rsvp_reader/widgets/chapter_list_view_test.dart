import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/epub_import/domain/entities/chapter.dart';
import 'package:ledor/features/epub_import/domain/entities/word_token.dart';
import 'package:ledor/features/rsvp_reader/presentation/widgets/chapter_list_view.dart';

Chapter chapter(String title, int words) => Chapter(
      title: title,
      tokens: List.generate(
        words,
        (i) => WordToken(
          text: 'w$i',
          orpIndex: 0,
          timingMultiplier: 1,
          globalIndex: i,
          chapterIndex: 0,
          paragraphIndex: 0,
        ),
      ),
    );

void main() {
  group('navigableChapters', () {
    test('drops EPUB split fragments but keeps their original indices', () {
      final chapters = [
        chapter('Copyright', 150),
        chapter('Text/index_split_000', 1),
        chapter('Text/index_split_001', 1),
        chapter('Cover', 22),
        chapter('Preface', 4645),
      ];

      final rows = navigableChapters(chapters);

      expect(rows.map((e) => e.$2.title), [
        'Copyright',
        'Cover',
        'Preface',
      ]);
      expect(rows.map((e) => e.$1), [0, 3, 4],
          reason: 'jumpToChapter indexes the full list, not the filtered one');
    });

    test('keeps everything when every chapter is short', () {
      final chapters = [chapter('a', 1), chapter('b', 2)];
      expect(navigableChapters(chapters).length, 2,
          reason: 'a book of tiny chapters must still be navigable');
    });

    test('empty book yields no rows', () {
      expect(navigableChapters(const []), isEmpty);
    });
  });

  group('chapterRowFor', () {
    final rows = navigableChapters([
      chapter('Copyright', 150), // 0
      chapter('Text/index_split_000', 1), // 1 — filtered out
      chapter('Cover', 22), // 2
      chapter('Preface', 4645), // 3
    ]);

    test('maps the current chapter to its filtered row', () {
      expect(chapterRowFor(rows, 3), 2);
      expect(chapterRowFor(rows, 0), 0);
    });

    test('falls back to the nearest listed chapter before a filtered one', () {
      expect(chapterRowFor(rows, 1), 0);
    });

    test('returns the first row when nothing precedes the current chapter', () {
      expect(chapterRowFor(const [], 5), 0);
    });
  });
}

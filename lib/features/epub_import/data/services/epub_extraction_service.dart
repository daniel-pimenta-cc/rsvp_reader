import 'dart:typed_data';

import 'package:epub_pro/epub_pro.dart';
import 'package:image/image.dart' as img;

import '../../../../core/utils/html_stripper.dart';
import '../../../../core/utils/text_tokenizer.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/parsed_book.dart';

/// Parses an EPUB file and extracts all text content as tokenized chapters.
class EpubExtractionService {
  /// Parse EPUB bytes and return a [ParsedBook] with all chapters tokenized.
  Future<ParsedBook> extractBook(Uint8List epubBytes) async {
    final epubBook = await EpubReader.readBook(epubBytes);

    final title = epubBook.title ?? 'Unknown Title';
    final author = epubBook.author ?? 'Unknown Author';

    // Convert cover image to PNG bytes if available
    Uint8List? coverBytes;
    if (epubBook.coverImage != null) {
      coverBytes = Uint8List.fromList(img.encodePng(epubBook.coverImage!));
    }

    final chapters = <Chapter>[];
    int globalOffset = 0;

    for (final epubChapter in epubBook.chapters) {
      final chapter =
          _processChapter(epubChapter, chapters.length, globalOffset);
      if (chapter.tokens.isNotEmpty) {
        globalOffset += chapter.tokens.length;
        chapters.add(chapter);
      }

      for (final sub in epubChapter.subChapters) {
        final subChapter =
            _processChapter(sub, chapters.length, globalOffset);
        if (subChapter.tokens.isNotEmpty) {
          globalOffset += subChapter.tokens.length;
          chapters.add(subChapter);
        }
      }
    }

    return ParsedBook(
      title: title,
      author: author,
      coverImage: coverBytes,
      chapters: chapters,
      totalWords: globalOffset,
    );
  }

  Chapter _processChapter(
    EpubChapter epubChapter,
    int chapterIndex,
    int globalOffset,
  ) {
    final htmlContent = epubChapter.htmlContent ?? '';
    final cleanText = HtmlStripper.strip(htmlContent);
    final tokens = TextTokenizer.tokenize(
      cleanText,
      chapterIndex: chapterIndex,
      globalOffset: globalOffset,
    );
    return Chapter(
      title: epubChapter.title ?? 'Chapter ${chapterIndex + 1}',
      tokens: tokens,
    );
  }
}

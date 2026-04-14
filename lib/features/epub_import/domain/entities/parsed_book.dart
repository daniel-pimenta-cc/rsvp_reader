import 'dart:typed_data';

import 'chapter.dart';

class ParsedBook {
  final String title;
  final String author;
  final Uint8List? coverImage;
  final List<Chapter> chapters;
  final int totalWords;

  const ParsedBook({
    required this.title,
    required this.author,
    required this.coverImage,
    required this.chapters,
    required this.totalWords,
  });
}

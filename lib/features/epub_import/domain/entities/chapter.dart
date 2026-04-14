import 'word_token.dart';

class Chapter {
  final String title;
  final List<WordToken> tokens;

  const Chapter({required this.title, required this.tokens});

  int get wordCount => tokens.length;
}

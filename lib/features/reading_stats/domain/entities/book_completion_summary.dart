import 'dart:typed_data';

/// Stats displayed on the book completion screen and its share card.
///
/// All fields are derived from the [reading_session] rows for a single book
/// plus the [books] row; see `bookCompletionProvider` for the query.
class BookCompletionSummary {
  final String bookId;
  final String title;
  final String? author;
  final Uint8List? coverImage;
  final int totalWords;
  final int totalDurationMs;
  final int sessionCount;
  final int avgWpm;
  final DateTime? firstSessionAt;
  final DateTime? lastSessionAt;

  /// `null` when the user has not rated the book yet. Valid range 1..5.
  final int? rating;

  const BookCompletionSummary({
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverImage,
    required this.totalWords,
    required this.totalDurationMs,
    required this.sessionCount,
    required this.avgWpm,
    required this.firstSessionAt,
    required this.lastSessionAt,
    required this.rating,
  });

  int get daysSpan {
    final first = firstSessionAt;
    final last = lastSessionAt;
    if (first == null || last == null) return 0;
    return last.difference(first).inDays + 1;
  }
}

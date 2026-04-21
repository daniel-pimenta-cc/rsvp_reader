import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../database/app_database.dart';
import '../../domain/entities/book_completion_summary.dart';

/// Watches (book, sessions) for the given [bookId] and emits a
/// [BookCompletionSummary] whenever either changes — lets the screen
/// update live when the user taps a new rating.
final bookCompletionProvider = StreamProvider.autoDispose
    .family<BookCompletionSummary, String>((ref, bookId) async* {
  final booksDao = ref.watch(booksDaoProvider);
  final sessionDao = ref.watch(readingSessionDaoProvider);

  await for (final book in booksDao.watchBookById(bookId)) {
    if (book == null) {
      continue;
    }
    final sessions = await sessionDao.getAllSessionsForBook(bookId);
    yield buildCompletionSummary(book: book, sessions: sessions);
  }
});

/// Pure aggregation — exposed for tests.
BookCompletionSummary buildCompletionSummary({
  required BooksTableData book,
  required List<ReadingSessionTableData> sessions,
}) {
  int totalWords = 0;
  int totalDurationMs = 0;
  DateTime? first;
  DateTime? last;

  for (final s in sessions) {
    totalWords += s.wordsRead;
    totalDurationMs += s.durationMs;
    if (first == null || s.startedAt.isBefore(first)) first = s.startedAt;
    if (last == null || s.endedAt.isAfter(last)) last = s.endedAt;
  }

  final avgWpm = totalDurationMs > 0
      ? (totalWords * 60000 / totalDurationMs).round()
      : 0;

  return BookCompletionSummary(
    bookId: book.id,
    title: book.title,
    author: book.author,
    coverImage: book.coverImage,
    totalWords: totalWords,
    totalDurationMs: totalDurationMs,
    sessionCount: sessions.length,
    avgWpm: avgWpm,
    firstSessionAt: first,
    lastSessionAt: last,
    rating: book.rating,
  );
}

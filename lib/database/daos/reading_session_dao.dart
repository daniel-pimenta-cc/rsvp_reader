import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reading_session_table.dart';

part 'reading_session_dao.g.dart';

/// Aggregated per-book totals over a time range.
class BookSessionAggregate {
  final String bookId;
  final int totalDurationMs;
  final int totalWords;
  final int sessionCount;
  final int maxEndWordIndex;

  const BookSessionAggregate({
    required this.bookId,
    required this.totalDurationMs,
    required this.totalWords,
    required this.sessionCount,
    required this.maxEndWordIndex,
  });
}

@DriftAccessor(tables: [ReadingSessionTable])
class ReadingSessionDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingSessionDaoMixin {
  ReadingSessionDao(super.db);

  Future<void> insertSession(ReadingSessionTableCompanion session) {
    return into(readingSessionTable).insert(session);
  }

  Stream<List<ReadingSessionTableData>> watchSessionsInRange(
    DateTime from,
    DateTime to,
  ) {
    return (select(readingSessionTable)
          ..where((t) => t.startedAt.isBiggerOrEqualValue(from))
          ..where((t) => t.startedAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .watch();
  }

  Future<List<ReadingSessionTableData>> getSessionsInRange(
    DateTime from,
    DateTime to,
  ) {
    return (select(readingSessionTable)
          ..where((t) => t.startedAt.isBiggerOrEqualValue(from))
          ..where((t) => t.startedAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  /// Aggregates sessions in range grouped by bookId. Used for monthly recap
  /// ranking and the stats screen's book breakdown.
  Future<List<BookSessionAggregate>> aggregateByBookInRange(
    DateTime from,
    DateTime to,
  ) async {
    final durationSum = readingSessionTable.durationMs.sum();
    final wordsSum = readingSessionTable.wordsRead.sum();
    final sessionCount = readingSessionTable.id.count();
    final maxEnd = readingSessionTable.endWordIndex.max();

    final query = selectOnly(readingSessionTable)
      ..addColumns([
        readingSessionTable.bookId,
        durationSum,
        wordsSum,
        sessionCount,
        maxEnd,
      ])
      ..where(readingSessionTable.startedAt.isBiggerOrEqualValue(from) &
          readingSessionTable.startedAt.isSmallerThanValue(to))
      ..groupBy([readingSessionTable.bookId]);

    final rows = await query.get();
    return rows
        .map(
          (row) => BookSessionAggregate(
            bookId: row.read(readingSessionTable.bookId)!,
            totalDurationMs: row.read(durationSum) ?? 0,
            totalWords: row.read(wordsSum) ?? 0,
            sessionCount: row.read(sessionCount) ?? 0,
            maxEndWordIndex: row.read(maxEnd) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<int> deleteSessionsForBook(String bookId) {
    return (delete(readingSessionTable)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }
}

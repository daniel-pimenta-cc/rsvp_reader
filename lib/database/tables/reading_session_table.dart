import 'package:drift/drift.dart';

/// One row per continuous RSVP play stretch (play -> pause/end/mode-switch).
/// Seeks within a stretch do NOT split the session; skipped words don't count.
///
/// bookId is NOT declared as a foreign key so sessions survive book deletion
/// — the reading history (and monthly recaps) remain valid even if a book
/// is removed from the library.
@TableIndex(name: 'reading_session_started_at_idx', columns: {#startedAt})
@TableIndex(name: 'reading_session_book_id_idx', columns: {#bookId})
class ReadingSessionTable extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationMs => integer()();
  IntColumn get wordsRead => integer()();
  IntColumn get startWordIndex => integer()();
  IntColumn get endWordIndex => integer()();
  IntColumn get avgWpm => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

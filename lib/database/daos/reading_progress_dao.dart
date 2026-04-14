import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reading_progress_table.dart';

part 'reading_progress_dao.g.dart';

@DriftAccessor(tables: [ReadingProgressTable])
class ReadingProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingProgressDaoMixin {
  ReadingProgressDao(super.db);

  Future<ReadingProgressTableData?> getProgressForBook(String bookId) {
    return (select(readingProgressTable)
          ..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  Future<void> upsertProgress(ReadingProgressTableCompanion progress) {
    return into(readingProgressTable).insertOnConflictUpdate(progress);
  }

  Future<int> deleteProgressForBook(String bookId) {
    return (delete(readingProgressTable)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }
}

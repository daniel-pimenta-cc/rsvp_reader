import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cached_tokens_table.dart';

part 'cached_tokens_dao.g.dart';

@DriftAccessor(tables: [CachedTokensTable])
class CachedTokensDao extends DatabaseAccessor<AppDatabase>
    with _$CachedTokensDaoMixin {
  CachedTokensDao(super.db);

  Future<List<CachedTokensTableData>> getTokensForBook(String bookId) {
    return (select(cachedTokensTable)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.chapterIndex)]))
        .get();
  }

  Future<CachedTokensTableData?> getTokensForChapter(
    String bookId,
    int chapterIndex,
  ) {
    return (select(cachedTokensTable)
          ..where(
            (t) =>
                t.bookId.equals(bookId) &
                t.chapterIndex.equals(chapterIndex),
          ))
        .getSingleOrNull();
  }

  Future<void> insertChapterTokens(CachedTokensTableCompanion tokens) {
    return into(cachedTokensTable).insert(tokens);
  }

  Future<int> deleteTokensForBook(String bookId) {
    return (delete(cachedTokensTable)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }

  /// Sum of word counts of all chapters with index < [chapterIndex] for [bookId].
  /// Used to convert a chapter-local position into a global word index.
  Future<int> getWordCountBeforeChapter(String bookId, int chapterIndex) async {
    final sumExpr = cachedTokensTable.wordCount.sum();
    final query = selectOnly(cachedTokensTable)
      ..addColumns([sumExpr])
      ..where(
        cachedTokensTable.bookId.equals(bookId) &
            cachedTokensTable.chapterIndex.isSmallerThanValue(chapterIndex),
      );
    final row = await query.getSingleOrNull();
    return row?.read(sumExpr) ?? 0;
  }
}

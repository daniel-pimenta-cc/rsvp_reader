import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/books_table.dart';

part 'books_dao.g.dart';

@DriftAccessor(tables: [BooksTable])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.db);

  Future<List<BooksTableData>> getAllBooks() {
    return (select(booksTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastReadAt)]))
        .get();
  }

  Stream<List<BooksTableData>> watchAllBooks() {
    return (select(booksTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastReadAt)]))
        .watch();
  }

  Future<BooksTableData?> getBookById(String id) {
    return (select(booksTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<BooksTableData?> watchBookById(String id) {
    return (select(booksTable)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<void> insertBook(BooksTableCompanion book) {
    return into(booksTable).insert(book);
  }

  Future<void> updateLastReadAt(String bookId) {
    return (update(booksTable)..where((t) => t.id.equals(bookId))).write(
      BooksTableCompanion(lastReadAt: Value(DateTime.now())),
    );
  }

  /// Pass `null` to clear a previously set rating. Any out-of-range value
  /// is clamped at the call site (we don't enforce here so the rating
  /// picker can stay the source of truth on validation).
  Future<void> updateRating(String bookId, int? rating) {
    return (update(booksTable)..where((t) => t.id.equals(bookId))).write(
      BooksTableCompanion(rating: Value(rating)),
    );
  }

  Future<int> deleteBook(String id) {
    return (delete(booksTable)..where((t) => t.id.equals(id))).go();
  }
}

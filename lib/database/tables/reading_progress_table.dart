import 'package:drift/drift.dart';

import 'books_table.dart';

class ReadingProgressTable extends Table {
  TextColumn get bookId => text().references(BooksTable, #id)();
  IntColumn get chapterIndex => integer()();
  IntColumn get wordIndex => integer()();
  IntColumn get wpm => integer().withDefault(const Constant(300))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {bookId};
}

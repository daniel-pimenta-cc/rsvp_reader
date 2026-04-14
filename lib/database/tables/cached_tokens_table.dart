import 'package:drift/drift.dart';

import 'books_table.dart';

class CachedTokensTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().references(BooksTable, #id)();
  IntColumn get chapterIndex => integer()();
  TextColumn get chapterTitle => text().withDefault(const Constant(''))();
  TextColumn get tokensJson => text()();
  IntColumn get wordCount => integer()();
  IntColumn get paragraphCount => integer().withDefault(const Constant(0))();
}

import 'package:drift/drift.dart';

class BooksTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get filePath => text()();
  BlobColumn get coverImage => blob().nullable()();
  IntColumn get totalWords => integer().withDefault(const Constant(0))();
  IntColumn get chapterCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get importedAt => dateTime()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

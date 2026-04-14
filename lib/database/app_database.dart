import 'package:drift/drift.dart';

import 'daos/books_dao.dart';
import 'daos/cached_tokens_dao.dart';
import 'daos/reading_progress_dao.dart';
import 'tables/books_table.dart';
import 'tables/cached_tokens_table.dart';
import 'tables/reading_progress_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [BooksTable, ReadingProgressTable, CachedTokensTable],
  daos: [BooksDao, ReadingProgressDao, CachedTokensDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

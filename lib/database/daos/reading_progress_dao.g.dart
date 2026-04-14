// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_progress_dao.dart';

// ignore_for_file: type=lint
mixin _$ReadingProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $BooksTableTable get booksTable => attachedDatabase.booksTable;
  $ReadingProgressTableTable get readingProgressTable =>
      attachedDatabase.readingProgressTable;
  ReadingProgressDaoManager get managers => ReadingProgressDaoManager(this);
}

class ReadingProgressDaoManager {
  final _$ReadingProgressDaoMixin _db;
  ReadingProgressDaoManager(this._db);
  $$BooksTableTableTableManager get booksTable =>
      $$BooksTableTableTableManager(_db.attachedDatabase, _db.booksTable);
  $$ReadingProgressTableTableTableManager get readingProgressTable =>
      $$ReadingProgressTableTableTableManager(
        _db.attachedDatabase,
        _db.readingProgressTable,
      );
}

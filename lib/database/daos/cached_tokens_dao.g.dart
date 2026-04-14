// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_tokens_dao.dart';

// ignore_for_file: type=lint
mixin _$CachedTokensDaoMixin on DatabaseAccessor<AppDatabase> {
  $BooksTableTable get booksTable => attachedDatabase.booksTable;
  $CachedTokensTableTable get cachedTokensTable =>
      attachedDatabase.cachedTokensTable;
  CachedTokensDaoManager get managers => CachedTokensDaoManager(this);
}

class CachedTokensDaoManager {
  final _$CachedTokensDaoMixin _db;
  CachedTokensDaoManager(this._db);
  $$BooksTableTableTableManager get booksTable =>
      $$BooksTableTableTableManager(_db.attachedDatabase, _db.booksTable);
  $$CachedTokensTableTableTableManager get cachedTokensTable =>
      $$CachedTokensTableTableTableManager(
        _db.attachedDatabase,
        _db.cachedTokensTable,
      );
}

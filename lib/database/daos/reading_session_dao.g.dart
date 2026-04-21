// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_session_dao.dart';

// ignore_for_file: type=lint
mixin _$ReadingSessionDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReadingSessionTableTable get readingSessionTable =>
      attachedDatabase.readingSessionTable;
  ReadingSessionDaoManager get managers => ReadingSessionDaoManager(this);
}

class ReadingSessionDaoManager {
  final _$ReadingSessionDaoMixin _db;
  ReadingSessionDaoManager(this._db);
  $$ReadingSessionTableTableTableManager get readingSessionTable =>
      $$ReadingSessionTableTableTableManager(
        _db.attachedDatabase,
        _db.readingSessionTable,
      );
}

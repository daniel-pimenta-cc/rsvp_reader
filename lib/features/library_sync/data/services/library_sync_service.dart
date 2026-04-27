import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../database/app_database.dart';
import '../../../../database/daos/books_dao.dart';
import '../../../../database/daos/cached_tokens_dao.dart';
import '../../../../database/daos/reading_progress_dao.dart';
import '../../../../database/daos/sync_import_failures_dao.dart';
import '../../../../database/tables/book_source.dart';
import '../../../epub_import/data/services/epub_extraction_service.dart';
import '../../../epub_import/domain/entities/chapter.dart';
import '../../../rsvp_reader/domain/entities/display_settings.dart';
import '../../domain/entities/sync_config.dart';
import '../../domain/entities/sync_library.dart';
import '../../domain/repositories/sync_folder_gateway.dart';

const _kLibraryFile = 'library.json';
const _kBooksDir = 'books';

/// Pure functions that describe what the settings snapshot looks like on
/// disk. Kept as a map to stay forward-compatible with new DisplaySettings
/// fields without changing the sync schema every time.
Map<String, dynamic> displaySettingsToMap(DisplaySettings s) => {
      'wpm': s.wpm,
      'fontSize': s.fontSize,
      'contextFontSize': s.contextFontSize,
      'wordColorValue': s.wordColorValue,
      'orpColorValue': s.orpColorValue,
      'backgroundColorValue': s.backgroundColorValue,
      'highlightColorValue': s.highlightColorValue,
      'verticalPosition': s.verticalPosition,
      'horizontalPosition': s.horizontalPosition,
      'fontFamily': s.fontFamily,
      'showOrpHighlight': s.showOrpHighlight,
      'smartTiming': s.smartTiming,
      'rampUp': s.rampUp,
      'showFocusLine': s.showFocusLine,
      'focusLineShowsProgress': s.focusLineShowsProgress,
    };

DisplaySettings displaySettingsFromMap(Map<String, dynamic> m) {
  final defaults = const DisplaySettings();
  return defaults.copyWith(
    wpm: (m['wpm'] as num?)?.toInt(),
    fontSize: (m['fontSize'] as num?)?.toDouble(),
    contextFontSize: (m['contextFontSize'] as num?)?.toDouble(),
    wordColorValue: (m['wordColorValue'] as num?)?.toInt(),
    orpColorValue: (m['orpColorValue'] as num?)?.toInt(),
    backgroundColorValue: (m['backgroundColorValue'] as num?)?.toInt(),
    highlightColorValue: (m['highlightColorValue'] as num?)?.toInt(),
    verticalPosition: (m['verticalPosition'] as num?)?.toDouble(),
    horizontalPosition: (m['horizontalPosition'] as num?)?.toDouble(),
    fontFamily: m['fontFamily'] as String?,
    showOrpHighlight: m['showOrpHighlight'] as bool?,
    smartTiming: m['smartTiming'] as bool?,
    rampUp: m['rampUp'] as bool?,
    showFocusLine: m['showFocusLine'] as bool?,
    focusLineShowsProgress: m['focusLineShowsProgress'] as bool?,
  );
}

/// Called after pull to apply the synced DisplaySettings (the provider layer
/// writes the fields back to SharedPreferences by re-saving through the
/// notifier).
typedef ApplySettingsCallback = Future<void> Function(DisplaySettings);

/// Called to produce the current local DisplaySettings snapshot for push.
typedef ReadSettingsCallback = DisplaySettings Function();

/// Reports bulk-import progress. [current] is 0-based and incremented after
/// each file attempt; [total] is the number of files the service is about to
/// process (set on the initial call with current=0). [fileName] is the file
/// just attempted, or empty at the initial call.
typedef ImportProgressCallback = void Function(
    int current, int total, String fileName);

/// Orchestrates pull + push against the user-chosen folder.
///
/// Push/pull are not re-entrant: callers (typically [LibrarySyncNotifier])
/// serialize access with a mutex/flag.
class LibrarySyncService {
  final SyncFolderGateway _gateway;
  final BooksDao _booksDao;
  final ReadingProgressDao _progressDao;
  final CachedTokensDao _tokensDao;
  final SyncImportFailuresDao _failuresDao;
  final EpubExtractionService _extractionService;

  LibrarySyncService({
    required SyncFolderGateway gateway,
    required BooksDao booksDao,
    required ReadingProgressDao progressDao,
    required CachedTokensDao tokensDao,
    required SyncImportFailuresDao failuresDao,
    required EpubExtractionService extractionService,
  })  : _gateway = gateway,
        _booksDao = booksDao,
        _progressDao = progressDao,
        _tokensDao = tokensDao,
        _failuresDao = failuresDao,
        _extractionService = extractionService;

  /// Pull remote → merge with local → push merged back.
  ///
  /// Returns the time at which the sync completed on success. Throws on I/O
  /// errors — callers should catch and surface via [SyncResult.fail].
  Future<DateTime> sync({
    required SyncConfig config,
    required ReadSettingsCallback readSettings,
    required ApplySettingsCallback applySettings,
    DateTime? localSettingsUpdatedAt,
    ImportProgressCallback? onImportProgress,
  }) async {
    final folder = config.driveFolderId!;

    // 1. Kick off the three independent Drive reads in parallel. Previously
    // these were serial, costing ~3× the latency of the slowest one. Wall-
    // clock total is dominated by whichever finishes last.
    final isReadableF = _gateway.isReadable(folder);
    final readManifestF = _gateway.readText(folder, _kLibraryFile);
    final listBooksF = config.syncEpubs
        ? _gateway.listFiles(folder, _kBooksDir).catchError(
              (_) => <String>[],
            )
        : Future<List<String>>.value(const []);

    if (!await isReadableF) {
      throw StateError('Sync folder is not readable: $folder');
    }

    final remoteRaw = await readManifestF;
    SyncLibrary remote;
    if (remoteRaw == null || remoteRaw.trim().isEmpty) {
      remote = SyncLibrary.empty(config.deviceId);
    } else {
      remote = SyncLibrary.decode(remoteRaw);
    }

    // 2. Collect the books-dir inventory (launched in step 1).
    Set<String> remoteEpubFiles = const {};
    if (config.syncEpubs) {
      remoteEpubFiles = (await listBooksF).toSet();

      // Auto-import any EPUBs dropped directly in the sync folder that
      // aren't yet tracked by the manifest or the local DB. These become
      // regular local books; the subsequent snapshot will include them.
      await _autoImportOrphanFiles(
        folder: folder,
        remote: remote,
        remoteEpubFiles: remoteEpubFiles,
        onProgress: onImportProgress,
      );
    }

    // 3. Snapshot the (now possibly augmented) local library.
    // If the notifier didn't mark settings dirty this session, reuse the
    // remote timestamp so the snapshot doesn't look artificially newer than
    // the manifest — otherwise every sync pushes a fresh settings block and
    // the manifest-unchanged skip never triggers.
    final settingsTs = localSettingsUpdatedAt ??
        remote.settings?.updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final local = await _buildLocalSnapshot(
      config: config,
      localSettings: readSettings(),
      localSettingsUpdatedAt: settingsTs,
    );

    // 4. Merge.
    final rawMerged = mergeLibraries(local, remote, config.deviceId);
    // Garbage-collect zombie tombstones: entries with deletedAt whose
    // syncFileName is already claimed by an active merged book. These are
    // leftovers from an older orphan-reimport bug (deleted book → file
    // stayed in Drive → auto-imported under a new uuid with the same
    // filename). The active entry now owns that filename, so the tombstone
    // propagates nothing useful to other devices — drop it to stop every
    // sync from logging `skippedTombstones` forever.
    final activeFileNames = <String>{
      for (final b in rawMerged.books)
        if (b.deletedAt == null) b.syncFileName ?? '${b.id}.epub',
    };
    final compactedBooks = rawMerged.books.where((b) {
      if (b.deletedAt == null) return true;
      final name = b.syncFileName ?? '${b.id}.epub';
      return !activeFileNames.contains(name);
    }).toList();
    final compacted = compactedBooks.length == rawMerged.books.length
        ? rawMerged
        : SyncLibrary(
            schemaVersion: rawMerged.schemaVersion,
            updatedAt: rawMerged.updatedAt,
            updatedBy: rawMerged.updatedBy,
            settings: rawMerged.settings,
            books: compactedBooks,
          );
    final merged = compacted.copyWithMeta(
      updatedAt: DateTime.now().toUtc(),
      updatedBy: config.deviceId,
    );

    // 5. Apply remote → local for anything where remote won.
    await _applyToLocal(
      merged: merged,
      localBefore: local,
      config: config,
      applySettings: applySettings,
    );

    // 6. Push the merged snapshot back to the folder — but only if content
    // actually changed. Stamping a fresh updatedAt/updatedBy on every sync
    // triggers a ~3s Drive round-trip (find + update) for zero useful delta
    // when the user didn't touch anything since the last push.
    if (!_libraryContentEquals(merged, remote)) {
      await _gateway.writeText(folder, _kLibraryFile, merged.encode());
    }

    // 7. Upload any local EPUBs that the folder is missing (if sync on).
    if (config.syncEpubs) {
      await _uploadMissingEpubs(
        folder: folder,
        merged: merged,
        remoteEpubFiles: remoteEpubFiles,
      );
    }

    return DateTime.now();
  }

  Future<SyncLibrary> _buildLocalSnapshot({
    required SyncConfig config,
    required DisplaySettings localSettings,
    required DateTime localSettingsUpdatedAt,
  }) async {
    // Articles are local-only — they have no backing EPUB to upload and the
    // sync manifest is an EPUB library format. Skip them here.
    final books = (await _booksDao.getAllBooks())
        .where((b) => b.source == BookSource.epub)
        .toList();
    final snapshot = <SyncLibraryBook>[];
    for (final book in books) {
      final progress = await _progressDao.getProgressForBook(book.id);
      snapshot.add(SyncLibraryBook(
        id: book.id,
        title: book.title,
        author: book.author,
        totalWords: book.totalWords,
        chapterCount: book.chapterCount,
        importedAt: book.importedAt,
        lastReadAt: book.lastReadAt,
        hasEpubFile: true,
        syncFileName: book.syncFileName,
        progress: progress == null
            ? null
            : SyncLibraryProgress(
                chapterIndex: progress.chapterIndex,
                wordIndex: progress.wordIndex,
                wpm: progress.wpm,
                updatedAt: progress.updatedAt,
              ),
        deletedAt: null,
        updatedAt: book.lastReadAt ?? book.importedAt,
      ));
    }

    return SyncLibrary(
      updatedAt: DateTime.now().toUtc(),
      updatedBy: config.deviceId,
      settings: SyncLibrarySettings(
        values: displaySettingsToMap(localSettings),
        updatedAt: localSettingsUpdatedAt,
      ),
      books: snapshot,
    );
  }

  Future<void> _applyToLocal({
    required SyncLibrary merged,
    required SyncLibrary localBefore,
    required SyncConfig config,
    required ApplySettingsCallback applySettings,
  }) async {
    final localById = {for (final b in localBefore.books) b.id: b};

    for (final book in merged.books) {
      try {
        final local = localById[book.id];

        // Tombstone: remote says deleted → drop locally.
        if (book.deletedAt != null) {
          if (local != null) {
            await _deleteBookLocally(book.id);
          }
          continue;
        }

        if (local == null) {
          // New book from remote. Need the EPUB to populate tokens.
          if (config.syncEpubs) {
            await _importFromRemoteEpub(
              folder: config.driveFolderId!,
              book: book,
            );
          } else {
            // Insert a placeholder row so progress/metadata sync, but skip
            // tokens. Reader will prompt to re-import locally.
            await _insertPlaceholderBook(book);
            if (book.progress != null) {
              await _progressDao.upsertProgress(ReadingProgressTableCompanion(
                bookId: Value(book.id),
                chapterIndex: Value(book.progress!.chapterIndex),
                wordIndex: Value(book.progress!.wordIndex),
                wpm: Value(book.progress!.wpm),
                updatedAt: Value(book.progress!.updatedAt),
              ));
            }
          }
          continue;
        }

        // Book exists locally: update metadata + progress if merged differs.
        // DateTime comparisons use isAtSameMomentAs because local times come
        // from Drift (local TZ, isUtc=false) while remote times come from
        // the JSON manifest (isUtc=true). Default DateTime == compares both
        // microsSinceEpoch AND isUtc, so the same instant on the two sides
        // would always register as different — producing a needless write
        // per book on every sync.
        final localProg = local.progress;
        final remoteProg = book.progress;
        final progressDiffers = remoteProg != null &&
            (localProg == null ||
                !remoteProg.updatedAt.isAtSameMomentAs(localProg.updatedAt) ||
                remoteProg.wordIndex != localProg.wordIndex ||
                remoteProg.chapterIndex != localProg.chapterIndex);
        if (progressDiffers) {
          await _progressDao.upsertProgress(ReadingProgressTableCompanion(
            bookId: Value(book.id),
            chapterIndex: Value(remoteProg.chapterIndex),
            wordIndex: Value(remoteProg.wordIndex),
            wpm: Value(remoteProg.wpm),
            updatedAt: Value(remoteProg.updatedAt),
          ));
        }
        final lastReadDiffers = book.lastReadAt != null &&
            (local.lastReadAt == null ||
                !book.lastReadAt!.isAtSameMomentAs(local.lastReadAt!));
        if (lastReadDiffers) {
          await _booksDao.setLastReadAt(book.id, book.lastReadAt!);
        }
      } catch (e, st) {
        debugPrint('Failed to apply remote book "${book.id}": $e\n$st');
      }
    }

    // Settings: only apply when remote wins (its updatedAt > local's).
    // Isolated in its own try/catch so a prefs write failure doesn't bail
    // out of the sync before we write the merged manifest back to the
    // remote folder.
    final localSettingsTs = localBefore.settings?.updatedAt;
    final mergedSettingsTs = merged.settings?.updatedAt;
    if (merged.settings != null &&
        (localSettingsTs == null ||
            (mergedSettingsTs != null &&
                mergedSettingsTs.isAfter(localSettingsTs)))) {
      try {
        await applySettings(displaySettingsFromMap(merged.settings!.values));
      } catch (e, st) {
        debugPrint('Failed to apply remote settings: $e\n$st');
      }
    }
  }

  Future<void> _deleteBookLocally(String bookId) async {
    await _tokensDao.deleteTokensForBook(bookId);
    await _progressDao.deleteProgressForBook(bookId);
    final book = await _booksDao.getBookById(bookId);
    if (book != null) {
      final f = File(book.filePath);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {/* best effort */}
      }
    }
    await _booksDao.deleteBook(bookId);
  }

  /// Returns the relative path in the sync folder where [book]'s EPUB lives.
  /// Uses [SyncLibraryBook.syncFileName] when present, falling back to the
  /// legacy `<bookId>.epub` naming for books imported before the filename
  /// feature landed.
  String _epubRelPath(SyncLibraryBook book) {
    final name = book.syncFileName ?? '${book.id}.epub';
    return '$_kBooksDir/$name';
  }

  Future<void> _insertPlaceholderBook(SyncLibraryBook book) async {
    await _booksDao.insertBook(BooksTableCompanion.insert(
      id: book.id,
      title: book.title,
      author: Value(book.author),
      filePath: '', // no local file yet
      totalWords: Value(book.totalWords),
      chapterCount: Value(book.chapterCount),
      importedAt: book.importedAt,
      lastReadAt: Value(book.lastReadAt),
      syncFileName: Value(book.syncFileName),
    ));
  }

  Future<void> _importFromRemoteEpub({
    required String folder,
    required SyncLibraryBook book,
  }) async {
    final bytes = await _gateway.readBytes(folder, _epubRelPath(book));
    if (bytes == null) {
      // Remote metadata references an EPUB that isn't there yet. Insert
      // placeholder; next sync will fill it in.
      await _insertPlaceholderBook(book);
      if (book.progress != null) {
        await _progressDao.upsertProgress(ReadingProgressTableCompanion(
          bookId: Value(book.id),
          chapterIndex: Value(book.progress!.chapterIndex),
          wordIndex: Value(book.progress!.wordIndex),
          wpm: Value(book.progress!.wpm),
          updatedAt: Value(book.progress!.updatedAt),
        ));
      }
      return;
    }

    final parsed = await _extractionService.extractBook(bytes);
    if (parsed.chapters.isEmpty) {
      await _insertPlaceholderBook(book);
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/${AppConstants.booksSubdir}');
    if (!booksDir.existsSync()) {
      await booksDir.create(recursive: true);
    }
    final savedPath = '${booksDir.path}/${book.id}.epub';
    await File(savedPath).writeAsBytes(bytes);

    await _booksDao.insertBook(BooksTableCompanion.insert(
      id: book.id,
      title: book.title,
      author: Value(book.author),
      filePath: savedPath,
      coverImage: Value(parsed.coverImage),
      totalWords: Value(parsed.totalWords),
      chapterCount: Value(parsed.chapters.length),
      importedAt: book.importedAt,
      lastReadAt: Value(book.lastReadAt),
      syncFileName: Value(book.syncFileName),
    ));

    for (int i = 0; i < parsed.chapters.length; i++) {
      final Chapter ch = parsed.chapters[i];
      final tokensJson = jsonEncode(ch.tokens.map((t) => t.toJson()).toList());
      await _tokensDao.insertChapterTokens(CachedTokensTableCompanion.insert(
        bookId: book.id,
        chapterIndex: i,
        chapterTitle: Value(ch.title),
        tokensJson: tokensJson,
        wordCount: ch.tokens.length,
        paragraphCount: Value(
          ch.tokens.isEmpty ? 0 : ch.tokens.last.paragraphIndex + 1,
        ),
      ));
    }

    if (book.progress != null) {
      await _progressDao.upsertProgress(ReadingProgressTableCompanion(
        bookId: Value(book.id),
        chapterIndex: Value(book.progress!.chapterIndex),
        wordIndex: Value(book.progress!.wordIndex),
        wpm: Value(book.progress!.wpm),
        updatedAt: Value(book.progress!.updatedAt),
      ));
    }
  }

  Future<void> _uploadMissingEpubs({
    required String folder,
    required SyncLibrary merged,
    required Set<String> remoteEpubFiles,
  }) async {
    // Filenames claimed by at least one active (non-tombstoned) book in the
    // merged library. If two entries share a syncFileName — an old tombstone
    // plus a re-imported orphan, for example — the tombstone's delete would
    // clobber the active book's file and the next sync would upload it back,
    // forever. Actives win this tie: leave the file alone.
    final activeFileNames = <String>{};
    for (final book in merged.books) {
      if (book.deletedAt != null) continue;
      activeFileNames.add(book.syncFileName ?? '${book.id}.epub');
    }

    for (final book in merged.books) {
      final fileName = book.syncFileName ?? '${book.id}.epub';
      final relPath = '$_kBooksDir/$fileName';

      if (book.deletedAt != null) {
        if (activeFileNames.contains(fileName)) continue;
        // Only round-trip to Drive if the file actually exists; previous
        // syncs' tombstones would otherwise re-trigger a list+delete pair
        // for every already-removed file on every sync.
        if (remoteEpubFiles.contains(fileName)) {
          await _gateway.deleteFile(folder, relPath);
        }
        continue;
      }

      if (remoteEpubFiles.contains(fileName)) continue;

      final local = await _booksDao.getBookById(book.id);
      if (local == null || local.filePath.isEmpty) continue;
      final localFile = File(local.filePath);
      if (!await localFile.exists()) continue;

      final bytes = await localFile.readAsBytes();
      await _gateway.writeBytes(folder, relPath, bytes);
    }
  }

  /// Discovers EPUBs that the user dropped directly in the sync folder and
  /// imports them as fresh local books. A file is considered "orphan" when
  /// its name matches no entry in the remote manifest nor any local book's
  /// [BooksTableData.syncFileName].
  ///
  /// Files that previously failed to import are recorded in
  /// [SyncImportFailuresDao] and skipped on subsequent syncs so we don't
  /// thrash on a corrupt EPUB. Stale failure entries for files the user
  /// deleted from the cloud are pruned here as well. Per-file errors are
  /// caught so a single bad EPUB does not block the rest.
  ///
  /// Known limitation: matching is case-sensitive and by exact filename.
  /// Renaming a file in the cloud is treated as "delete old + new orphan",
  /// which produces a duplicate book. A content-hash dedup would fix this
  /// but is out of scope here.
  Future<void> _autoImportOrphanFiles({
    required String folder,
    required SyncLibrary remote,
    required Set<String> remoteEpubFiles,
    ImportProgressCallback? onProgress,
  }) async {
    await _failuresDao.retainOnly(remoteEpubFiles);
    final previouslyFailed = await _failuresDao.getAllFileNames();

    final knownInManifest = remote.books
        .where((b) => b.deletedAt == null && b.syncFileName != null)
        .map((b) => b.syncFileName!)
        .toSet();
    // Tombstoned filenames: re-importing them would spawn a second book row
    // with the same syncFileName as a pre-existing tombstone, which then
    // fights the active row each sync (tombstone deletes the active file,
    // active re-uploads, repeat forever). Treat them as "known" so the file
    // is left alone; the next _uploadMissingEpubs pass will clean it up via
    // the tombstone's delete branch.
    final tombstonedInManifest = remote.books
        .where((b) => b.deletedAt != null && b.syncFileName != null)
        .map((b) => b.syncFileName!)
        .toSet();
    final localBooks = await _booksDao.getAllBooks();
    final knownLocally = localBooks
        .map((b) => b.syncFileName)
        .whereType<String>()
        .toSet();

    final orphans = remoteEpubFiles
        .where((f) => f.toLowerCase().endsWith('.epub'))
        .where((f) => !knownInManifest.contains(f))
        .where((f) => !tombstonedInManifest.contains(f))
        .where((f) => !knownLocally.contains(f))
        .where((f) => !previouslyFailed.contains(f))
        .toList();
    if (orphans.isEmpty) return;

    onProgress?.call(0, orphans.length, '');

    for (int i = 0; i < orphans.length; i++) {
      final fileName = orphans[i];
      onProgress?.call(i, orphans.length, fileName);
      try {
        await _autoImportOrphan(folder: folder, fileName: fileName);
        // Success: clear any stale failure record for this filename.
        await _failuresDao.clear(fileName);
      } catch (e, st) {
        debugPrint('Failed to auto-import "$fileName": $e\n$st');
        await _failuresDao.record(fileName, e.toString());
      }
    }

    onProgress?.call(orphans.length, orphans.length, '');
  }

  Future<void> _autoImportOrphan({
    required String folder,
    required String fileName,
  }) async {
    final bytes = await _gateway.readBytes(folder, '$_kBooksDir/$fileName');
    if (bytes == null) return;

    final parsed = await _extractionService.extractBook(bytes);
    if (parsed.chapters.isEmpty) return;

    final bookId = const Uuid().v4();
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/${AppConstants.booksSubdir}');
    if (!booksDir.existsSync()) {
      await booksDir.create(recursive: true);
    }
    final savedPath = '${booksDir.path}/$bookId.epub';
    await File(savedPath).writeAsBytes(bytes);

    await _booksDao.insertBook(BooksTableCompanion.insert(
      id: bookId,
      title: parsed.title,
      author: Value(parsed.author),
      filePath: savedPath,
      coverImage: Value(parsed.coverImage),
      totalWords: Value(parsed.totalWords),
      chapterCount: Value(parsed.chapters.length),
      importedAt: DateTime.now(),
      syncFileName: Value(fileName),
    ));

    for (int i = 0; i < parsed.chapters.length; i++) {
      final Chapter ch = parsed.chapters[i];
      final tokensJson = jsonEncode(ch.tokens.map((t) => t.toJson()).toList());
      await _tokensDao.insertChapterTokens(CachedTokensTableCompanion.insert(
        bookId: bookId,
        chapterIndex: i,
        chapterTitle: Value(ch.title),
        tokensJson: tokensJson,
        wordCount: ch.tokens.length,
        paragraphCount: Value(
          ch.tokens.isEmpty ? 0 : ch.tokens.last.paragraphIndex + 1,
        ),
      ));
    }
  }

  /// True when two manifests describe the same library state, ignoring the
  /// per-sync metadata (`updatedAt`/`updatedBy`) that changes every run.
  /// Used to skip a ~3s round-trip when the user didn't actually touch
  /// anything between syncs.
  bool _libraryContentEquals(SyncLibrary a, SyncLibrary b) {
    if (a.books.length != b.books.length) return false;
    if (jsonEncode(a.settings?.toJson()) !=
        jsonEncode(b.settings?.toJson())) {
      return false;
    }
    // Sort by id so ordering differences don't cause false negatives.
    final aBooks = [...a.books]..sort((x, y) => x.id.compareTo(y.id));
    final bBooks = [...b.books]..sort((x, y) => x.id.compareTo(y.id));
    for (int i = 0; i < aBooks.length; i++) {
      if (jsonEncode(aBooks[i].toJson()) != jsonEncode(bBooks[i].toJson())) {
        return false;
      }
    }
    return true;
  }

  /// Write a tombstone to the remote library for [bookId] so other devices
  /// drop it on their next sync. Called from the delete path.
  Future<void> pushTombstone({
    required SyncConfig config,
    required String bookId,
    required DateTime deletedAt,
  }) async {
    final folder = config.driveFolderId!;
    if (!await _gateway.isReadable(folder)) return;

    final raw = await _gateway.readText(folder, _kLibraryFile);
    SyncLibrary remote = raw == null || raw.trim().isEmpty
        ? SyncLibrary.empty(config.deviceId)
        : SyncLibrary.decode(raw);

    final updated = <SyncLibraryBook>[];
    SyncLibraryBook? deletedEntry;
    bool found = false;
    for (final book in remote.books) {
      if (book.id == bookId) {
        found = true;
        final tombstone = book.copyWith(
          deletedAt: deletedAt,
          updatedAt: deletedAt,
        );
        deletedEntry = tombstone;
        updated.add(tombstone);
      } else {
        updated.add(book);
      }
    }
    if (!found) {
      final tombstone = SyncLibraryBook(
        id: bookId,
        title: '',
        totalWords: 0,
        chapterCount: 0,
        importedAt: deletedAt,
        hasEpubFile: false,
        deletedAt: deletedAt,
        updatedAt: deletedAt,
      );
      deletedEntry = tombstone;
      updated.add(tombstone);
    }

    final next = SyncLibrary(
      updatedAt: DateTime.now().toUtc(),
      updatedBy: config.deviceId,
      settings: remote.settings,
      books: updated,
    );
    await _gateway.writeText(folder, _kLibraryFile, next.encode());

    if (config.syncEpubs && deletedEntry != null) {
      await _gateway.deleteFile(folder, _epubRelPath(deletedEntry));
    }
  }
}

extension on SyncLibrary {
  SyncLibrary copyWithMeta({
    required DateTime updatedAt,
    required String updatedBy,
  }) {
    return SyncLibrary(
      schemaVersion: schemaVersion,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
      settings: settings,
      books: books,
    );
  }
}

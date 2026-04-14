import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../database/app_database.dart';
import '../../data/services/epub_extraction_service.dart';

final epubExtractionServiceProvider = Provider<EpubExtractionService>((ref) {
  return EpubExtractionService();
});

/// State for the import process.
enum ImportStatus { idle, picking, processing, done, error }

class ImportState {
  final ImportStatus status;
  final String? errorMessage;
  final String? importedBookId;

  const ImportState({
    this.status = ImportStatus.idle,
    this.errorMessage,
    this.importedBookId,
  });

  ImportState copyWith({
    ImportStatus? status,
    String? errorMessage,
    String? importedBookId,
  }) {
    return ImportState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      importedBookId: importedBookId ?? this.importedBookId,
    );
  }
}

class EpubImportNotifier extends StateNotifier<ImportState> {
  final Ref _ref;

  EpubImportNotifier(this._ref) : super(const ImportState());

  Future<void> importFromFilePicker() async {
    state = state.copyWith(status: ImportStatus.picking);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: ImportStatus.idle);
        return;
      }

      state = state.copyWith(status: ImportStatus.processing);

      final filePath = result.files.single.path!;
      final bytes = await File(filePath).readAsBytes();

      // 1. Parse EPUB
      final extractionService = _ref.read(epubExtractionServiceProvider);
      final parsedBook = await extractionService.extractBook(bytes);

      if (parsedBook.chapters.isEmpty) {
        state = state.copyWith(
          status: ImportStatus.error,
          errorMessage: 'No readable content found in EPUB',
        );
        return;
      }

      // 2. Save EPUB file to app storage
      final appDir = await getApplicationDocumentsDirectory();
      final bookId = const Uuid().v4();
      final booksDir = Directory('${appDir.path}/${AppConstants.booksSubdir}');
      if (!booksDir.existsSync()) {
        await booksDir.create(recursive: true);
      }
      final savedPath = '${booksDir.path}/$bookId.epub';
      await File(savedPath).writeAsBytes(bytes);

      // 3. Insert book metadata into database
      final booksDao = _ref.read(booksDaoProvider);
      await booksDao.insertBook(BooksTableCompanion.insert(
        id: bookId,
        title: parsedBook.title,
        author: Value(parsedBook.author),
        filePath: savedPath,
        coverImage: Value(parsedBook.coverImage),
        totalWords: Value(parsedBook.totalWords),
        chapterCount: Value(parsedBook.chapters.length),
        importedAt: DateTime.now(),
      ));

      // 4. Cache tokenized words per chapter
      final tokensDao = _ref.read(cachedTokensDaoProvider);
      for (int i = 0; i < parsedBook.chapters.length; i++) {
        final chapter = parsedBook.chapters[i];
        final tokensJson = jsonEncode(
          chapter.tokens.map((t) => t.toJson()).toList(),
        );
        await tokensDao.insertChapterTokens(CachedTokensTableCompanion.insert(
          bookId: bookId,
          chapterIndex: i,
          chapterTitle: Value(chapter.title),
          tokensJson: tokensJson,
          wordCount: chapter.tokens.length,
          paragraphCount: Value(
            chapter.tokens.isEmpty
                ? 0
                : chapter.tokens.last.paragraphIndex + 1,
          ),
        ));
      }

      // Do NOT create a reading_progress row here — the engine treats a
      // missing row as "not started" and defaults to (0, 0, defaultWpm) on
      // first open. Creating it at import time would put every freshly
      // imported book into the "In progress" section of the library.

      state = state.copyWith(
        status: ImportStatus.done,
        importedBookId: bookId,
      );
    } catch (e) {
      state = state.copyWith(
        status: ImportStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = const ImportState();
  }
}

final epubImportProvider =
    StateNotifierProvider<EpubImportNotifier, ImportState>((ref) {
  return EpubImportNotifier(ref);
});

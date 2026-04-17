import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../database/app_database.dart';
import '../../../epub_import/domain/entities/chapter.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/rsvp_state.dart';
import 'display_settings_provider.dart';

/// The heart of the app. Manages RSVP playback using a [Ticker] for
/// frame-accurate word timing.
class RsvpEngineNotifier extends StateNotifier<RsvpState> {
  final Ref _ref;
  Ticker? _ticker;
  Duration _elapsed = Duration.zero;
  Duration _nextWordAt = Duration.zero;
  int _wordsInSession = 0;
  Timer? _saveDebounce;
  int _lastSavedWordIndex = -1;

  RsvpEngineNotifier(this._ref, String bookId)
      : super(RsvpState(bookId: bookId));

  /// Initialize the engine: load cached tokens and restore progress.
  /// Must be called with a [TickerProvider] from the widget's mixin.
  Future<void> initialize(TickerProvider vsync) async {
    // Load cached tokens from database
    final tokensDao = _ref.read(cachedTokensDaoProvider);
    final cachedRows = await tokensDao.getTokensForBook(state.bookId);

    final chapters = <Chapter>[];
    for (final row in cachedRows) {
      final tokensList = (jsonDecode(row.tokensJson) as List)
          .map((j) => WordToken.fromJson(j as Map<String, dynamic>))
          .toList();
      chapters.add(Chapter(title: row.chapterTitle, tokens: tokensList));
    }

    if (chapters.isEmpty) return;

    // Load saved progress
    final progressDao = _ref.read(readingProgressDaoProvider);
    final progress = await progressDao.getProgressForBook(state.bookId);

    final chapterIdx = progress?.chapterIndex ?? 0;
    final wordIdx = progress?.wordIndex ?? 0;
    final wpm = progress?.wpm ?? AppConstants.defaultWpm;

    final totalWords = chapters.fold<int>(0, (sum, ch) => sum + ch.wordCount);
    final globalIdx = _calculateGlobalIndex(chapters, chapterIdx, wordIdx);

    _ticker = vsync.createTicker(_onTick);

    // Ensure display settings are loaded from disk before reading
    await _ref.read(displaySettingsProvider.notifier).load();
    final savedSettings = _ref.read(displaySettingsProvider);
    final displaySettings = savedSettings.copyWith(wpm: wpm);

    _lastSavedWordIndex = globalIdx;

    state = state.copyWith(
      chapters: chapters,
      currentChapterIndex: chapterIdx,
      currentWordIndex: wordIdx,
      globalWordIndex: globalIdx,
      totalWords: totalWords,
      currentWord: chapters[chapterIdx].tokens[wordIdx],
      wpm: wpm,
      isLoading: false,
      displaySettings: displaySettings,
    );
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;

    if (_elapsed >= _nextWordAt) {
      _advanceWord();
      _wordsInSession++;
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    final effectiveWpm = _effectiveWpm();
    final baseMs = 60000.0 / effectiveWpm;
    final multiplier =
        state.displaySettings.smartTiming
            ? (state.currentWord?.timingMultiplier ?? 1.0)
            : 1.0;
    _nextWordAt = _elapsed + Duration(milliseconds: (baseMs * multiplier).round());
  }

  /// Returns the current effective WPM accounting for ramp-up.
  ///
  /// Starts at [rampUpStartFraction] of target WPM and linearly
  /// increases to 100% over [rampUpWords] words.
  double _effectiveWpm() {
    final target = state.wpm.toDouble();
    if (!state.displaySettings.rampUp) return target;
    if (_wordsInSession >= AppConstants.rampUpWords) return target;

    final progress = _wordsInSession / AppConstants.rampUpWords;
    final startWpm = target * AppConstants.rampUpStartFraction;
    return startWpm + (target - startWpm) * progress;
  }

  // ---------- Public controls ----------

  void play() {
    if (state.isPlaying || state.isLoading) return;
    if (state.globalWordIndex >= state.totalWords - 1) return;

    _elapsed = Duration.zero;
    _nextWordAt = Duration.zero;
    _wordsInSession = 0;
    _ticker?.start();
    state = state.copyWith(isPlaying: true, mode: ReaderMode.rsvp);
  }

  void pause() {
    if (!state.isPlaying) return;
    _ticker?.stop();
    state = state.copyWith(isPlaying: false, mode: ReaderMode.scroll);
    _saveProgress();
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void enterEreaderMode() {
    if (state.isPlaying) {
      _ticker?.stop();
      _saveProgress();
    }
    state = state.copyWith(isPlaying: false, mode: ReaderMode.ereader);
  }

  void exitEreaderMode() {
    if (state.mode != ReaderMode.ereader) return;
    state = state.copyWith(mode: ReaderMode.scroll);
  }

  void toggleEreaderMode() {
    if (state.mode == ReaderMode.ereader) {
      exitEreaderMode();
    } else {
      enterEreaderMode();
    }
  }

  void setWpm(int wpm) {
    final clamped = wpm.clamp(AppConstants.minWpm, AppConstants.maxWpm);
    state = state.copyWith(
      wpm: clamped,
      displaySettings: state.displaySettings.copyWith(wpm: clamped),
    );
  }

  void increaseWpm() => setWpm(state.wpm + AppConstants.wpmStep);
  void decreaseWpm() => setWpm(state.wpm - AppConstants.wpmStep);

  /// Seek to a specific global word index.
  void seekToWord(int globalIndex) {
    final clamped = globalIndex.clamp(0, state.totalWords - 1);
    final (chapterIdx, wordIdx) = _globalToLocal(clamped);

    state = state.copyWith(
      currentChapterIndex: chapterIdx,
      currentWordIndex: wordIdx,
      globalWordIndex: clamped,
      currentWord: state.chapters[chapterIdx].tokens[wordIdx],
    );

    if (!state.isPlaying) _scheduleSaveProgress();
  }

  void skipForward([int words = AppConstants.skipWordCount]) {
    seekToWord(state.globalWordIndex + words);
  }

  void skipBackward([int words = AppConstants.skipWordCount]) {
    seekToWord(state.globalWordIndex - words);
  }

  void jumpToChapter(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) return;
    final globalIdx = _calculateGlobalIndex(state.chapters, chapterIndex, 0);
    seekToWord(globalIdx);
  }

  void updateDisplaySettings(DisplaySettings Function(DisplaySettings) updater) {
    state = state.copyWith(displaySettings: updater(state.displaySettings));
  }

  // ---------- Private helpers ----------

  void _advanceWord() {
    int chapterIdx = state.currentChapterIndex;
    int wordIdx = state.currentWordIndex + 1;

    if (wordIdx >= state.chapters[chapterIdx].tokens.length) {
      chapterIdx++;
      wordIdx = 0;
      if (chapterIdx >= state.chapters.length) {
        // End of book
        _ticker?.stop();
        state = state.copyWith(isPlaying: false);
        _saveProgress();
        return;
      }
    }

    state = state.copyWith(
      currentChapterIndex: chapterIdx,
      currentWordIndex: wordIdx,
      globalWordIndex: state.globalWordIndex + 1,
      currentWord: state.chapters[chapterIdx].tokens[wordIdx],
    );
  }

  /// Coalesce rapid saves (e.g. continuous slider drag) into one DB write.
  void _scheduleSaveProgress() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 300),
      _saveProgress,
    );
  }

  Future<void> _saveProgress() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (state.globalWordIndex == _lastSavedWordIndex) return;
    _lastSavedWordIndex = state.globalWordIndex;

    final progressDao = _ref.read(readingProgressDaoProvider);
    await progressDao.upsertProgress(ReadingProgressTableCompanion(
      bookId: Value(state.bookId),
      chapterIndex: Value(state.currentChapterIndex),
      wordIndex: Value(state.currentWordIndex),
      wpm: Value(state.wpm),
      updatedAt: Value(DateTime.now()),
    ));

    final booksDao = _ref.read(booksDaoProvider);
    await booksDao.updateLastReadAt(state.bookId);

    _ref.read(librarySyncProvider.notifier).schedulePush();
  }

  int _calculateGlobalIndex(List<Chapter> chapters, int chapterIdx, int wordIdx) {
    int global = 0;
    for (int c = 0; c < chapterIdx && c < chapters.length; c++) {
      global += chapters[c].tokens.length;
    }
    return global + wordIdx;
  }

  (int chapterIdx, int wordIdx) _globalToLocal(int globalIndex) {
    int remaining = globalIndex;
    for (int c = 0; c < state.chapters.length; c++) {
      if (remaining < state.chapters[c].tokens.length) {
        return (c, remaining);
      }
      remaining -= state.chapters[c].tokens.length;
    }
    // Fallback: last word of last chapter
    final lastChapter = state.chapters.length - 1;
    return (lastChapter, state.chapters[lastChapter].tokens.length - 1);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _saveProgress();
    }
    super.dispose();
  }
}

/// Provider family keyed by bookId.
final rsvpEngineProvider =
    StateNotifierProvider.family<RsvpEngineNotifier, RsvpState, String>(
  (ref, bookId) => RsvpEngineNotifier(ref, bookId),
);

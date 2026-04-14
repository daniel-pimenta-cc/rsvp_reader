import '../../../epub_import/domain/entities/chapter.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import 'display_settings.dart';

enum ReaderMode { rsvp, scroll, ereader }

class RsvpState {
  final String bookId;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final int currentWordIndex;
  final int globalWordIndex;
  final int totalWords;
  final WordToken? currentWord;
  final int wpm;
  final bool isPlaying;
  final bool isLoading;
  final ReaderMode mode;
  final DisplaySettings displaySettings;

  const RsvpState({
    required this.bookId,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.currentWordIndex = 0,
    this.globalWordIndex = 0,
    this.totalWords = 0,
    this.currentWord,
    this.wpm = 300,
    this.isPlaying = false,
    this.isLoading = true,
    this.mode = ReaderMode.scroll,
    this.displaySettings = const DisplaySettings(),
  });

  double get progress => totalWords > 0 ? globalWordIndex / totalWords : 0;

  String? get currentChapterTitle =>
      chapters.isNotEmpty && currentChapterIndex < chapters.length
          ? chapters[currentChapterIndex].title
          : null;

  int get estimatedMinutesRemaining {
    if (wpm <= 0) return 0;
    final remaining = totalWords - globalWordIndex;
    return (remaining / wpm).ceil();
  }

  RsvpState copyWith({
    String? bookId,
    List<Chapter>? chapters,
    int? currentChapterIndex,
    int? currentWordIndex,
    int? globalWordIndex,
    int? totalWords,
    WordToken? currentWord,
    int? wpm,
    bool? isPlaying,
    bool? isLoading,
    ReaderMode? mode,
    DisplaySettings? displaySettings,
  }) {
    return RsvpState(
      bookId: bookId ?? this.bookId,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      globalWordIndex: globalWordIndex ?? this.globalWordIndex,
      totalWords: totalWords ?? this.totalWords,
      currentWord: currentWord ?? this.currentWord,
      wpm: wpm ?? this.wpm,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      mode: mode ?? this.mode,
      displaySettings: displaySettings ?? this.displaySettings,
    );
  }
}

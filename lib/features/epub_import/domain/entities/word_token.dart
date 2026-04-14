import 'package:freezed_annotation/freezed_annotation.dart';

part 'word_token.freezed.dart';
part 'word_token.g.dart';

/// The fundamental unit of RSVP playback.
///
/// Every word in a book is pre-processed into a WordToken at import time.
/// ORP index and timing multiplier are pre-calculated so the RSVP engine's
/// hot loop does zero computation beyond reading these fields.
@freezed
abstract class WordToken with _$WordToken {
  const factory WordToken({
    required String text,
    required int orpIndex,
    required double timingMultiplier,
    required int globalIndex,
    required int chapterIndex,
    required int paragraphIndex,
    @Default(false) bool isParagraphStart,
    @Default(false) bool isChapterStart,
  }) = _WordToken;

  factory WordToken.fromJson(Map<String, dynamic> json) =>
      _$WordTokenFromJson(json);
}

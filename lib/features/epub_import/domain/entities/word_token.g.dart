// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WordToken _$WordTokenFromJson(Map<String, dynamic> json) => _WordToken(
  text: json['text'] as String,
  orpIndex: (json['orpIndex'] as num).toInt(),
  timingMultiplier: (json['timingMultiplier'] as num).toDouble(),
  globalIndex: (json['globalIndex'] as num).toInt(),
  chapterIndex: (json['chapterIndex'] as num).toInt(),
  paragraphIndex: (json['paragraphIndex'] as num).toInt(),
  isParagraphStart: json['isParagraphStart'] as bool? ?? false,
  isChapterStart: json['isChapterStart'] as bool? ?? false,
);

Map<String, dynamic> _$WordTokenToJson(_WordToken instance) =>
    <String, dynamic>{
      'text': instance.text,
      'orpIndex': instance.orpIndex,
      'timingMultiplier': instance.timingMultiplier,
      'globalIndex': instance.globalIndex,
      'chapterIndex': instance.chapterIndex,
      'paragraphIndex': instance.paragraphIndex,
      'isParagraphStart': instance.isParagraphStart,
      'isChapterStart': instance.isChapterStart,
    };

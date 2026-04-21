import 'package:flutter/material.dart';

/// Assigns a distinct color to each of the top-N books in the stats window.
/// Books beyond [maxDistinctBooks] collapse into a single "Other" color so
/// the stacked chart stays legible.
///
/// Palette is derived from [scheme.primary] by rotating HSL hue — keeps the
/// accent orange dominant on the first (most-read) book, with cool shifts
/// for the tail.
class StatsColorPalette {
  static const int maxDistinctBooks = 5;

  final Map<String, Color> _byBook;
  final Color otherColor;

  const StatsColorPalette._(this._byBook, this.otherColor);

  factory StatsColorPalette.forBooks({
    required List<String> orderedBookIds,
    required ColorScheme scheme,
  }) {
    final base = HSLColor.fromColor(scheme.primary);
    final map = <String, Color>{};
    for (var i = 0; i < orderedBookIds.length && i < maxDistinctBooks; i++) {
      final hue = (base.hue + (i * 47)) % 360;
      final lightness = (base.lightness + (i.isOdd ? -0.05 : 0.05)).clamp(0.35, 0.65);
      map[orderedBookIds[i]] = base.withHue(hue).withLightness(lightness).toColor();
    }
    return StatsColorPalette._(map, scheme.outlineVariant);
  }

  Color colorFor(String bookId) => _byBook[bookId] ?? otherColor;

  bool isDistinct(String bookId) => _byBook.containsKey(bookId);
}

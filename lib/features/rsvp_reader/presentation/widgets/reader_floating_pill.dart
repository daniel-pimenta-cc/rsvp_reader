import 'package:flutter/material.dart';

/// Shared look of the reader's floating overlays — the lock/recenter pill in
/// the context view and the mode switcher. Colours come from
/// [DisplaySettings] (passed in), never `Theme.of(context)`, so the pills
/// track the live theme preview like everything else in the reader.
BoxDecoration readerPillDecoration({
  required Color backgroundColor,
  required Color wordColor,
  BorderRadius? borderRadius,
}) {
  return BoxDecoration(
    // Forced opaque: the pills float over body text, and the reader's
    // background colour can itself carry alpha (the colour picker exposes
    // an opacity slider), which let paragraphs ghost right through them.
    color: backgroundColor.withAlpha(255),
    shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: borderRadius,
    border: Border.all(color: wordColor.withAlpha(38)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(28),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

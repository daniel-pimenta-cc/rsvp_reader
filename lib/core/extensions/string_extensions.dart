extension StringX on String {
  /// Whether a single character is a letter or digit, including accented Latin chars.
  bool get isLetterOrDigit {
    if (isEmpty) return false;
    final rune = runes.first;
    return (rune >= 0x30 && rune <= 0x39) || // 0-9
        (rune >= 0x41 && rune <= 0x5A) || // A-Z
        (rune >= 0x61 && rune <= 0x7A) || // a-z
        (rune >= 0xC0 && rune <= 0xFF && rune != 0xD7 && rune != 0xF7) || // Latin-1 accented
        (rune >= 0x100 && rune <= 0x24F); // Latin Extended-A and B
  }
}

import 'package:flutter/material.dart';

abstract final class AppShadows {
  static List<BoxShadow> level1({required Brightness brightness}) {
    final base = brightness == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFF1A120B);
    final alpha = brightness == Brightness.dark ? 0x30 : 0x18;
    return [
      BoxShadow(
        color: base.withAlpha(alpha),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> level2({required Brightness brightness}) {
    final base = brightness == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFF1A120B);
    final alpha = brightness == Brightness.dark ? 0x45 : 0x22;
    return [
      BoxShadow(
        color: base.withAlpha(alpha),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> level3({required Brightness brightness}) {
    final base = brightness == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFF1A120B);
    final alpha = brightness == Brightness.dark ? 0x55 : 0x2E;
    return [
      BoxShadow(
        color: base.withAlpha(alpha),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> level4({required Brightness brightness}) {
    final base = brightness == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFF1A120B);
    final alpha = brightness == Brightness.dark ? 0x66 : 0x3A;
    return [
      BoxShadow(
        color: base.withAlpha(alpha),
        blurRadius: 40,
        offset: const Offset(0, 12),
      ),
    ];
  }
}

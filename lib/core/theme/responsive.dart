import 'package:flutter/widgets.dart';

abstract final class Breakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;
}

enum DeviceType { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  Size get _size => MediaQuery.of(this).size;
  Orientation get _orientation => MediaQuery.of(this).orientation;

  bool get isTablet => _size.shortestSide >= Breakpoints.compact;
  bool get isLandscape => _orientation == Orientation.landscape;

  DeviceType get deviceType {
    final w = _size.width;
    if (w >= Breakpoints.medium) return DeviceType.expanded;
    if (w >= Breakpoints.compact) return DeviceType.medium;
    return DeviceType.compact;
  }
}

int gridCrossAxisCount(BuildContext context) {
  switch (context.deviceType) {
    case DeviceType.compact:
      return 2;
    case DeviceType.medium:
      return 3;
    case DeviceType.expanded:
      return 4;
  }
}

double gridAspectRatio(BuildContext context) {
  switch (context.deviceType) {
    case DeviceType.compact:
      return 0.65;
    case DeviceType.medium:
      return 0.7;
    case DeviceType.expanded:
      return 0.72;
  }
}

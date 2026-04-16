import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';
import '../theme/responsive.dart';

/// Responsive defaults for the RSVP reader UI. These are *display-time*
/// scalars — they do NOT rewrite `DisplaySettings` in storage. They apply
/// only when the user hasn't customized a given parameter (i.e., it's still
/// the factory default), so tablets get a larger word out of the box without
/// overriding anyone's saved preference.
abstract final class ResponsiveDefaults {
  /// Display-only scale factor applied on top of the user's stored RSVP font
  /// size when they're still on the factory default. On tablets we nudge the
  /// word bigger so it reads comfortably at a longer viewing distance.
  static double rsvpFontScale(BuildContext context) {
    switch (context.deviceType) {
      case DeviceType.compact:
        return 1.0;
      case DeviceType.medium:
        return 1.25;
      case DeviceType.expanded:
        return 1.4;
    }
  }

  /// Horizontal breathing room around the RSVP word. Wider on tablet so
  /// long words still feel anchored near the ORP line instead of colliding
  /// with the screen edges.
  static double rsvpWordMargin(BuildContext context) {
    switch (context.deviceType) {
      case DeviceType.compact:
        return AppSpacing.xl; // 32
      case DeviceType.medium:
        return AppSpacing.xxl; // 48
      case DeviceType.expanded:
        return AppSpacing.xxl + AppSpacing.base; // 64
    }
  }

  /// Max line-length for the context-scroll reading view. Keeping text
  /// around the classic editorial ~65-character measure avoids "scanning
  /// across an entire tablet" fatigue.
  static double readableMaxWidth(BuildContext context) {
    switch (context.deviceType) {
      case DeviceType.compact:
        return double.infinity;
      case DeviceType.medium:
        return 640;
      case DeviceType.expanded:
        return 720;
    }
  }
}

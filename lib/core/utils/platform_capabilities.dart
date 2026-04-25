import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Static checks for platform-specific capabilities. Use these instead of
/// scattering `Platform.isAndroid` / `Platform.isLinux` across the codebase.
class PlatformCapabilities {
  PlatformCapabilities._();

  /// `receive_sharing_intent` only ships Android + iOS bindings.
  static bool get supportsShareIntent {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Drive sync depends on `google_sign_in`, which only has a working
  /// Android implementation in this project. iOS would need a provisioning
  /// profile; desktop platforms need an OAuth loopback flow we haven't
  /// built yet.
  static bool get supportsDriveSync {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  }

  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
}

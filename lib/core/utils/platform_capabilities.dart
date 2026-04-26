import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../features/library_sync/data/auth/desktop_oauth_drive_auth_backend.dart';

/// Static checks for platform-specific capabilities. Use these instead of
/// scattering `Platform.isAndroid` / `Platform.isLinux` across the codebase.
class PlatformCapabilities {
  PlatformCapabilities._();

  /// `receive_sharing_intent` only ships Android + iOS bindings.
  static bool get supportsShareIntent {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Drive sync. Android uses the native `google_sign_in` flow. Linux
  /// uses an OAuth loopback flow against credentials baked in at build
  /// time via --dart-define; if those weren't provided, the section is
  /// hidden so we don't surface a button that can only error.
  /// iOS would need a separate provisioning profile and is not wired up.
  static bool get supportsDriveSync {
    if (kIsWeb) return false;
    if (Platform.isAndroid) return true;
    if (Platform.isLinux) return desktopOAuthCredentialsConfigured;
    return false;
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

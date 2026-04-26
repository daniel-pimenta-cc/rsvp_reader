import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as ga;

import '../../../../core/utils/platform_capabilities.dart';
import '../../data/auth/desktop_oauth_drive_auth_backend.dart';
import '../../data/auth/drive_auth_backend.dart';
import '../../data/auth/google_sign_in_drive_auth_backend.dart';

class DriveAuthState {
  final bool isBusy;
  final String? email;
  final String? errorMessage;

  const DriveAuthState({
    this.isBusy = false,
    this.email,
    this.errorMessage,
  });

  bool get isSignedIn => email != null;

  DriveAuthState copyWith({
    bool? isBusy,
    String? email,
    bool clearEmail = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriveAuthState(
      isBusy: isBusy ?? this.isBusy,
      email: clearEmail ? null : (email ?? this.email),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DriveAuthNotifier extends StateNotifier<DriveAuthState> {
  final DriveAuthBackend _backend;

  DriveAuthNotifier(this._backend) : super(const DriveAuthState());

  /// Attempt a silent sign-in using cached credentials. Safe to call on
  /// every app launch — returns false if there's no cached account or
  /// the refresh fails.
  Future<bool> trySilentSignIn() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _backend.trySilentSignIn();
      state = DriveAuthState(email: result?.email);
      return result != null;
    } catch (e) {
      state = DriveAuthState(errorMessage: e.toString());
      return false;
    }
  }

  /// Interactive sign-in. Shows the account chooser (mobile) or opens
  /// the system browser (desktop).
  Future<bool> signIn() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _backend.signIn();
      if (result == null) {
        // user cancelled
        state = const DriveAuthState();
        return false;
      }
      state = DriveAuthState(email: result.email);
      return true;
    } catch (e) {
      state = DriveAuthState(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _backend.signOut();
    } finally {
      state = const DriveAuthState();
    }
  }

  /// Returns an HTTP client authenticated with the current user's Drive
  /// scope. Null when signed out or when tokens cannot be refreshed.
  ///
  /// The client handles token refresh automatically. Close it when done.
  Future<ga.AuthClient?> authenticatedClient() {
    return _backend.authenticatedClient();
  }
}

/// Picks the auth backend per platform. Override in tests with
/// `driveAuthBackendProvider.overrideWith((ref) => FakeBackend())`.
final driveAuthBackendProvider = Provider<DriveAuthBackend>((ref) {
  if (PlatformCapabilities.isDesktop) {
    return DesktopOAuthDriveAuthBackend();
  }
  return GoogleSignInDriveAuthBackend();
});

final driveAuthProvider =
    StateNotifierProvider<DriveAuthNotifier, DriveAuthState>((ref) {
  return DriveAuthNotifier(ref.watch(driveAuthBackendProvider));
});

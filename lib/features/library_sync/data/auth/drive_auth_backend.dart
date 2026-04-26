import 'package:googleapis_auth/googleapis_auth.dart' as ga;

/// Result of a sign-in attempt. We carry only the email back to the
/// caller — anything else lives inside the backend.
class DriveSignInResult {
  final String email;
  const DriveSignInResult(this.email);
}

/// Platform-agnostic surface for Google Drive authentication. The
/// [DriveAuthNotifier] only talks to this interface; concrete
/// implementations handle the platform specifics (native Android sheet,
/// desktop OAuth loopback, etc.).
abstract class DriveAuthBackend {
  /// Try to restore a previous session without UI. Returns the email
  /// when successful, null otherwise. Must never throw.
  Future<DriveSignInResult?> trySilentSignIn();

  /// Interactive sign-in. Returns the email on success, null if the
  /// user cancelled. Throws on hard errors so the caller can surface
  /// them.
  Future<DriveSignInResult?> signIn();

  /// Wipe local credentials so the next [signIn] starts fresh.
  Future<void> signOut();

  /// Returns an authenticated HTTP client with the Drive scope. Null
  /// when there is no current session or the cached refresh token is
  /// no longer valid.
  Future<ga.AuthClient?> authenticatedClient();
}

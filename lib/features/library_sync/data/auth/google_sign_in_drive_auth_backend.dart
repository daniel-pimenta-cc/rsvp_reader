import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as ga;

import 'drive_auth_backend.dart';

/// Mobile (Android/iOS) backend. Wraps [GoogleSignIn] — the OAuth
/// credentials live in the native config (google-services.json on
/// Android, plist on iOS) so there's no client_id/secret to thread
/// through the constructor.
class GoogleSignInDriveAuthBackend implements DriveAuthBackend {
  final GoogleSignIn _google;

  GoogleSignInDriveAuthBackend()
      : _google = GoogleSignIn(scopes: const [drive.DriveApi.driveFileScope]);

  @override
  Future<DriveSignInResult?> trySilentSignIn() async {
    final account = await _google.signInSilently(suppressErrors: true);
    if (account == null) return null;
    return DriveSignInResult(account.email);
  }

  @override
  Future<DriveSignInResult?> signIn() async {
    final account = await _google.signIn();
    if (account == null) return null; // user cancelled
    return DriveSignInResult(account.email);
  }

  @override
  Future<void> signOut() => _google.signOut();

  @override
  Future<ga.AuthClient?> authenticatedClient() => _google.authenticatedClient();
}

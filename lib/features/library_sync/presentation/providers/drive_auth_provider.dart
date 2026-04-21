import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as ga;

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
  final GoogleSignIn _google;

  DriveAuthNotifier()
      : _google = GoogleSignIn(scopes: const [drive.DriveApi.driveFileScope]),
        super(const DriveAuthState());

  /// Attempt a silent sign-in using cached credentials. Safe to call on
  /// every app launch — returns false if there's no cached account or
  /// the refresh fails.
  Future<bool> trySilentSignIn() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final account = await _google.signInSilently(suppressErrors: true);
      state = DriveAuthState(email: account?.email);
      return account != null;
    } catch (e) {
      state = DriveAuthState(errorMessage: e.toString());
      return false;
    }
  }

  /// Interactive sign-in. Shows the account chooser.
  Future<bool> signIn() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final account = await _google.signIn();
      if (account == null) {
        // user cancelled
        state = const DriveAuthState();
        return false;
      }
      state = DriveAuthState(email: account.email);
      return true;
    } catch (e) {
      state = DriveAuthState(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } finally {
      state = const DriveAuthState();
    }
  }

  /// Returns an HTTP client authenticated with the current user's Drive
  /// scope. Null when signed out or when tokens cannot be refreshed.
  ///
  /// The client handles token refresh automatically. Close it when done.
  Future<ga.AuthClient?> authenticatedClient() {
    return _google.authenticatedClient();
  }
}

final driveAuthProvider =
    StateNotifierProvider<DriveAuthNotifier, DriveAuthState>((ref) {
  return DriveAuthNotifier();
});

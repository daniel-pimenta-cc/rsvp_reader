import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Book currently loaded in the master-detail right pane (tablet landscape).
/// `null` means the placeholder is shown. On compact / portrait layouts
/// this provider isn't consulted — navigation uses `context.push('/reader/...')`
/// as before.
final selectedBookIdProvider = StateProvider<String?>((ref) => null);

/// Whether the library list panel is visible in master-detail. Defaults to
/// true; the user can collapse it to give the reader the full window width
/// (desktop / tablet landscape only). Ephemeral — resets on app restart.
final libraryPanelVisibleProvider = StateProvider<bool>((ref) => true);

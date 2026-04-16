import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Book currently loaded in the master-detail right pane (tablet landscape).
/// `null` means the placeholder is shown. On compact / portrait layouts
/// this provider isn't consulted — navigation uses `context.push('/reader/...')`
/// as before.
final selectedBookIdProvider = StateProvider<String?>((ref) => null);

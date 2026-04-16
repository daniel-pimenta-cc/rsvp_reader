import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which auxiliary panel is visible in the reader's tablet-landscape layout.
/// On compact / portrait layouts this is unused — settings and chapters
/// still come up as bottom sheets.
enum ReaderSidePanelMode { none, settings, chapters }

final readerSidePanelProvider =
    StateProvider<ReaderSidePanelMode>((ref) => ReaderSidePanelMode.none);

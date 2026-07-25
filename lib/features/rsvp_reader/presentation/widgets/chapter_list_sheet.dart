import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/reader_side_panel_provider.dart';
import '../providers/rsvp_engine_provider.dart';
import 'chapter_list_view.dart';
import 'reader_sheet_shell.dart';

/// Opens the chapter list — side panel on tablet landscape, bottom sheet
/// everywhere else. Shared by the reader's top bar (chapter title button)
/// and the dock's chapter counter.
void openChapterList(BuildContext context, WidgetRef ref, String bookId) {
  if (context.isTablet && context.isLandscape) {
    final current = ref.read(readerSidePanelProvider);
    ref.read(readerSidePanelProvider.notifier).state =
        current == ReaderSidePanelMode.chapters
            ? ReaderSidePanelMode.none
            : ReaderSidePanelMode.chapters;
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChapterListSheet(bookId: bookId),
  );
}

/// Bottom sheet showing a list of chapters for navigation.
class ChapterListSheet extends ConsumerWidget {
  final String bookId;

  const ChapterListSheet({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(rsvpEngineProvider(bookId).select((s) => s.displaySettings));
    final l10n = AppLocalizations.of(context)!;

    return ReaderSheetShell(
      settings: settings,
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.8,
      title: l10n.chaptersTitle,
      bodyBuilder: (context, scrollController) => Expanded(
        child: ChapterListView(
          bookId: bookId,
          settings: settings,
          controller: scrollController,
          onJump: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

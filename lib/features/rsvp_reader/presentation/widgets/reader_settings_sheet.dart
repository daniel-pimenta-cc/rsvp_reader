import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/display_settings_provider.dart';
import 'display_settings_panel.dart';
import 'finish_book_button.dart';
import 'reader_sheet_shell.dart';

/// Bottom sheet wrapper around the compact [DisplaySettingsPanel], shown from
/// the reader. Only the settings that affect the mode you're reading in; the
/// rest is one tap away in the full-screen page.
class ReaderSettingsSheet extends ConsumerWidget {
  final String bookId;

  const ReaderSettingsSheet({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);

    return ReaderSheetShell(
      settings: settings,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      showDivider: false,
      bodyBuilder: (context, scrollController) => Expanded(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            children: [
              DisplaySettingsPanel(bookId: bookId, compact: true),
              const SizedBox(height: 12),
              AllSettingsLink(
                settings: settings,
                onBeforeNavigate: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 16),
              FinishBookButton(
                bookId: bookId,
                settings: settings,
                onBeforeNavigate: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

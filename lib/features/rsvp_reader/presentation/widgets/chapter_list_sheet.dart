import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/rsvp_engine_provider.dart';

/// Bottom sheet showing a list of chapters for navigation.
class ChapterListSheet extends ConsumerWidget {
  final String bookId;

  const ChapterListSheet({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rsvpEngineProvider(bookId));
    final engine = ref.read(rsvpEngineProvider(bookId).notifier);
    final settings = state.displaySettings;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Color.lerp(settings.backgroundColor, Colors.white, 0.08),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: settings.wordColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chapters',
                    style: TextStyle(
                      color: settings.wordColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Chapter list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: state.chapters.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (context, index) {
                    final chapter = state.chapters[index];
                    final isCurrent =
                        index == state.currentChapterIndex;

                    return ListTile(
                      dense: true,
                      selected: isCurrent,
                      selectedTileColor:
                          settings.orpColor.withAlpha(30),
                      leading: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent
                              ? settings.orpColor
                              : settings.wordColor.withAlpha(100),
                          fontSize: 14,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      title: Text(
                        chapter.title,
                        style: TextStyle(
                          color: isCurrent
                              ? settings.orpColor
                              : settings.wordColor,
                          fontSize: 14,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${chapter.wordCount} words',
                        style: TextStyle(
                          color: settings.wordColor.withAlpha(80),
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        engine.jumpToChapter(index);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

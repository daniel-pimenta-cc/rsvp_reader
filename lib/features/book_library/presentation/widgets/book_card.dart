import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../database/app_database.dart';
import '../../../../database/tables/book_source.dart';
import '../providers/book_library_provider.dart';
import 'reading_progress_bar.dart';

class BookCard extends ConsumerStatefulWidget {
  final BooksTableData book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  const BookCard({
    required this.book,
    required this.onTap,
    required this.onLongPress,
    this.selected = false,
    super.key,
  });

  @override
  ConsumerState<BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<BookCard> {
  bool _pressed = false;

  /// For articles we prefer the site name over the (often empty) author
  /// field — it's the clearer attribution for web content.
  String? get _subtitle {
    final book = widget.book;
    if (book.source == BookSource.article) {
      final site = book.siteName;
      if (site != null && site.isNotEmpty) return site;
      final author = book.author;
      if (author != null && author.isNotEmpty) return author;
      final url = book.sourceUrl;
      if (url != null && url.isNotEmpty) {
        return Uri.tryParse(url)?.host ?? url;
      }
      return null;
    }
    return book.author;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress =
        ref.watch(bookProgressProvider(widget.book.id)).valueOrNull ?? 0.0;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: AppRadius.borderLg,
          border: widget.selected
              ? Border.all(color: scheme.primary, width: 1.5)
              : Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.borderLg,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap();
              },
              onLongPress: widget.onLongPress,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _Cover(book: widget.book),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _subtitle!,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: ReadingProgressBar(progress: progress),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '${(progress * 100).round()}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final BooksTableData book;
  const _Cover({required this.book});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (book.coverImage != null) {
      return Image.memory(book.coverImage!, fit: BoxFit.cover);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withAlpha(55),
            scheme.surfaceContainerHigh,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          book.source == BookSource.article
              ? Icons.article_outlined
              : Icons.menu_book_outlined,
          size: 52,
          color: scheme.primary.withAlpha(180),
        ),
      ),
    );
  }
}

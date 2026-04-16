import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/article_import_provider.dart';

/// Prompts the user for an article URL, then kicks off the article import
/// via [articleImportProvider]. The library screen listens to that provider
/// for navigation + error snackbars, so this dialog only deals with input.
class ImportArticleDialog extends ConsumerStatefulWidget {
  const ImportArticleDialog({super.key});

  @override
  ConsumerState<ImportArticleDialog> createState() =>
      _ImportArticleDialogState();
}

class _ImportArticleDialogState extends ConsumerState<ImportArticleDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _maybePrefillFromClipboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// If the clipboard holds an http/https URL, drop it in the field so the
  /// user doesn't have to paste manually. Runs once on open.
  Future<void> _maybePrefillFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final url = UrlUtils.extractHttpUrl(data?.text ?? '');
      if (url != null && mounted) {
        setState(() {
          _controller.text = url;
          _prefilled = true;
        });
      }
    } catch (_) {
      // Clipboard access can fail on some platforms; ignore.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.base,
        AppSpacing.lg,
        AppSpacing.base,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.importArticle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.importArticleUrlHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.importArticleUrlLabel,
              prefixIcon: const Icon(Icons.link, size: 20),
              suffixIcon: _prefilled
                  ? IconButton(
                      tooltip: l10n.cancel,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _prefilled = false);
                        _focusNode.requestFocus();
                      },
                    )
                  : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_prefilled) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.content_paste,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.importArticleClipboardHint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.importArticleCta),
        ),
      ],
    );
  }

  void _submit() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    Navigator.of(context).pop();
    ref.read(articleImportProvider.notifier).importFromUrl(url);
  }
}

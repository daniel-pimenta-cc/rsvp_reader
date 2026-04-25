import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../features/article_import/presentation/providers/article_import_provider.dart';
import '../utils/platform_capabilities.dart';
import '../utils/url_utils.dart';

/// Wraps the app and funnels share-sheet events (URLs / plain text) into
/// [ArticleImportNotifier.importFromUrl]. Handles both cold start (app was
/// launched via share) and warm start (stream while app is open).
class ShareIntentHandler extends ConsumerStatefulWidget {
  final Widget child;

  const ShareIntentHandler({required this.child, super.key});

  @override
  ConsumerState<ShareIntentHandler> createState() => _ShareIntentHandlerState();
}

class _ShareIntentHandlerState extends ConsumerState<ShareIntentHandler> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();

    // The plugin only registers a native binding on Android and iOS; calling
    // it on desktop throws a MissingPluginException.
    if (!PlatformCapabilities.supportsShareIntent) return;

    // Cold start: the app was launched by the system share sheet.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (!mounted) return;
      _handle(files);
      ReceiveSharingIntent.instance.reset();
    });

    _sub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handle, onError: (Object _) {/* swallow */});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handle(List<SharedMediaFile> files) {
    for (final file in files) {
      if (file.type != SharedMediaType.url &&
          file.type != SharedMediaType.text) {
        continue;
      }
      final url = UrlUtils.extractHttpUrl(file.path);
      if (url != null) {
        // Fire-and-forget: the article-import provider is watched at the
        // app level (see app.dart) to handle navigation + snackbar.
        ref.read(articleImportProvider.notifier).importFromUrl(url);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

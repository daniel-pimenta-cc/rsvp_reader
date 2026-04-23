import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';

class LibraryAppBarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  final TabController tabController;
  final AppLocalizations l10n;
  final LibrarySyncState syncState;

  const LibraryAppBarBottom({
    required this.tabController,
    required this.l10n,
    required this.syncState,
    super.key,
  });

  static const _tabsHeight = 48.0;
  static const _progressHeight = 48.0;
  static const _syncHairlineHeight = 2.0;

  bool get _showSyncHairline =>
      !syncState.isImporting && syncState.stage == SyncStage.syncing;

  @override
  Size get preferredSize {
    double height = _tabsHeight;
    if (syncState.isImporting) height += _progressHeight;
    if (_showSyncHairline) height += _syncHairlineHeight;
    return Size.fromHeight(height);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (syncState.isImporting)
          LibraryImportProgressBar(
            current: syncState.importCurrent ?? 0,
            total: syncState.importTotal ?? 0,
            fileName: syncState.importFileName ?? '',
            l10n: l10n,
          )
        else if (_showSyncHairline)
          SizedBox(
            height: _syncHairlineHeight,
            child: LinearProgressIndicator(
              minHeight: _syncHairlineHeight,
              backgroundColor: theme.colorScheme.outlineVariant.withAlpha(80),
              color: theme.colorScheme.primary.withAlpha(160),
            ),
          ),
        TabBar(
          controller: tabController,
          indicatorWeight: 2,
          tabs: [
            Tab(text: l10n.libraryTabBooks),
            Tab(text: l10n.libraryTabArticles),
          ],
        ),
      ],
    );
  }
}

class LibraryImportProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final String fileName;
  final AppLocalizations l10n;

  const LibraryImportProgressBar({
    required this.current,
    required this.total,
    required this.fileName,
    required this.l10n,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
    final displayName = fileName.isEmpty ? '\u2026' : fileName;
    return SizedBox(
      height: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: fraction == 0 ? null : fraction,
            minHeight: 2,
            backgroundColor: theme.colorScheme.outlineVariant,
            color: theme.colorScheme.primary,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.xs + 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.syncImportingProgress(
                      current + 1 > total ? total : current + 1,
                      total,
                      displayName,
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

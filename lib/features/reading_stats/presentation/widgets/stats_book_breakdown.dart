import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/stats_snapshot.dart';
import 'stats_color_palette.dart';

class StatsBookBreakdown extends StatelessWidget {
  final StatsSnapshot snapshot;
  final StatsColorPalette palette;
  const StatsBookBreakdown({
    required this.snapshot,
    required this.palette,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (var i = 0; i < snapshot.bookBreakdowns.length; i++) ...[
          if (i > 0) Divider(color: scheme.outlineVariant, height: 1),
          _BreakdownRow(
            entry: snapshot.bookBreakdowns[i],
            dotColor: palette.colorFor(snapshot.bookBreakdowns[i].bookId),
            l10n: l10n,
          ),
        ],
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final BookBreakdown entry;
  final Color dotColor;
  final AppLocalizations l10n;
  const _BreakdownRow({
    required this.entry,
    required this.dotColor,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = (entry.totalDurationMs / 60000).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: AppRadius.borderSm,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.statsBookBreakdownEntry(minutes, entry.sessionCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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

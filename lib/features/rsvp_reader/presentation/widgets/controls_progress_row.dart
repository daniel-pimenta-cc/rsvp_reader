import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/rsvp_state.dart';

class ControlsProgressRow extends StatelessWidget {
  final RsvpState state;
  final AppLocalizations l10n;
  final VoidCallback onOpenChapters;

  const ControlsProgressRow({
    required this.state,
    required this.l10n,
    required this.onOpenChapters,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final settings = state.displaySettings;
    final muted = settings.wordColor.withAlpha(140);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.progressPercent((state.progress * 100).round()),
            style: TextStyle(
              color: muted,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0.4,
            ),
          ),
          if (state.chapters.isNotEmpty)
            InkWell(
              borderRadius: AppRadius.borderSm,
              onTap: onOpenChapters,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.chapterOf(
                        state.currentChapterIndex + 1,
                        state.chapters.length,
                      ),
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.list_rounded,
                      size: 14,
                      color: settings.wordColor.withAlpha(130),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/rsvp_state.dart';

class ControlsMetaRow extends StatelessWidget {
  final RsvpState state;
  final AppLocalizations l10n;

  const ControlsMetaRow({required this.state, required this.l10n, super.key});

  @override
  Widget build(BuildContext context) {
    final settings = state.displaySettings;
    final muted = settings.wordColor.withAlpha(150);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              state.currentChapterTitle ?? '',
              style: TextStyle(
                color: settings.wordColor.withAlpha(220),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            l10n.minutesRemaining(state.estimatedMinutesRemaining),
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

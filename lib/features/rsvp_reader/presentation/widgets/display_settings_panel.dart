import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/rsvp_state.dart';
import '../providers/display_settings_provider.dart';
import '../providers/rsvp_engine_provider.dart';
import 'settings/sections/audio_section.dart';
import 'settings/sections/chrome_section.dart';
import 'settings/sections/reader_view_section.dart';
import 'settings/sections/rsvp_display_section.dart';
import 'settings/sections/speed_timing_section.dart';
import 'settings/sections/typography_section.dart';
import 'settings/settings_category.dart';

/// All display + reading settings rendered as a single Column of categorised
/// sections.
///
/// Used by [ReaderSettingsSheet] (bottom sheet), [ReaderSidePanel] (tablet
/// landscape) and [SettingsScreen] (full screen). When [bookId] is provided,
/// edits also propagate to the running engine for live preview; otherwise
/// only persisted settings update.
///
/// [compact] is the reader's in-the-moment view: only the categories that
/// visibly affect the active mode, and only the settings you'd plausibly
/// reach for mid-book. Everything else — timing multipliers, focus-line
/// plumbing, chrome toggles — stays in the full-screen page, one tap away
/// via [AllSettingsLink]. Without it the sheet was ~22 controls of which
/// most were inert in whatever mode you were reading in.
///
/// When [bookId] is set (and [compact] is false), the section that owns the
/// active reader mode floats to the top and its header chip lights up — a
/// quick visual answer to "what in here actually affects what I'm seeing
/// right now?". Full-screen Settings uses a fixed pedagogical order instead,
/// since there is no active mode.
///
/// The TTS section is suppressed entirely on platforms that don't expose any
/// TTS backend.
class DisplaySettingsPanel extends ConsumerWidget {
  final String? bookId;
  final bool compact;

  const DisplaySettingsPanel({this.bookId, this.compact = false, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);
    final activeMode =
        bookId != null ? ref.watch(readerModeProvider(bookId!)) : null;

    final ordered = compact && activeMode != null
        ? quickCategoriesFor(activeMode)
        : orderedCategoriesFor(activeMode);
    final categories = ordered.where(
      (c) => c != SettingsCategory.audio || PlatformCapabilities.supportsTts,
    );

    final children = <Widget>[];
    for (final category in categories) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.lg));
      }
      children.add(_buildSection(
        category,
        settings: settings,
        activeMode: activeMode,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildSection(
    SettingsCategory category, {
    required DisplaySettings settings,
    required ReaderMode? activeMode,
  }) {
    // In compact mode every rendered section is by definition the active
    // one, so the scope chip would say the same thing on all of them.
    final isActive = !compact && isCategoryActiveFor(category, activeMode);
    // ValueKey(category) makes Flutter element-match sections by identity
    // instead of position. When the active mode changes and the sections
    // reorder, each section's State (including the AudioSection's
    // ttsEnginesProvider subscription and the header's animation state)
    // moves with it instead of being torn down and rebuilt at a new index.
    final key = ValueKey(category);
    switch (category) {
      case SettingsCategory.speedTiming:
        return SpeedTimingSection(
            key: key,
            bookId: bookId,
            settings: settings,
            isActive: isActive,
            compact: compact);
      case SettingsCategory.rsvpDisplay:
        return RsvpDisplaySection(
            key: key,
            bookId: bookId,
            settings: settings,
            isActive: isActive,
            compact: compact);
      case SettingsCategory.audio:
        return AudioSection(
            key: key,
            bookId: bookId,
            settings: settings,
            isActive: isActive,
            compact: compact);
      case SettingsCategory.readerView:
        return ReaderViewSection(
            key: key,
            bookId: bookId,
            settings: settings,
            isActive: isActive,
            compact: compact);
      case SettingsCategory.typography:
        return TypographySection(
            key: key,
            bookId: bookId,
            settings: settings,
            isActive: isActive,
            compact: compact);
      case SettingsCategory.chrome:
        return ChromeSection(
            key: key,
            bookId: bookId,
            settings: settings,
            isActive: isActive,
            compact: compact);
    }
  }
}

/// Escape hatch out of the compact panel into the full-screen Settings page.
class AllSettingsLink extends StatelessWidget {
  final DisplaySettings settings;

  /// Runs before navigating — the bottom sheet uses it to close itself so
  /// the user doesn't come back to a stale sheet.
  final VoidCallback? onBeforeNavigate;

  const AllSettingsLink({
    required this.settings,
    this.onBeforeNavigate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      borderRadius: AppRadius.borderMd,
      onTap: () {
        onBeforeNavigate?.call();
        context.push('/settings');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(Icons.tune, size: 18, color: settings.wordColor.withAlpha(180)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l10n.settingsAllSettings,
                style: TextStyle(
                  color: settings.wordColor.withAlpha(220),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: settings.wordColor.withAlpha(140)),
          ],
        ),
      ),
    );
  }
}

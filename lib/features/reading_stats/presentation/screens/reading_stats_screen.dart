import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/stats_range.dart';
import '../../domain/entities/stats_snapshot.dart';
import '../providers/reading_stats_provider.dart';
import '../widgets/stats_book_breakdown.dart';
import '../widgets/stats_color_palette.dart';
import '../widgets/stats_empty_state.dart';
import '../widgets/stats_summary_cards.dart';
import '../widgets/stats_time_per_day_chart.dart';
import '../widgets/stats_words_per_day_chart.dart';
import '../widgets/stats_wpm_trend_chart.dart';

class ReadingStatsScreen extends ConsumerStatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  ConsumerState<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends ConsumerState<ReadingStatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 2,
          tabs: [
            Tab(text: l10n.statsTabWeekly),
            Tab(text: l10n.statsTabMonthly),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _StatsTabBody(range: StatsRange.weekly),
          _StatsTabBody(range: StatsRange.monthly),
        ],
      ),
    );
  }
}

class _StatsTabBody extends ConsumerWidget {
  final StatsRange range;
  const _StatsTabBody({required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsSnapshotProvider(range));

    return async.when(
      data: (snapshot) => snapshot.isEmpty
          ? const StatsEmptyState()
          : _StatsTabContent(snapshot: snapshot),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('$err'),
        ),
      ),
    );
  }
}

class _StatsTabContent extends StatelessWidget {
  final StatsSnapshot snapshot;
  const _StatsTabContent({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final orderedBookIds =
        snapshot.bookBreakdowns.map((b) => b.bookId).toList(growable: false);
    final palette = StatsColorPalette.forBooks(
      orderedBookIds: orderedBookIds,
      scheme: scheme,
    );

    final showRecapCta = snapshot.range == StatsRange.monthly;
    final recapCta = showRecapCta
        ? Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: FilledButton.tonalIcon(
              onPressed: () => context.push('/stats/recap'),
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.recapGenerateCta),
            ),
          )
        : const SizedBox.shrink();

    final summary = StatsSummaryCards(snapshot: snapshot);
    final wordsChart = SectionCard(
      header: l10n.statsChartWordsPerDay,
      child: StatsWordsPerDayChart(snapshot: snapshot, palette: palette),
    );
    final timeChart = SectionCard(
      header: l10n.statsChartTimePerDay,
      child: StatsTimePerDayChart(snapshot: snapshot),
    );
    final wpmChart = SectionCard(
      header: l10n.statsChartWpmTrend,
      child: StatsWpmTrendChart(snapshot: snapshot),
    );
    final breakdown = SectionCard(
      header: l10n.statsBookBreakdownTitle,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
      child: StatsBookBreakdown(snapshot: snapshot, palette: palette),
    );

    final wideLayout = context.isTablet && context.isLandscape;
    if (wideLayout) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  recapCta,
                  summary,
                  const SizedBox(height: AppSpacing.lg),
                  breakdown,
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: ListView(
                children: [
                  wordsChart,
                  const SizedBox(height: AppSpacing.lg),
                  timeChart,
                  const SizedBox(height: AppSpacing.lg),
                  wpmChart,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        recapCta,
        summary,
        const SizedBox(height: AppSpacing.lg),
        wordsChart,
        const SizedBox(height: AppSpacing.lg),
        timeChart,
        const SizedBox(height: AppSpacing.lg),
        wpmChart,
        const SizedBox(height: AppSpacing.lg),
        breakdown,
      ],
    );
  }
}

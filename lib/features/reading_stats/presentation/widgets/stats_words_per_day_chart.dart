import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/stats_snapshot.dart';
import 'stats_color_palette.dart';

/// Stacked bar chart: one bar per day, colored slices per book.
class StatsWordsPerDayChart extends StatelessWidget {
  final StatsSnapshot snapshot;
  final StatsColorPalette palette;
  const StatsWordsPerDayChart({
    required this.snapshot,
    required this.palette,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = _computeMaxY(snapshot);

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barGroups: [
            for (var i = 0; i < snapshot.dailyBuckets.length; i++)
              _buildGroup(i, snapshot.dailyBuckets[i], scheme),
          ],
          titlesData: _titlesData(context, snapshot, scheme),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, groupIdx, rod, rodIdx) => BarTooltipItem(
                '${rod.toY.round()}',
                TextStyle(color: scheme.onInverseSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BarChartGroupData _buildGroup(
    int x,
    DailyBucket bucket,
    ColorScheme scheme,
  ) {
    if (bucket.isEmpty) {
      return BarChartGroupData(x: x, barRods: [
        BarChartRodData(toY: 0, width: 0),
      ]);
    }

    // Sort slices: distinct-palette books first (biggest first), other last.
    final sortedSlices = [...bucket.perBook]
      ..sort((a, b) {
        final distA = palette.isDistinct(a.bookId) ? 0 : 1;
        final distB = palette.isDistinct(b.bookId) ? 0 : 1;
        if (distA != distB) return distA.compareTo(distB);
        return b.wordsRead.compareTo(a.wordsRead);
      });

    double cursor = 0;
    final stack = <BarChartRodStackItem>[];
    for (final slice in sortedSlices) {
      final from = cursor;
      final to = cursor + slice.wordsRead;
      stack.add(BarChartRodStackItem(from, to, palette.colorFor(slice.bookId)));
      cursor = to;
    }

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: cursor,
          width: 14,
          borderRadius: BorderRadius.circular(3),
          rodStackItems: stack,
          color: scheme.primary,
        ),
      ],
    );
  }

  double _computeMaxY(StatsSnapshot snap) {
    final max = snap.dailyBuckets.fold<int>(
      0,
      (acc, b) => b.totalWords > acc ? b.totalWords : acc,
    );
    if (max == 0) return 10;
    // Round up to a nice-ish number for grid lines.
    final magnitude = _niceStep(max.toDouble());
    return (max / magnitude).ceil() * magnitude;
  }

  double _niceStep(double max) {
    if (max <= 50) return 10;
    if (max <= 200) return 50;
    if (max <= 1000) return 200;
    if (max <= 5000) return 1000;
    return 5000;
  }

  FlTitlesData _titlesData(
    BuildContext context,
    StatsSnapshot snap,
    ColorScheme scheme,
  ) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          getTitlesWidget: (value, meta) {
            if (value == meta.max) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                _formatAxis(value),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                textAlign: TextAlign.right,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= snap.dailyBuckets.length) {
              return const SizedBox.shrink();
            }
            // Show labels for first, last, and a few in between.
            final n = snap.dailyBuckets.length;
            final step = n <= 7 ? 1 : (n ~/ 5);
            if (idx != 0 && idx != n - 1 && idx % step != 0) {
              return const SizedBox.shrink();
            }
            final day = snap.dailyBuckets[idx].day;
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${day.day}/${day.month}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatAxis(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return v.round().toString();
  }
}

/// Time window for the stats screen. `weekly` shows the last 7 days
/// (today inclusive), `monthly` the last 30.
enum StatsRange {
  weekly(days: 7),
  monthly(days: 30);

  final int days;
  const StatsRange({required this.days});

  /// Returns the [from, to) window, snapped to local-date midnights.
  /// `to` is the start of tomorrow so sessions from today are included.
  ({DateTime from, DateTime to}) window({DateTime? now}) {
    final n = now ?? DateTime.now();
    final tomorrow = DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
    final from = tomorrow.subtract(Duration(days: days));
    return (from: from, to: tomorrow);
  }
}

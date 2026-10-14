import 'farmer_analytics.dart';

class AnalyticsPeriod {
  const AnalyticsPeriod(this.from, this.to, this.count);
  final DateTime from;
  final DateTime to;
  final int count;
}

List<AnalyticsPeriod> analyticsPeriods(List<AnalyticsDay> days) {
  if (days.isEmpty) return const [];
  // Presentation-only grouping: at most six labelled bars, with no omitted days.
  final size = (days.length / 6).ceil();
  final result = <AnalyticsPeriod>[];
  for (var start = 0; start < days.length; start += size) {
    final end = (start + size).clamp(0, days.length);
    result.add(
      AnalyticsPeriod(
        days[start].date,
        days[end - 1].date,
        days.sublist(start, end).fold(0, (sum, item) => sum + item.count),
      ),
    );
  }
  return List.unmodifiable(result);
}

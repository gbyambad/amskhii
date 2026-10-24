import 'package:flutter/foundation.dart';

import 'app_usage.dart';

@immutable
class DaySummary {
  const DaySummary({required this.date, required this.screenTime, required this.pickups});

  final DateTime date;
  final Duration screenTime;
  final int pickups;
}

@immutable
class AppWeekUsage {
  const AppWeekUsage({
    required this.appId,
    required this.name,
    required this.screenTime,
    required this.change,
    this.icon,
  });

  final String appId;
  final String name;
  final Duration screenTime;

  /// Ratio against the previous week: `0.08` is 8% more; `null` when the
  /// app was not used then or that history is gone.
  final double? change;

  final Uint8List? icon;
}

/// The last seven days, oldest first; the last entry is today.
@immutable
class WeekReport {
  const WeekReport({
    required this.days,
    required this.previousDailyAverage,
    required this.byCategory,
    required this.topApps,
  });

  final List<DaySummary> days;

  /// `null` when the device no longer keeps last week's history.
  final Duration? previousDailyAverage;
  final Map<AppCategory, Duration> byCategory;
  final List<AppWeekUsage> topApps;

  Duration get total => days.fold(Duration.zero, (sum, d) => sum + d.screenTime);

  /// Days with any use; a fresh install has no history for the others.
  Iterable<DaySummary> get _daysWithData => days.where((d) => d.screenTime > Duration.zero || d.pickups > 0);

  Duration get dailyAverage {
    final count = _daysWithData.length;
    return count == 0 ? Duration.zero : total ~/ count;
  }

  /// Ratio against the previous week's daily average, if known.
  double? get changeVsPrevious {
    final previous = previousDailyAverage;
    if (previous == null || previous == Duration.zero) return null;
    return dailyAverage.inSeconds / previous.inSeconds - 1;
  }

  int get averagePickups {
    final withData = _daysWithData.toList();
    if (withData.isEmpty) return 0;
    return (withData.fold(0, (sum, d) => sum + d.pickups) / withData.length).round();
  }

  DaySummary get mostPickupsDay => days.reduce((a, b) => b.pickups > a.pickups ? b : a);

  /// Consecutive days, counting back from today, that stayed within [limit].
  int streakWithin(Duration limit) {
    var streak = 0;
    for (final day in days.reversed) {
      if (day.screenTime > limit) break;
      streak++;
    }
    return streak;
  }
}

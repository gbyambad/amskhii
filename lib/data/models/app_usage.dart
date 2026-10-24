import 'package:flutter/foundation.dart';

enum AppCategory { social, video, chat, other }

/// One app's usage for a single day.
@immutable
class AppUsage {
  const AppUsage({
    required this.appId,
    required this.name,
    required this.category,
    required this.screenTime,
    required this.opens,
    required this.notifications,
    required this.dataBytes,
    this.icon,
  });

  /// Android package name / iOS bundle id.
  final String appId;
  final String name;
  final AppCategory category;
  final Duration screenTime;
  final int opens;
  final int notifications;
  final int dataBytes;

  /// Launcher icon as PNG bytes, when the platform provides one.
  final Uint8List? icon;
}

/// Today's usage up to [asOf], bucketed by hour of day.
@immutable
class DayUsage {
  const DayUsage({
    required this.asOf,
    required this.hourlyScreenTime,
    required this.hourlyPickups,
    required this.apps,
    required this.previousDayTotal,
    this.lastPickupAt,
  });

  final DateTime asOf;

  /// 24 entries, index = hour of day.
  final List<Duration> hourlyScreenTime;

  /// 24 entries, index = hour of day.
  final List<int> hourlyPickups;
  final List<AppUsage> apps;
  final Duration previousDayTotal;
  final DateTime? lastPickupAt;

  Duration get total => hourlyScreenTime.fold(Duration.zero, (a, b) => a + b);

  int get pickups => hourlyPickups.fold(0, (a, b) => a + b);

  /// Hours after this one have not happened yet.
  int get currentHour => asOf.hour;

  /// Pickups in `[startHour, endHour)`.
  int pickupsBetween(int startHour, int endHour) =>
      hourlyPickups.sublist(startHour, endHour).fold(0, (a, b) => a + b);

  int get peakUsageHour => _indexOfMax(hourlyScreenTime.map((d) => d.inSeconds).toList());

  int get peakPickupHour => _indexOfMax(hourlyPickups);

  Duration screenTimeIn(AppCategory category) => apps
      .where((a) => a.category == category)
      .fold(Duration.zero, (sum, a) => sum + a.screenTime);

  static int _indexOfMax(List<int> values) {
    var best = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return best;
  }
}

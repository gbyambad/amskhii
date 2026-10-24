import 'package:flutter/services.dart';

import '../models/app_usage.dart';
import '../models/week_report.dart';

/// Dart end of the `amskhii/screen_time` channel (Android: `ScreenTimeChannel.kt`,
/// iOS: `ScreenTimeChannel.swift`, which only answers the two access calls).
///
/// Times are epoch milliseconds, durations are milliseconds.
///
/// `getToday` →
/// ```
/// {asOf, hourlyScreenTimeMs: [24], hourlyPickups: [24], previousDayTotalMs,
///  lastPickupAt?, apps: [{appId, name, category, screenTimeMs, opens,
///  notifications, dataBytes, icon?: PNG bytes}]}
/// ```
/// `getWeek` →
/// ```
/// {days: [7 × {date, screenTimeMs, pickups}] oldest first,
///  previousDailyAverageMs?, byCategoryMs: {category: ms},
///  topApps: [{appId, name, screenTimeMs, change?, icon?}]}
/// ```
class ScreenTimeChannel {
  const ScreenTimeChannel();

  static const _channel = MethodChannel('amskhii/screen_time');

  Future<bool> hasUsageAccess() async => await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  /// Android opens Settings; iOS shows the Screen Time prompt and completes
  /// once answered, throwing a [PlatformException] when declined.
  Future<void> openUsageAccessSettings() => _channel.invokeMethod<void>('openUsageAccessSettings');

  Future<DayUsage> today() async {
    final map = (await _channel.invokeMapMethod<String, Object?>('getToday'))!;
    return DayUsage(
      asOf: _time(map['asOf'])!,
      hourlyScreenTime: [for (final ms in map['hourlyScreenTimeMs']! as List) _duration(ms)],
      hourlyPickups: (map['hourlyPickups']! as List).cast<int>(),
      previousDayTotal: _duration(map['previousDayTotalMs']),
      lastPickupAt: _time(map['lastPickupAt']),
      apps: [
        for (final raw in map['apps']! as List)
          if (raw case final Map<Object?, Object?> app)
            AppUsage(
              appId: app['appId']! as String,
              name: app['name']! as String,
              category: _category(app['category']),
              screenTime: _duration(app['screenTimeMs']),
              opens: app['opens']! as int,
              notifications: app['notifications']! as int,
              dataBytes: app['dataBytes']! as int,
              icon: app['icon'] as Uint8List?,
            ),
      ],
    );
  }

  Future<WeekReport> week() async {
    final map = (await _channel.invokeMapMethod<String, Object?>('getWeek'))!;
    final previous = map['previousDailyAverageMs'] as int?;
    return WeekReport(
      days: [
        for (final raw in map['days']! as List)
          if (raw case final Map<Object?, Object?> day)
            DaySummary(
              date: _time(day['date'])!,
              screenTime: _duration(day['screenTimeMs']),
              pickups: day['pickups']! as int,
            ),
      ],
      previousDailyAverage: previous == null ? null : Duration(milliseconds: previous),
      byCategory: {
        for (final e in (map['byCategoryMs']! as Map).entries) _category(e.key): _duration(e.value),
      },
      topApps: [
        for (final raw in map['topApps']! as List)
          if (raw case final Map<Object?, Object?> app)
            AppWeekUsage(
              appId: app['appId']! as String,
              name: app['name']! as String,
              screenTime: _duration(app['screenTimeMs']),
              change: (app['change'] as num?)?.toDouble(),
              icon: app['icon'] as Uint8List?,
            ),
      ],
    );
  }

  static Duration _duration(Object? ms) => Duration(milliseconds: ms! as int);

  static DateTime? _time(Object? ms) => ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);

  static AppCategory _category(Object? name) => AppCategory.values.asNameMap()[name] ?? AppCategory.other;
}

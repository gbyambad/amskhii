import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/app_selection.dart';
import '../models/app_usage.dart';
import '../models/block_schedule.dart';
import '../models/limit_rule.dart';
import '../models/week_report.dart';

/// Dart end of the `amskhii/screen_time` channel (Android: `ScreenTimeChannel.kt`,
/// iOS: `ScreenTimeChannel.swift`, which answers the usage access calls and the
/// iOS-only calls at the end of this class).
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

  /// Android only: whether `BlockingService` is on in Accessibility settings.
  Future<bool> hasBlockingAccess() async => await _channel.invokeMethod<bool>('hasBlockingAccess') ?? false;

  /// Android only: opens Accessibility settings.
  Future<void> openBlockingSettings() => _channel.invokeMethod<void>('openBlockingSettings');

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

  /// iOS only: `{id, apps, categories, sites}` counts, or null when cancelled.
  Future<AppSelection?> pickApps(String id) async {
    final map = await _channel.invokeMapMethod<String, Object?>('pickApps', {'id': id});
    return map == null ? null : _selection(map);
  }

  /// iOS only.
  Future<List<AppSelection>> selections() async => [
        for (final raw in await _channel.invokeListMethod<Object?>('getSelections') ?? const [])
          if (raw case final Map<Object?, Object?> map) _selection(map),
      ];

  /// iOS only.
  Future<void> deleteSelection(String id) => _channel.invokeMethod<void>('deleteSelection', {'id': id});

  /// iOS only: hands the saved rules to Screen Time, which shields apps and
  /// watches limits and schedules even while Amskhii is closed. Same JSON as
  /// `LocalSettingsStore` saves.
  Future<void> applyRules(ScreenTimeRules rules, List<BlockSchedule> schedules) =>
      _channel.invokeMethod<void>('applyRules', {
        'rules': jsonEncode(rules.toJson()),
        'schedules': jsonEncode([for (final s in schedules) s.toJson()]),
      });

  static AppSelection _selection(Map<Object?, Object?> map) => AppSelection(
        id: map['id']! as String,
        apps: map['apps'] as int? ?? 0,
        categories: map['categories'] as int? ?? 0,
        sites: map['sites'] as int? ?? 0,
      );

  static Duration _duration(Object? ms) => Duration(milliseconds: ms! as int);

  static DateTime? _time(Object? ms) => ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);

  static AppCategory _category(Object? name) => AppCategory.values.asNameMap()[name] ?? AppCategory.other;
}

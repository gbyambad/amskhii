import 'package:flutter/foundation.dart';

enum ScheduleKind { bedtime, work, family, custom }

/// Blocks apps on a weekly schedule, e.g. bedtime 23:00–07:00.
@immutable
class BlockSchedule {
  const BlockSchedule({
    required this.id,
    required this.name,
    required this.kind,
    required this.startMinute,
    required this.endMinute,
    required this.weekdays,
    this.enabled = true,
    this.appIds,
  });

  static const _day = 24 * 60;
  static const _week = 7 * _day;

  final String id;
  final String name;
  final ScheduleKind kind;

  /// Minutes since midnight; [endMinute] < [startMinute] crosses midnight.
  final int startMinute;
  final int endMinute;

  /// [DateTime.monday]..[DateTime.sunday].
  final Set<int> weekdays;
  final bool enabled;

  /// Apps to block; `null` blocks everything except calls and messages.
  /// On iOS this holds one `AppSelection.forSchedule` id instead.
  final Set<String>? appIds;

  bool get blocksAllApps => appIds == null;

  bool get crossesMidnight => endMinute < startMinute;

  Duration get length => Duration(minutes: (endMinute - startMinute) % _day);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'startMinute': startMinute,
        'endMinute': endMinute,
        'weekdays': (weekdays.toList()..sort()),
        'enabled': enabled,
        'appIds': appIds?.toList(),
      };

  factory BlockSchedule.fromJson(Map<String, Object?> json) => BlockSchedule(
        id: json['id']! as String,
        name: json['name']! as String,
        kind: ScheduleKind.values.asNameMap()[json['kind']] ?? ScheduleKind.custom,
        startMinute: json['startMinute']! as int,
        endMinute: json['endMinute']! as int,
        weekdays: {...(json['weekdays']! as List).cast<int>()},
        enabled: json['enabled'] as bool? ?? true,
        appIds: (json['appIds'] as List?)?.cast<String>().toSet(),
      );

  /// Whether [next] blocks less than this: off, fewer apps, or any minute of
  /// the week no longer covered. The changes the PIN guards.
  bool loosenedBy(BlockSchedule next) {
    if (!enabled) return false;
    if (!next.enabled) return true;
    final apps = appIds;
    final nextApps = next.appIds;
    if (apps == null ? nextApps != null : nextApps != null && !nextApps.containsAll(apps)) return true;
    return !next._minutesOfWeek.containsAll(_minutesOfWeek);
  }

  /// Every minute this blocks, counted from Monday 00:00.
  Set<int> get _minutesOfWeek => {
        for (final day in weekdays)
          for (var m = 0; m < length.inMinutes; m++) ((day - 1) * _day + startMinute + m) % _week,
      };

  BlockSchedule copyWith({bool? enabled}) => _copy(enabled: enabled);

  /// Returns this unchanged if the shift would make start and end meet.
  BlockSchedule shiftStart(int minutes) {
    final next = (startMinute + minutes) % _day;
    return next == endMinute ? this : _copy(startMinute: next);
  }

  BlockSchedule shiftEnd(int minutes) {
    final next = (endMinute + minutes) % _day;
    return next == startMinute ? this : _copy(endMinute: next);
  }

  BlockSchedule toggleWeekday(int weekday) => _copy(
        weekdays: weekdays.contains(weekday) ? ({...weekdays}..remove(weekday)) : {...weekdays, weekday},
      );

  BlockSchedule withAppIds(Set<String> appIds) => _copy(appIds: appIds);

  BlockSchedule toggleApp(String appId) {
    final current = appIds ?? const <String>{};
    return _copy(appIds: current.contains(appId) ? ({...current}..remove(appId)) : {...current, appId});
  }

  BlockSchedule _copy({
    int? startMinute,
    int? endMinute,
    Set<int>? weekdays,
    bool? enabled,
    Set<String>? appIds,
  }) =>
      BlockSchedule(
        id: id,
        name: name,
        kind: kind,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
        weekdays: weekdays ?? this.weekdays,
        enabled: enabled ?? this.enabled,
        appIds: appIds ?? this.appIds,
      );
}

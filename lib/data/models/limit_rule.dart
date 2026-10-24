import 'package:flutter/foundation.dart';

import 'app_usage.dart';

/// What happens when a daily limit runs out.
enum LimitAction { warn, block }

/// A daily limit and/or a hard block on one app or category.
@immutable
class LimitRule {
  const LimitRule({this.dailyLimit, this.blocked = false, this.onLimit = LimitAction.block});

  static const none = LimitRule();
  static const maxDailyLimit = Duration(hours: 12);

  /// Remaining time at or below this shows as "almost out".
  static const nearThreshold = Duration(minutes: 10);

  /// `null` means unlimited.
  final Duration? dailyLimit;
  final bool blocked;
  final LimitAction onLimit;

  LimitRule copyWith({ValueGetter<Duration?>? dailyLimit, bool? blocked, LimitAction? onLimit}) => LimitRule(
        dailyLimit: dailyLimit != null ? dailyLimit() : this.dailyLimit,
        blocked: blocked ?? this.blocked,
        onLimit: onLimit ?? this.onLimit,
      );

  /// Moves the limit by [delta]; dropping to zero removes it.
  LimitRule stepLimit(Duration delta) {
    final next = (dailyLimit ?? Duration.zero) + delta;
    if (next <= Duration.zero) return copyWith(dailyLimit: () => null);
    return copyWith(dailyLimit: () => next > maxDailyLimit ? maxDailyLimit : next);
  }

  /// Time left today, or `null` when there is no limit.
  Duration? remaining(Duration used) {
    final limit = dailyLimit;
    if (limit == null) return null;
    final left = limit - used;
    return left.isNegative ? Duration.zero : left;
  }

  /// Share of the limit used, clamped to 1.
  double? usedFraction(Duration used) {
    final limit = dailyLimit;
    if (limit == null) return null;
    return (used.inSeconds / limit.inSeconds).clamp(0.0, 1.0);
  }

  bool isNear(Duration used) {
    final left = remaining(used);
    return !blocked && left != null && left <= nearThreshold;
  }

  Map<String, Object?> toJson() => {
        'limitMinutes': dailyLimit?.inMinutes,
        'blocked': blocked,
        'onLimit': onLimit.name,
      };

  factory LimitRule.fromJson(Map<String, Object?> json) {
    final minutes = json['limitMinutes'] as int?;
    return LimitRule(
      dailyLimit: minutes == null ? null : Duration(minutes: minutes),
      blocked: json['blocked'] as bool? ?? false,
      onLimit: LimitAction.values.asNameMap()[json['onLimit']] ?? LimitAction.block,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LimitRule && other.dailyLimit == dailyLimit && other.blocked == blocked && other.onLimit == onLimit;

  @override
  int get hashCode => Object.hash(dailyLimit, blocked, onLimit);
}

/// Everything the user has configured on the Limits tab.
@immutable
class ScreenTimeRules {
  const ScreenTimeRules({
    this.apps = const {},
    this.categories = const {},
    this.totalDailyLimit,
    this.pinEnabled = false,
  });

  final Map<String, LimitRule> apps;
  final Map<AppCategory, LimitRule> categories;

  /// Cap on all screen time per day; `null` means none.
  final Duration? totalDailyLimit;

  /// Ask for the PIN before limits are loosened.
  final bool pinEnabled;

  LimitRule forApp(String appId) => apps[appId] ?? LimitRule.none;

  LimitRule forCategory(AppCategory category) => categories[category] ?? LimitRule.none;

  ScreenTimeRules withApp(String appId, LimitRule rule) => _copy(apps: {...apps, appId: rule});

  ScreenTimeRules withCategory(AppCategory category, LimitRule rule) =>
      _copy(categories: {...categories, category: rule});

  Map<String, Object?> toJson() => {
        'apps': {for (final e in apps.entries) e.key: e.value.toJson()},
        'categories': {for (final e in categories.entries) e.key.name: e.value.toJson()},
        'totalLimitMinutes': totalDailyLimit?.inMinutes,
        'pinEnabled': pinEnabled,
      };

  factory ScreenTimeRules.fromJson(Map<String, Object?> json) {
    final apps = (json['apps'] as Map<String, Object?>?) ?? const {};
    final categories = (json['categories'] as Map<String, Object?>?) ?? const {};
    final categoryByName = AppCategory.values.asNameMap();
    final totalMinutes = json['totalLimitMinutes'] as int?;
    return ScreenTimeRules(
      apps: {for (final e in apps.entries) e.key: LimitRule.fromJson(e.value! as Map<String, Object?>)},
      categories: {
        for (final e in categories.entries)
          ?categoryByName[e.key]: LimitRule.fromJson(e.value! as Map<String, Object?>),
      },
      totalDailyLimit: totalMinutes == null ? null : Duration(minutes: totalMinutes),
      pinEnabled: json['pinEnabled'] as bool? ?? false,
    );
  }

  ScreenTimeRules copyWith({ValueGetter<Duration?>? totalDailyLimit, bool? pinEnabled}) => _copy(
        totalDailyLimit: totalDailyLimit,
        pinEnabled: pinEnabled,
      );

  ScreenTimeRules _copy({
    Map<String, LimitRule>? apps,
    Map<AppCategory, LimitRule>? categories,
    ValueGetter<Duration?>? totalDailyLimit,
    bool? pinEnabled,
  }) =>
      ScreenTimeRules(
        apps: apps ?? this.apps,
        categories: categories ?? this.categories,
        totalDailyLimit: totalDailyLimit != null ? totalDailyLimit() : this.totalDailyLimit,
        pinEnabled: pinEnabled ?? this.pinEnabled,
      );
}

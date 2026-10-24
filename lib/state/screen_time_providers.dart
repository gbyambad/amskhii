import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_usage.dart';
import '../data/models/block_schedule.dart';
import '../data/models/limit_rule.dart';
import '../data/models/week_report.dart';
import '../data/screen_time_repository.dart';

/// Set in `main`; tests override it with the fake in `test/support`.
final screenTimeRepositoryProvider = Provider<ScreenTimeRepository>(
  (ref) => throw UnimplementedError('Override screenTimeRepositoryProvider'),
);

/// True on iOS, where usage never reaches Dart: Apple shows it only inside the
/// Screen Time report extension, so the usage screens embed its native view
/// and access is granted in a system prompt rather than Settings.
final nativeUsageReportsProvider = Provider<bool>((ref) => false);

/// Re-read on app resume, since the user grants access in system Settings.
final usageAccessProvider = FutureProvider<bool>(
  (ref) => ref.watch(screenTimeRepositoryProvider).hasUsageAccess(),
);

final todayUsageProvider = FutureProvider<DayUsage>(
  (ref) => ref.watch(screenTimeRepositoryProvider).loadToday(),
);

final weekReportProvider = FutureProvider<WeekReport>(
  (ref) => ref.watch(screenTimeRepositoryProvider).loadWeek(),
);

final rulesProvider = AsyncNotifierProvider<RulesNotifier, ScreenTimeRules>(RulesNotifier.new);

final schedulesProvider = AsyncNotifierProvider<SchedulesNotifier, List<BlockSchedule>>(SchedulesNotifier.new);

class RulesNotifier extends AsyncNotifier<ScreenTimeRules> {
  static const _minTotal = Duration(minutes: 30);
  static const _maxTotal = Duration(hours: 16);

  @override
  Future<ScreenTimeRules> build() => ref.watch(screenTimeRepositoryProvider).loadRules();

  Future<void> setAppRule(String appId, LimitRule rule) => _update((r) => r.withApp(appId, rule));

  Future<void> toggleAppBlocked(String appId) => _update((r) {
        final rule = r.forApp(appId);
        return r.withApp(appId, rule.copyWith(blocked: !rule.blocked));
      });

  Future<void> stepAppLimit(String appId, Duration delta) =>
      _update((r) => r.withApp(appId, r.forApp(appId).stepLimit(delta)));

  Future<void> toggleCategoryBlocked(AppCategory category) => _update((r) {
        final rule = r.forCategory(category);
        return r.withCategory(category, rule.copyWith(blocked: !rule.blocked));
      });

  Future<void> stepCategoryLimit(AppCategory category, Duration delta) =>
      _update((r) => r.withCategory(category, r.forCategory(category).stepLimit(delta)));

  Future<void> stepTotalDailyLimit(Duration delta) => _update((r) {
        var next = (r.totalDailyLimit ?? const Duration(hours: 4)) + delta;
        if (next < _minTotal) next = _minTotal;
        if (next > _maxTotal) next = _maxTotal;
        return r.copyWith(totalDailyLimit: () => next);
      });

  Future<void> setPinEnabled(bool enabled) => _update((r) => r.copyWith(pinEnabled: enabled));

  Future<void> _update(ScreenTimeRules Function(ScreenTimeRules) change) async {
    final next = change(await future);
    state = AsyncData(next);
    await ref.read(screenTimeRepositoryProvider).saveRules(next);
  }
}

class SchedulesNotifier extends AsyncNotifier<List<BlockSchedule>> {
  @override
  Future<List<BlockSchedule>> build() => ref.watch(screenTimeRepositoryProvider).loadSchedules();

  Future<void> replace(BlockSchedule schedule) =>
      _update((list) => [for (final s in list) s.id == schedule.id ? schedule : s]);

  Future<void> add(BlockSchedule schedule) => _update((list) => [...list, schedule]);

  Future<void> _update(List<BlockSchedule> Function(List<BlockSchedule>) change) async {
    final next = change(await future);
    state = AsyncData(next);
    await ref.read(screenTimeRepositoryProvider).saveSchedules(next);
  }
}

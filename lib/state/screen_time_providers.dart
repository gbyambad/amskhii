import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_selection.dart';
import '../data/models/app_usage.dart';
import '../data/models/block_schedule.dart';
import '../data/models/limit_rule.dart';
import '../data/models/week_report.dart';
import '../data/screen_time_repository.dart';
import 'pin_gate.dart';

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

/// Re-read on app resume, since the user turns blocking on in Settings.
final blockingAccessProvider = FutureProvider<bool>(
  (ref) => ref.watch(screenTimeRepositoryProvider).hasBlockingAccess(),
);

/// True when rules would be saved but not enforced: Android with the blocking
/// service off. iOS never asks, since it doesn't enforce limits yet.
final blockingOffProvider = Provider<bool>(
  (ref) => !ref.watch(nativeUsageReportsProvider) && ref.watch(blockingAccessProvider).value == false,
);

final todayUsageProvider = FutureProvider<DayUsage>(
  (ref) => ref.watch(screenTimeRepositoryProvider).loadToday(),
);

final weekReportProvider = FutureProvider<WeekReport>(
  (ref) => ref.watch(screenTimeRepositoryProvider).loadWeek(),
);

final rulesProvider = AsyncNotifierProvider<RulesNotifier, ScreenTimeRules>(RulesNotifier.new);

/// iOS: what the user picked in Apple's app picker.
final selectionsProvider = AsyncNotifierProvider<SelectionsNotifier, List<AppSelection>>(SelectionsNotifier.new);

final schedulesProvider = AsyncNotifierProvider<SchedulesNotifier, List<BlockSchedule>>(SchedulesNotifier.new);

class RulesNotifier extends AsyncNotifier<ScreenTimeRules> {
  static const _minTotal = Duration(minutes: 30);
  static const _maxTotal = Duration(hours: 16);

  @override
  Future<ScreenTimeRules> build() => ref.watch(screenTimeRepositoryProvider).loadRules();

  Future<bool> setAppRule(String appId, LimitRule rule) => _update((r) => r.withApp(appId, rule));

  Future<bool> removeApp(String appId) => _update((r) => r.withoutApp(appId));

  Future<bool> toggleAppBlocked(String appId) => _update((r) {
        final rule = r.forApp(appId);
        return r.withApp(appId, rule.copyWith(blocked: !rule.blocked));
      });

  Future<bool> stepAppLimit(String appId, Duration delta) =>
      _update((r) => r.withApp(appId, r.forApp(appId).stepLimit(delta)));

  Future<bool> toggleCategoryBlocked(AppCategory category) => _update((r) {
        final rule = r.forCategory(category);
        return r.withCategory(category, rule.copyWith(blocked: !rule.blocked));
      });

  Future<bool> stepCategoryLimit(AppCategory category, Duration delta) =>
      _update((r) => r.withCategory(category, r.forCategory(category).stepLimit(delta)));

  Future<bool> stepTotalDailyLimit(Duration delta) => _update((r) {
        var next = (r.totalDailyLimit ?? const Duration(hours: 4)) + delta;
        if (next < _minTotal) next = _minTotal;
        if (next > _maxTotal) next = _maxTotal;
        return r.copyWith(totalDailyLimit: () => next);
      });

  Future<bool> setPinEnabled(bool enabled) =>
      _update((r) => r.copyWith(pinEnabled: enabled), reason: 'PIN хамгаалалтыг унтраахын тулд');

  /// Applies [change] and returns whether it went ahead: one that loosens
  /// the rules first passes the [PinGate].
  Future<bool> _update(ScreenTimeRules Function(ScreenTimeRules) change, {String reason = _loosenReason}) async {
    final current = await future;
    final next = change(current);
    if (current.loosenedBy(next) && !await ref.read(pinGateProvider).unlock(reason)) return false;
    state = AsyncData(next);
    await ref.read(screenTimeRepositoryProvider).saveRules(next);
    return true;
  }

  static const _loosenReason = 'Хязгаарыг сулруулахын тулд';
}

class SchedulesNotifier extends AsyncNotifier<List<BlockSchedule>> {
  @override
  Future<List<BlockSchedule>> build() => ref.watch(screenTimeRepositoryProvider).loadSchedules();

  Future<bool> replace(BlockSchedule schedule) =>
      _update((list) => [for (final s in list) s.id == schedule.id ? schedule : s]);

  Future<bool> add(BlockSchedule schedule) => _update((list) => [...list, schedule]);

  /// As `RulesNotifier._update`: a change that blocks less passes the [PinGate].
  Future<bool> _update(List<BlockSchedule> Function(List<BlockSchedule>) change) async {
    final current = await future;
    final next = change(current);
    final byId = {for (final s in next) s.id: s};
    final loosened = current.any((s) {
      final after = byId[s.id];
      return after == null ? s.enabled : s.loosenedBy(after);
    });
    if (loosened && !await ref.read(pinGateProvider).unlock('Хуваарийг сулруулахын тулд')) return false;
    state = AsyncData(next);
    await ref.read(screenTimeRepositoryProvider).saveSchedules(next);
    return true;
  }
}

class SelectionsNotifier extends AsyncNotifier<List<AppSelection>> {
  @override
  Future<List<AppSelection>> build() => ref.watch(screenTimeRepositoryProvider).loadSelections();

  /// Opens Apple's picker for [id]. An empty pick is dropped; `null` means
  /// cancelled. Changing an earlier pick may drop apps, so it passes the
  /// [PinGate] first; Dart can't see which apps it holds.
  Future<AppSelection?> pick(String id) async {
    final list = await future;
    if (list.any((s) => s.id == id) && !await ref.read(pinGateProvider).unlock('Сонгосон аппуудыг өөрчлөхийн тулд')) {
      return null;
    }
    final picked = await ref.read(screenTimeRepositoryProvider).pickApps(id);
    if (picked == null) return null;
    if (picked.isEmpty) {
      await remove(id);
      return picked;
    }
    final latest = await future;
    final known = latest.any((s) => s.id == id);
    state = AsyncData(known ? [for (final s in latest) s.id == id ? picked : s] : [...latest, picked]);
    return picked;
  }

  Future<void> remove(String id) async {
    await ref.read(screenTimeRepositoryProvider).deleteSelection(id);
    state = AsyncData([for (final s in await future) if (s.id != id) s]);
  }
}

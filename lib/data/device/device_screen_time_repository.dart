import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_selection.dart';
import '../models/app_usage.dart';
import '../models/block_schedule.dart';
import '../models/limit_rule.dart';
import '../models/week_report.dart';
import '../screen_time_repository.dart';
import 'local_settings_store.dart';
import 'screen_time_channel.dart';

/// Real usage from the OS; limits and schedules saved on the phone.
///
/// On iOS only the access calls work for usage (see `nativeUsageReportsProvider`),
/// and every save also goes to Screen Time, which enforces it. Android's
/// blocking service reads the saved rules itself.
class DeviceScreenTimeRepository implements ScreenTimeRepository {
  DeviceScreenTimeRepository({required this.store, this.channel = const ScreenTimeChannel(), this.ios = false});

  final LocalSettingsStore store;
  final ScreenTimeChannel channel;
  final bool ios;

  /// First-run schedule, off until the user turns it on.
  static const _defaultSchedules = [
    BlockSchedule(
      id: 'bedtime',
      name: 'Амрах цаг',
      kind: ScheduleKind.bedtime,
      startMinute: 23 * 60,
      endMinute: 7 * 60,
      weekdays: {1, 2, 3, 4, 5, 6, 7},
      enabled: false,
    ),
  ];

  @override
  Future<bool> hasUsageAccess() => channel.hasUsageAccess();

  @override
  Future<void> requestUsageAccess() => channel.openUsageAccessSettings();

  @override
  Future<bool> hasBlockingAccess() => channel.hasBlockingAccess();

  @override
  Future<void> requestBlockingAccess() => channel.openBlockingSettings();

  @override
  Future<List<AppSelection>> loadSelections() async => ios ? channel.selections() : const [];

  @override
  Future<AppSelection?> pickApps(String id) => channel.pickApps(id);

  @override
  Future<void> deleteSelection(String id) => channel.deleteSelection(id);

  @override
  Future<DayUsage> loadToday() => channel.today();

  @override
  Future<WeekReport> loadWeek() => channel.week();

  @override
  Future<ScreenTimeRules> loadRules() async => store.loadRules() ?? const ScreenTimeRules();

  @override
  Future<void> saveRules(ScreenTimeRules rules) async {
    await store.saveRules(rules);
    await applyRules();
  }

  @override
  Future<List<BlockSchedule>> loadSchedules() async => store.loadSchedules() ?? _defaultSchedules;

  @override
  Future<void> saveSchedules(List<BlockSchedule> schedules) async {
    await store.saveSchedules(schedules);
    await applyRules();
  }

  /// iOS: hands the saved rules to Screen Time. Also run at launch, so rules
  /// saved before an update or a restore take effect. The native side applies
  /// them in the background (and only once access is granted), logging any
  /// failure: the rules are saved either way and go again next save.
  Future<void> applyRules() async {
    if (!ios) return;
    try {
      await channel.applyRules(await loadRules(), await loadSchedules());
    } on PlatformException catch (e) {
      debugPrint('Could not hand the rules to Screen Time: ${e.code} ${e.message}');
    }
  }
}

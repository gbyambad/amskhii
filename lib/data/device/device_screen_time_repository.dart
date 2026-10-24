import '../models/app_usage.dart';
import '../models/block_schedule.dart';
import '../models/limit_rule.dart';
import '../models/week_report.dart';
import '../screen_time_repository.dart';
import 'local_settings_store.dart';
import 'screen_time_channel.dart';

/// Real usage from the OS; limits and schedules saved on the phone.
///
/// On iOS only the access calls work; see `nativeUsageReportsProvider`.
class DeviceScreenTimeRepository implements ScreenTimeRepository {
  DeviceScreenTimeRepository({required this.store, this.channel = const ScreenTimeChannel()});

  final LocalSettingsStore store;
  final ScreenTimeChannel channel;

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
  Future<DayUsage> loadToday() => channel.today();

  @override
  Future<WeekReport> loadWeek() => channel.week();

  @override
  Future<ScreenTimeRules> loadRules() async => store.loadRules() ?? const ScreenTimeRules();

  @override
  Future<void> saveRules(ScreenTimeRules rules) => store.saveRules(rules);

  @override
  Future<List<BlockSchedule>> loadSchedules() async => store.loadSchedules() ?? _defaultSchedules;

  @override
  Future<void> saveSchedules(List<BlockSchedule> schedules) => store.saveSchedules(schedules);
}

import 'models/app_selection.dart';
import 'models/app_usage.dart';
import 'models/block_schedule.dart';
import 'models/limit_rule.dart';
import 'models/week_report.dart';

/// Source of usage data and store for the user's rules.
///
/// `DeviceScreenTimeRepository` reads the phone's real usage; tests use the
/// fake in `test/support`, which serves the design's sample data.
abstract interface class ScreenTimeRepository {
  /// Whether the OS lets the app read usage; Android asks in Settings.
  Future<bool> hasUsageAccess();

  /// Opens the OS screen where the user grants usage access.
  Future<void> requestUsageAccess();

  /// Android only: whether the blocking service that enforces limits and
  /// schedules is on. The user turns it on in Accessibility settings.
  Future<bool> hasBlockingAccess();

  /// Opens the OS screen where the user turns blocking on.
  Future<void> requestBlockingAccess();

  /// iOS: what the user has picked in Apple's app picker; empty on Android.
  Future<List<AppSelection>> loadSelections();

  /// iOS: opens Apple's app picker for [id], starting from the earlier pick.
  /// Returns `null` when the user cancels.
  Future<AppSelection?> pickApps(String id);

  Future<void> deleteSelection(String id);

  Future<DayUsage> loadToday();

  Future<WeekReport> loadWeek();

  Future<ScreenTimeRules> loadRules();

  Future<void> saveRules(ScreenTimeRules rules);

  Future<List<BlockSchedule>> loadSchedules();

  Future<void> saveSchedules(List<BlockSchedule> schedules);
}

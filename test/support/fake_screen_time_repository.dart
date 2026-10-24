import 'package:amskhii/data/models/app_usage.dart';
import 'package:amskhii/data/models/block_schedule.dart';
import 'package:amskhii/data/models/limit_rule.dart';
import 'package:amskhii/data/models/week_report.dart';
import 'package:amskhii/data/screen_time_repository.dart';

/// In-memory repository holding the sample data from the design canvas.
class FakeScreenTimeRepository implements ScreenTimeRepository {
  FakeScreenTimeRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const _hourlyMinutes = [6, 0, 0, 0, 0, 0, 3, 14, 18, 10, 8, 12, 26, 20, 9, 11, 8, 15, 22, 24, 28, 18, 0, 0];
  static const _hourlyPickups = [1, 0, 0, 0, 0, 0, 1, 6, 7, 5, 4, 5, 8, 6, 4, 5, 4, 6, 7, 6, 7, 5, 0, 0];

  static const _apps = [
    AppUsage(
      appId: 'com.facebook.katana',
      name: 'Facebook',
      category: AppCategory.social,
      screenTime: Duration(minutes: 84),
      opens: 24,
      notifications: 46,
      dataBytes: 620000000,
    ),
    AppUsage(
      appId: 'com.zhiliaoapp.musically',
      name: 'TikTok',
      category: AppCategory.video,
      screenTime: Duration(minutes: 58),
      opens: 19,
      notifications: 12,
      dataBytes: 1430000000,
    ),
    AppUsage(
      appId: 'com.google.android.youtube',
      name: 'YouTube',
      category: AppCategory.video,
      screenTime: Duration(minutes: 46),
      opens: 9,
      notifications: 5,
      dataBytes: 980000000,
    ),
    AppUsage(
      appId: 'com.facebook.orca',
      name: 'Messenger',
      category: AppCategory.chat,
      screenTime: Duration(minutes: 32),
      opens: 21,
      notifications: 64,
      dataBytes: 85000000,
    ),
    AppUsage(
      appId: 'com.instagram.android',
      name: 'Instagram',
      category: AppCategory.social,
      screenTime: Duration(minutes: 21),
      opens: 11,
      notifications: 18,
      dataBytes: 240000000,
    ),
    AppUsage(
      appId: 'com.android.chrome',
      name: 'Chrome',
      category: AppCategory.other,
      screenTime: Duration(minutes: 11),
      opens: 3,
      notifications: 2,
      dataBytes: 60000000,
    ),
  ];

  ScreenTimeRules _rules = const ScreenTimeRules(
    apps: {
      'com.facebook.katana': LimitRule(dailyLimit: Duration(minutes: 90)),
      'com.zhiliaoapp.musically': LimitRule(dailyLimit: Duration(minutes: 60)),
      'com.instagram.android': LimitRule(blocked: true),
    },
    categories: {AppCategory.video: LimitRule(dailyLimit: Duration(hours: 2))},
    totalDailyLimit: Duration(hours: 4, minutes: 30),
    pinEnabled: true,
  );

  List<BlockSchedule> _schedules = const [
    BlockSchedule(
      id: 'bedtime',
      name: 'Амрах цаг',
      kind: ScheduleKind.bedtime,
      startMinute: 23 * 60,
      endMinute: 7 * 60,
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
    BlockSchedule(
      id: 'work',
      name: 'Ажлын цаг',
      kind: ScheduleKind.work,
      startMinute: 9 * 60,
      endMinute: 18 * 60,
      weekdays: {1, 2, 3, 4, 5},
      appIds: {'com.zhiliaoapp.musically', 'com.instagram.android', 'com.google.android.youtube'},
    ),
    BlockSchedule(
      id: 'dinner',
      name: 'Оройн хоол',
      kind: ScheduleKind.family,
      startMinute: 19 * 60,
      endMinute: 20 * 60,
      weekdays: {1, 2, 3, 4, 5, 6, 7},
      enabled: false,
    ),
  ];

  /// The sample day is frozen at 21:40 so the hourly charts match the design.
  DateTime get _asOf {
    final now = _clock();
    return DateTime(now.year, now.month, now.day, 21, 40);
  }

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> requestUsageAccess() async {}

  @override
  Future<DayUsage> loadToday() async {
    final asOf = _asOf;
    return DayUsage(
      asOf: asOf,
      hourlyScreenTime: [for (final m in _hourlyMinutes) Duration(minutes: m)],
      hourlyPickups: _hourlyPickups,
      apps: _apps,
      previousDayTotal: const Duration(hours: 4, minutes: 30),
      lastPickupAt: asOf.subtract(const Duration(minutes: 4)),
    );
  }

  @override
  Future<WeekReport> loadWeek() async {
    const minutes = [290, 275, 196, 205, 188, 190, 252];
    const pickups = [112, 104, 81, 85, 79, 83, 87];
    final today = _asOf;
    return WeekReport(
      days: [
        for (var i = 0; i < 7; i++)
          DaySummary(
            date: DateTime(today.year, today.month, today.day - (6 - i)),
            screenTime: Duration(minutes: minutes[i]),
            pickups: pickups[i],
          ),
      ],
      previousDailyAverage: const Duration(minutes: 259),
      byCategory: const {
        AppCategory.video: Duration(minutes: 765),
        AppCategory.social: Duration(minutes: 587),
        AppCategory.chat: Duration(minutes: 230),
        AppCategory.other: Duration(minutes: 14),
      },
      topApps: const [
        AppWeekUsage(appId: 'com.facebook.katana', name: 'Facebook', screenTime: Duration(minutes: 552), change: 0.08),
        AppWeekUsage(
          appId: 'com.zhiliaoapp.musically',
          name: 'TikTok',
          screenTime: Duration(minutes: 425),
          change: -0.15,
        ),
        AppWeekUsage(
          appId: 'com.google.android.youtube',
          name: 'YouTube',
          screenTime: Duration(minutes: 340),
          change: -0.04,
        ),
        AppWeekUsage(appId: 'com.facebook.orca', name: 'Messenger', screenTime: Duration(minutes: 230), change: 0.02),
      ],
    );
  }

  @override
  Future<ScreenTimeRules> loadRules() async => _rules;

  @override
  Future<void> saveRules(ScreenTimeRules rules) async => _rules = rules;

  @override
  Future<List<BlockSchedule>> loadSchedules() async => _schedules;

  @override
  Future<void> saveSchedules(List<BlockSchedule> schedules) async => _schedules = schedules;
}

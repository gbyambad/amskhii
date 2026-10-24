import 'package:amskhii/data/device/device_screen_time_repository.dart';
import 'package:amskhii/data/device/local_settings_store.dart';
import 'package:amskhii/data/models/app_usage.dart';
import 'package:amskhii/data/models/block_schedule.dart';
import 'package:amskhii/data/models/limit_rule.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('amskhii/screen_time');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final midnight = DateTime(2026, 10, 23);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'hasUsageAccess':
          return true;
        case 'getToday':
          return {
            'asOf': midnight.add(const Duration(hours: 21, minutes: 40)).millisecondsSinceEpoch,
            'hourlyScreenTimeMs': List.filled(24, 60000),
            'hourlyPickups': List.filled(24, 2),
            'previousDayTotalMs': 3600000,
            'lastPickupAt': null,
            'apps': [
              {
                'appId': 'org.telegram.messenger',
                'name': 'Telegram',
                'category': 'chat',
                'screenTimeMs': 1800000,
                'opens': 7,
                'notifications': 31,
                'dataBytes': 42000000,
                'icon': Uint8List.fromList([1, 2, 3]),
              },
            ],
          };
        case 'getWeek':
          return {
            'days': [
              for (var i = 0; i < 7; i++)
                {
                  'date': midnight.subtract(Duration(days: 6 - i)).millisecondsSinceEpoch,
                  'screenTimeMs': 3600000 * (i + 1),
                  'pickups': 10 + i,
                },
            ],
            'previousDailyAverageMs': null,
            'byCategoryMs': {'chat': 7200000, 'unknown': 60000},
            'topApps': [
              {'appId': 'org.telegram.messenger', 'name': 'Telegram', 'screenTimeMs': 7200000, 'change': null},
            ],
          };
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<DeviceScreenTimeRepository> repository() async =>
      DeviceScreenTimeRepository(store: LocalSettingsStore(await SharedPreferences.getInstance()));

  test('parses today from the platform', () async {
    final today = await (await repository()).loadToday();

    expect(today.total, const Duration(minutes: 24));
    expect(today.pickups, 48);
    expect(today.lastPickupAt, isNull);
    final app = today.apps.single;
    expect(app.category, AppCategory.chat);
    expect(app.screenTime, const Duration(minutes: 30));
    expect(app.icon, [1, 2, 3]);
  });

  test('parses the week; unknown categories fold into other', () async {
    final week = await (await repository()).loadWeek();

    expect(week.days, hasLength(7));
    expect(week.days.last.date, midnight);
    expect(week.previousDailyAverage, isNull);
    expect(week.changeVsPrevious, isNull);
    expect(week.byCategory[AppCategory.other], const Duration(minutes: 1));
    expect(week.topApps.single.change, isNull);
  });

  test('rules and schedules survive a restart', () async {
    final first = await repository();
    expect(await first.loadRules(), isA<ScreenTimeRules>());
    await first.saveRules(
      const ScreenTimeRules(
        apps: {'org.telegram.messenger': LimitRule(dailyLimit: Duration(minutes: 45), onLimit: LimitAction.warn)},
        categories: {AppCategory.video: LimitRule(blocked: true)},
        totalDailyLimit: Duration(hours: 3),
        pinEnabled: true,
      ),
    );
    final schedules = await first.loadSchedules();
    await first.saveSchedules([schedules.single.copyWith(enabled: true).toggleApp('a.b')]);

    final second = await repository();
    final rules = await second.loadRules();
    expect(rules.forApp('org.telegram.messenger'),
        const LimitRule(dailyLimit: Duration(minutes: 45), onLimit: LimitAction.warn));
    expect(rules.forCategory(AppCategory.video).blocked, isTrue);
    expect(rules.totalDailyLimit, const Duration(hours: 3));
    expect(rules.pinEnabled, isTrue);

    final restored = (await second.loadSchedules()).single;
    expect(restored.enabled, isTrue);
    expect(restored.kind, ScheduleKind.bedtime);
    expect(restored.appIds, {'a.b'});
    expect(restored.weekdays, {1, 2, 3, 4, 5, 6, 7});
  });
}

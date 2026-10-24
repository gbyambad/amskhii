import 'package:amskhii/data/models/block_schedule.dart';
import 'package:amskhii/data/models/limit_rule.dart';
import 'package:amskhii/data/models/week_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_screen_time_repository.dart';

void main() {
  group('LimitRule', () {
    test('stepLimit adds, caps and removes the limit', () {
      expect(LimitRule.none.stepLimit(const Duration(minutes: 15)).dailyLimit, const Duration(minutes: 15));
      expect(
        const LimitRule(dailyLimit: Duration(minutes: 15)).stepLimit(const Duration(minutes: -15)).dailyLimit,
        isNull,
      );
      expect(
        const LimitRule(dailyLimit: Duration(hours: 12)).stepLimit(const Duration(minutes: 15)).dailyLimit,
        LimitRule.maxDailyLimit,
      );
    });

    test('remaining and isNear', () {
      const rule = LimitRule(dailyLimit: Duration(minutes: 90));
      expect(rule.remaining(const Duration(minutes: 84)), const Duration(minutes: 6));
      expect(rule.isNear(const Duration(minutes: 84)), isTrue);
      expect(rule.isNear(const Duration(minutes: 30)), isFalse);
      expect(rule.remaining(const Duration(minutes: 100)), Duration.zero);
      expect(rule.copyWith(blocked: true).isNear(const Duration(minutes: 84)), isFalse);
      expect(LimitRule.none.remaining(const Duration(minutes: 84)), isNull);
    });
  });

  group('WeekReport', () {
    test('streakWithin counts back from today', () async {
      final report = await FakeScreenTimeRepository().loadWeek();
      expect(report.streakWithin(const Duration(hours: 4, minutes: 30)), 5);
      expect(report.streakWithin(const Duration(hours: 4)), 0);
      expect(report.dailyAverage, const Duration(hours: 3, minutes: 48));
      expect(report.averagePickups, 90);
    });

    test('averages skip days with no data', () {
      final today = DateTime(2026, 10, 23);
      final report = WeekReport(
        days: [
          for (var i = 0; i < 6; i++)
            DaySummary(
              date: today.subtract(Duration(days: 6 - i)),
              screenTime: Duration.zero,
              pickups: 0,
            ),
          DaySummary(date: today, screenTime: const Duration(hours: 2), pickups: 30),
        ],
        previousDailyAverage: null,
        byCategory: const {},
        topApps: const [],
      );
      expect(report.dailyAverage, const Duration(hours: 2));
      expect(report.averagePickups, 30);
      expect(report.changeVsPrevious, isNull);
    });
  });

  group('BlockSchedule', () {
    const bedtime = BlockSchedule(
      id: 'b',
      name: 'Амрах цаг',
      kind: ScheduleKind.bedtime,
      startMinute: 23 * 60,
      endMinute: 7 * 60,
      weekdays: {1, 2, 3},
    );

    test('length across midnight', () {
      expect(bedtime.crossesMidnight, isTrue);
      expect(bedtime.length, const Duration(hours: 8));
    });

    test('shifting wraps and never makes start meet end', () {
      expect(bedtime.shiftStart(60).startMinute, 0);
      expect(bedtime.shiftEnd(-8 * 60), same(bedtime));
    });

    test('toggles weekdays and apps', () {
      expect(bedtime.toggleWeekday(2).weekdays, {1, 3});
      expect(bedtime.toggleWeekday(7).weekdays, {1, 2, 3, 7});
      expect(bedtime.toggleApp('x').appIds, {'x'});
    });
  });
}

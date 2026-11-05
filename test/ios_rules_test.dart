import 'package:amskhii/core/theme/app_theme.dart';
import 'package:amskhii/data/models/app_selection.dart';
import 'package:amskhii/data/models/limit_rule.dart';
import 'package:amskhii/features/limits/limits_screen.dart';
import 'package:amskhii/features/schedule/schedule_screen.dart';
import 'package:amskhii/state/screen_time_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_screen_time_repository.dart';

/// Pumps one tab as it runs on iOS: no usage in Dart, apps from Apple's picker.
Future<ProviderContainer> _pumpIos(WidgetTester tester, FakeScreenTimeRepository repository, Widget tab) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        screenTimeRepositoryProvider.overrideWithValue(repository),
        nativeUsageReportsProvider.overrideWithValue(true),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: tab)),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byWidget(tab)));
}

void main() {
  test('a pick reads as counts', () {
    expect(const AppSelection(id: 'x', apps: 3, categories: 1).label, '3 апп · 1 ангилал');
    expect(const AppSelection(id: 'x', sites: 2).label, '2 вэб сайт');
    expect(const AppSelection(id: 'x').label, 'Апп сонгоогүй');
  });

  testWidgets('iOS Limits: pick apps, block them, then limit them instead', (tester) async {
    final repository = FakeScreenTimeRepository()..nextPick = (id) => AppSelection(id: id, apps: 3, categories: 1);
    final container = await _pumpIos(tester, repository, const LimitsScreen());

    expect(find.textContaining('Хязгаарлах аппуудаа сонгоно уу'), findsOneWidget);
    await tester.tap(find.text('Апп сонгох'));
    await tester.pumpAndSettle();
    expect(find.text('3 апп · 1 ангилал'), findsOneWidget);
    final id = repository.selections.keys.single;
    expect(id, startsWith(AppSelection.limitPrefix));

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(container.read(rulesProvider).requireValue.forApp(id).blocked, isTrue);
    expect(find.textContaining('Хаалттай'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Хязгаарыг 15 минутаар нэмэх'));
    await tester.pumpAndSettle();
    expect(find.text('15м'), findsOneWidget);
    await tester.tap(find.text('Сануулах'));
    await tester.pumpAndSettle();
    final rule = container.read(rulesProvider).requireValue.forApp(id);
    expect(rule.dailyLimit, const Duration(minutes: 15));
    expect(rule.onLimit, LimitAction.warn);

    await tester.tap(find.text('Устгах'));
    await tester.pumpAndSettle();
    expect(repository.selections, isEmpty);
    expect(container.read(rulesProvider).requireValue.apps, isNot(contains(id)));
  });

  testWidgets('iOS Limits: cancelling the picker adds nothing', (tester) async {
    final repository = FakeScreenTimeRepository()..nextPick = (_) => null;
    await _pumpIos(tester, repository, const LimitsScreen());

    await tester.tap(find.text('Апп сонгох'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Хязгаарлах аппуудаа сонгоно уу'), findsOneWidget);
  });

  testWidgets('iOS Schedule: loads without usage and picks its apps', (tester) async {
    final repository = FakeScreenTimeRepository()..nextPick = (id) => AppSelection(id: id, apps: 2);
    final container = await _pumpIos(tester, repository, const ScheduleScreen());

    // The work schedule starts expanded; its Android package names mean nothing on iOS.
    final schedule = container.read(schedulesProvider).requireValue.firstWhere((s) => s.id == 'work');
    await tester.tap(find.text('Апп сонгоогүй'));
    await tester.pumpAndSettle();

    final saved = container.read(schedulesProvider).requireValue.firstWhere((s) => s.id == schedule.id);
    expect(saved.appIds, {AppSelection.forSchedule(schedule.id)});
    expect(find.text('2 апп'), findsOneWidget);
  });
}

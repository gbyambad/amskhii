import 'package:amskhii/app.dart';
import 'package:amskhii/core/theme/app_theme.dart';
import 'package:amskhii/data/device/biometrics.dart';
import 'package:amskhii/data/device/pin_store.dart';
import 'package:amskhii/data/models/block_schedule.dart';
import 'package:amskhii/data/models/limit_rule.dart';
import 'package:amskhii/features/pin/pin_screen.dart';
import 'package:amskhii/features/pin/prompting_pin_gate.dart';
import 'package:amskhii/state/pin_gate.dart';
import 'package:amskhii/state/screen_time_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_screen_time_repository.dart';

const _youtube = 'com.google.android.youtube';

/// An enrolled face or finger that always matches.
class _FakeBiometrics implements Biometrics {
  @override
  Future<bool> available() async => true;

  @override
  Future<bool> authenticate(String reason) async => true;

  @override
  Future<bool> authenticateDevice(String reason) async => true;
}

class _FakeGate implements PinGate {
  _FakeGate({required this.allow});

  final bool allow;
  final reasons = <String>[];

  @override
  Future<bool> unlock(String reason) async {
    reasons.add(reason);
    return allow;
  }

  @override
  void lock() {}
}

/// Pushes [screen] over a blank page and returns what it pops with.
Future<Future<bool?>> _push(WidgetTester tester, Widget screen, PinStore store, {Biometrics? biometrics}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pinStoreProvider.overrideWithValue(store),
        if (biometrics != null) biometricsProvider.overrideWithValue(biometrics),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const SizedBox()),
    ),
  );
  final result = tester.state<NavigatorState>(find.byType(Navigator)).push<bool>(MaterialPageRoute(builder: (_) => screen));
  await tester.pumpAndSettle();
  return result;
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  group('loosening', () {
    test('a rule loosens when unblocked, given more time or softened to a warning', () {
      const limited = LimitRule(dailyLimit: Duration(hours: 1));
      expect(const LimitRule(blocked: true).loosenedBy(LimitRule.none), isTrue);
      expect(limited.loosenedBy(const LimitRule(dailyLimit: Duration(hours: 2))), isTrue);
      expect(limited.loosenedBy(LimitRule.none), isTrue);
      expect(limited.loosenedBy(limited.copyWith(onLimit: LimitAction.warn)), isTrue);
      expect(limited.loosenedBy(const LimitRule(dailyLimit: Duration(minutes: 30))), isFalse);
      expect(LimitRule.none.loosenedBy(const LimitRule(blocked: true)), isFalse);
    });

    test('rules loosen when the PIN goes off or the total grows', () {
      const rules = ScreenTimeRules(totalDailyLimit: Duration(hours: 3), pinEnabled: true);
      expect(rules.loosenedBy(rules.copyWith(pinEnabled: false)), isTrue);
      expect(rules.loosenedBy(rules.copyWith(totalDailyLimit: () => const Duration(hours: 4))), isTrue);
      expect(rules.loosenedBy(rules.withApp(_youtube, const LimitRule(blocked: true))), isFalse);
    });

    test('a schedule loosens when it covers fewer minutes or apps', () {
      const night = BlockSchedule(
        id: 'n',
        name: 'Шөнө',
        kind: ScheduleKind.bedtime,
        startMinute: 23 * 60,
        endMinute: 7 * 60,
        weekdays: {1, 2, 3, 4, 5},
        appIds: {_youtube},
      );
      expect(night.loosenedBy(night.copyWith(enabled: false)), isTrue);
      expect(night.loosenedBy(night.shiftEnd(-60)), isTrue);
      expect(night.loosenedBy(night.toggleWeekday(1)), isTrue);
      expect(night.loosenedBy(night.toggleApp(_youtube)), isTrue);
      // Longer, more days or every app only tightens it.
      expect(night.loosenedBy(night.shiftEnd(60)), isFalse);
      expect(night.loosenedBy(night.toggleWeekday(6)), isFalse);
      expect(night.copyWith(enabled: false).loosenedBy(night), isFalse);
    });
  });

  group('notifiers', () {
    late FakeScreenTimeRepository repo;

    ProviderContainer containerWith(PinGate gate) => ProviderContainer.test(
          overrides: [screenTimeRepositoryProvider.overrideWithValue(repo), pinGateProvider.overrideWithValue(gate)],
        );

    setUp(() async {
      repo = FakeScreenTimeRepository();
      await repo.saveRules(const ScreenTimeRules().withApp(_youtube, const LimitRule(blocked: true)));
    });

    test('a refused unlock leaves the rules as they were', () async {
      final gate = _FakeGate(allow: false);
      final container = containerWith(gate);
      await container.read(rulesProvider.future);

      expect(await container.read(rulesProvider.notifier).toggleAppBlocked(_youtube), isFalse);
      expect(gate.reasons, ['Хязгаарыг сулруулахын тулд']);
      expect((await repo.loadRules()).forApp(_youtube).blocked, isTrue);
    });

    test('tightening never asks', () async {
      final gate = _FakeGate(allow: false);
      final container = containerWith(gate);
      await container.read(rulesProvider.future);

      expect(await container.read(rulesProvider.notifier).stepAppLimit('org.telegram.messenger', const Duration(minutes: 15)), isTrue);
      expect(gate.reasons, isEmpty);
    });

    test('a schedule turned off asks first', () async {
      final gate = _FakeGate(allow: true);
      final container = containerWith(gate);
      final schedules = await container.read(schedulesProvider.future);
      final on = schedules.firstWhere((s) => s.enabled);

      expect(await container.read(schedulesProvider.notifier).replace(on.copyWith(enabled: false)), isTrue);
      expect(gate.reasons, ['Хуваарийг сулруулахын тулд']);
    });
  });

  group('PIN screens', () {
    testWidgets('setup asks twice and saves only a match', (tester) async {
      final store = MemoryPinStore();
      final result = await _push(tester, const PinSetupScreen(), store);

      await _type(tester, '1234');
      expect(find.text('PIN-ээ дахин оруулна уу'), findsOneWidget);
      await _type(tester, '1235');
      expect(find.text('Хоёр код таарсангүй. Дахин эхэлнэ үү.'), findsOneWidget);
      expect(store.hasPin, isFalse);

      await _type(tester, '1234');
      await _type(tester, '1234');
      expect(await result, isTrue);
      expect(store.verify('1234'), isTrue);
    });

    testWidgets('entry lets the right PIN through', (tester) async {
      final store = MemoryPinStore();
      await store.setPin('2580');
      var done = false;
      final result = await _push(tester, const PinEntryScreen(reason: 'Хязгаарыг сулруулахын тулд'), store);
      result.then((_) => done = true);

      expect(find.text('Хязгаарыг сулруулахын тулд'), findsOneWidget);
      expect(find.byTooltip('Хурууны хээ эсвэл Face ID'), findsNothing);
      await _type(tester, '1111');
      expect(find.text('PIN буруу байна'), findsOneWidget);
      expect(done, isFalse);

      await _type(tester, '2580');
      expect(await result, isTrue);
    });

    testWidgets('five wrong tries rest the keypad', (tester) async {
      final store = MemoryPinStore();
      await store.setPin('2580');
      await _push(tester, const PinEntryScreen(reason: 'x'), store);

      for (var i = 0; i < 5; i++) {
        await _type(tester, '1111');
      }
      expect(find.text('30 секундын дараа дахин оролдоно уу'), findsOneWidget);
      await _type(tester, '2580');
      expect(find.byType(PinEntryScreen), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      await _type(tester, '2580');
      expect(find.byType(PinEntryScreen), findsNothing);
    });

    testWidgets('a face or finger opens it without typing', (tester) async {
      final store = MemoryPinStore();
      await store.setPin('2580');
      final result = await _push(tester, const PinEntryScreen(reason: 'x'), store, biometrics: _FakeBiometrics());

      expect(await result, isTrue);
    });
  });

  testWidgets('unblocking an app with the PIN on asks for it once', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = FakeScreenTimeRepository();
    await repo.saveRules(const ScreenTimeRules(pinEnabled: true).withApp(_youtube, const LimitRule(blocked: true)));
    final store = MemoryPinStore();
    await store.setPin('2580');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenTimeRepositoryProvider.overrideWithValue(repo),
          pinStoreProvider.overrideWithValue(store),
          pinGateProvider.overrideWith(PromptingPinGate.new),
        ],
        child: const ScreenTimeApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хязгаар'));
    await tester.pumpAndSettle();

    final youtubeSwitch = find.descendant(
      of: find.ancestor(of: find.text('YouTube'), matching: find.byType(MergeSemantics)).first,
      matching: find.byType(Switch),
    );
    await tester.tap(youtubeSwitch);
    await tester.pumpAndSettle();
    expect(find.text('PIN код оруулна уу'), findsOneWidget);

    await _type(tester, '2580');
    expect(find.byType(PinEntryScreen), findsNothing);
    expect((await repo.loadRules()).forApp(_youtube).blocked, isFalse);

    // Within the grace period the next loosening goes straight through.
    await tester.tap(youtubeSwitch);
    await tester.pumpAndSettle();
    await tester.tap(youtubeSwitch);
    await tester.pumpAndSettle();
    expect(find.byType(PinEntryScreen), findsNothing);
    expect((await repo.loadRules()).forApp(_youtube).blocked, isFalse);
  });
}

import 'package:amskhii/app.dart';
import 'package:amskhii/data/models/app_usage.dart';
import 'package:amskhii/features/block/block_screen.dart';
import 'package:amskhii/state/screen_time_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_screen_time_repository.dart';

const _channel = MethodChannel('amskhii/block');

Future<List<String>> _pumpBlockScreen(WidgetTester tester, BlockReason reason) async {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    calls.add(call.method);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));
  await tester.pumpWidget(ScreenTimeApp(home: BlockScreen(reason: reason)));
  return calls;
}

void main() {
  group('BlockReason', () {
    test('reads what BlockActivity sends', () {
      final reason = BlockReason.fromJson(
        '{"appId":"com.google.android.youtube","appName":"YouTube","warnOnly":false,'
        '"kind":"categoryLimit","category":"video","limitMinutes":90}',
      );
      expect(reason.kind, BlockKind.categoryLimit);
      expect(reason.category, AppCategory.video);
      expect(reason.limit, const Duration(minutes: 90));
      expect(reason.title, 'Өдрийн хязгаар дууслаа');
      expect(reason.message, '«Видео» ангилалд өгсөн өдрийн 1ц 30м хязгаар дууссан. Маргааш дахин нээгдэнэ.');
    });

    test('names the schedule and its hours', () {
      final reason = BlockReason.fromJson(
        '{"appName":"TikTok","kind":"schedule","scheduleName":"Амрах цаг",'
        '"startMinute":1380,"endMinute":420,"allApps":true}',
      );
      expect(reason.title, 'TikTok хаалттай');
      expect(reason.message, '«Амрах цаг» хуваарийн дагуу 23:00–07:00 хооронд хаалттай. Дуудлага, мессеж нээлттэй.');
    });

    test('a warning does not promise tomorrow', () {
      const reason = BlockReason(appName: 'YouTube', kind: BlockKind.appLimit, warnOnly: true, limit: Duration(hours: 1));
      expect(reason.message, 'YouTube-д өгсөн өдрийн 1ц хязгаар дууссан.');
    });
  });

  testWidgets('a block only offers the way home', (tester) async {
    final calls = await _pumpBlockScreen(tester, const BlockReason(appName: 'YouTube', kind: BlockKind.appBlocked));

    expect(find.text('YouTube хаалттай'), findsOneWidget);
    expect(find.text('Үргэлжлүүлэх'), findsNothing);
    await tester.tap(find.text('Ойлголоо'));
    expect(calls, ['goHome']);
  });

  testWidgets('a warning lets the user carry on', (tester) async {
    final calls = await _pumpBlockScreen(
      tester,
      const BlockReason(appName: 'YouTube', kind: BlockKind.appLimit, warnOnly: true, limit: Duration(hours: 1)),
    );

    expect(find.text('Үргэлжлүүлэх'), findsOneWidget);
    await tester.tap(find.text('Аппаас гарах'));
    expect(calls, ['goHome']);
  });

  testWidgets('Limits and Schedule ask for the blocking service while it is off', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repository = FakeScreenTimeRepository()..blockingAccess = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [screenTimeRepositoryProvider.overrideWithValue(repository)],
        child: const ScreenTimeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Хязгаар'));
    await tester.pumpAndSettle();
    expect(find.text('Хаалт ажиллахгүй байна'), findsOneWidget);

    await tester.tap(find.text('Хуваарь'));
    await tester.pumpAndSettle();
    expect(find.text('Хаалт ажиллахгүй байна'), findsOneWidget);

    // Turned on in Settings, then back in the app.
    repository.blockingAccess = true;
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    container.invalidate(blockingAccessProvider);
    await tester.pumpAndSettle();
    expect(find.text('Хаалт ажиллахгүй байна'), findsNothing);
  });
}

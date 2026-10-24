import 'package:amskhii/app.dart';
import 'package:amskhii/features/shell/home_shell.dart';
import 'package:amskhii/state/screen_time_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_screen_time_repository.dart';

const _youtube = 'com.google.android.youtube';

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [screenTimeRepositoryProvider.overrideWithValue(FakeScreenTimeRepository())],
      child: const ScreenTimeApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('overview shows today and the near-limit banner', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Дэлгэцийн цаг'), findsOneWidget);
    expect(find.text('4ц 12м'), findsOneWidget);
    expect(find.text('2 апп хязгаартаа ойртож байна'), findsOneWidget);
  });

  testWidgets('blocking an app in the sheet carries over to the Limits tab', (tester) async {
    await _pumpApp(tester);

    await tester.scrollUntilVisible(find.text('YouTube'), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Идэвхгүй болгох'));
    await tester.pumpAndSettle();
    expect(find.textContaining('YouTube нээгдэхгүй'), findsOneWidget);

    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(HomeShell)));
    expect(container.read(rulesProvider).requireValue.forApp(_youtube).blocked, isTrue);

    await tester.tap(find.text('Хязгаар'));
    await tester.pumpAndSettle();
    expect(find.text('Апп ба өдрийн хязгаар'), findsOneWidget);
  });
}

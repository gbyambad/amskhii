// Renders every screen with the bundled fonts at narrow widths and large text
// scales, failing on any RenderFlex overflow. The default test font is much
// wider than Onest, so real fonts are needed to catch real overflows.
import 'dart:io';

import 'package:amskhii/app.dart';
import 'package:amskhii/state/screen_time_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_screen_time_repository.dart';

Future<void> _loadFonts() async {
  Future<ByteData> file(String path) async => ByteData.sublistView(await File(path).readAsBytes());

  final onest = FontLoader('Onest');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    onest.addFont(file('assets/fonts/Onest-$weight.ttf'));
  }
  await onest.load();

  final unbounded = FontLoader('Unbounded')
    ..addFont(file('assets/fonts/Unbounded-Medium.ttf'))
    ..addFont(file('assets/fonts/Unbounded-SemiBold.ttf'));
  await unbounded.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (flutterRoot != null && icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(file(icons.path))).load();
  }
}

void main() {
  const cases = [(320.0, 1.35), (360.0, 1.3), (375.0, 1.15), (393.0, 1.0), (430.0, 1.0)];

  testWidgets('no overflow on any screen', (tester) async {
    await tester.runAsync(_loadFonts);
    final overflows = <String>{};
    var current = '';
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      final overflow = RegExp(r'overflowed by [\d.]+ pixels on the \w+').firstMatch(text);
      if (overflow == null) return original?.call(details);
      final source = RegExp(r'lib/\S+:\d+:\d+').firstMatch(text)?.group(0) ?? '?';
      overflows.add('$source ${overflow.group(0)} at $current');
    };
    addTearDown(() => FlutterError.onError = original);

    Future<void> tap(Finder finder) async {
      if (finder.evaluate().isEmpty) return;
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      await tester.tap(finder.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    for (final (width, scale) in cases) {
      current = '${width}dp × $scale';
      tester.view.physicalSize = Size(width * 3, 2600 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [screenTimeRepositoryProvider.overrideWithValue(FakeScreenTimeRepository())],
          child: const ScreenTimeApp(),
        ),
      );
      await tester.pumpAndSettle();

      for (final metric in ['Нээсэн', 'Мэдэгдэл', 'Дата', 'Цаг']) {
        await tap(find.text(metric));
      }
      for (final app in ['Facebook', 'Instagram']) {
        await tap(find.text(app));
        await tap(find.text('Идэвхгүй болгох'));
        await tap(find.text('2ц'));
        await tap(find.text('Хадгалах'));
      }
      await tap(find.text('Тайлан'));
      await tap(find.text('Хязгаар').last);
      await tap(find.text('Ангилал'));
      await tap(find.text('Хуваарь').last);
      await tap(find.text('Амрах цаг'));
      await tap(find.text('Шинэ хуваарь нэмэх'));
    }

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.reset();
    expect(overflows, isEmpty);
  });
}

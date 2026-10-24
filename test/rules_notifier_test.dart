import 'package:amskhii/data/models/app_usage.dart';
import 'package:amskhii/state/screen_time_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_screen_time_repository.dart';

const _youtube = 'com.google.android.youtube';

void main() {
  late FakeScreenTimeRepository repo;
  late ProviderContainer container;

  setUp(() async {
    repo = FakeScreenTimeRepository();
    container = ProviderContainer.test(overrides: [screenTimeRepositoryProvider.overrideWithValue(repo)]);
    await container.read(rulesProvider.future);
  });

  RulesNotifier notifier() => container.read(rulesProvider.notifier);

  test('toggling an app updates state and persists it', () async {
    await notifier().toggleAppBlocked(_youtube);

    expect(container.read(rulesProvider).requireValue.forApp(_youtube).blocked, isTrue);
    expect((await repo.loadRules()).forApp(_youtube).blocked, isTrue);
  });

  test('stepping a category limit from unlimited', () async {
    await notifier().stepCategoryLimit(AppCategory.chat, const Duration(minutes: 15));

    expect(
      container.read(rulesProvider).requireValue.forCategory(AppCategory.chat).dailyLimit,
      const Duration(minutes: 15),
    );
  });

  test('total daily limit stays within bounds', () async {
    await notifier().stepTotalDailyLimit(const Duration(hours: -20));
    expect(container.read(rulesProvider).requireValue.totalDailyLimit, const Duration(minutes: 30));

    await notifier().stepTotalDailyLimit(const Duration(hours: 40));
    expect(container.read(rulesProvider).requireValue.totalDailyLimit, const Duration(hours: 16));
  });

  test('schedules: replace keeps order', () async {
    final schedules = await container.read(schedulesProvider.future);
    await container.read(schedulesProvider.notifier).replace(schedules[1].copyWith(enabled: false));

    final next = container.read(schedulesProvider).requireValue;
    expect(next.map((s) => s.id), schedules.map((s) => s.id));
    expect(next[1].enabled, isFalse);
  });
}

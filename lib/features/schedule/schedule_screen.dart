import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_visuals.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/tiles.dart';
import '../../data/models/app_selection.dart';
import '../../data/models/app_usage.dart';
import '../../data/models/block_schedule.dart';
import '../../state/screen_time_providers.dart';
import '../limits/blocking_banner.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  String? _expanded = 'work';

  Future<void> _addSchedule() async {
    final schedule = BlockSchedule(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Шинэ хуваарь',
      kind: ScheduleKind.custom,
      startMinute: 14 * 60,
      endMinute: 16 * 60,
      weekdays: const {DateTime.saturday, DateTime.sunday},
      appIds: const {},
    );
    setState(() => _expanded = schedule.id);
    await ref.read(schedulesProvider.notifier).add(schedule);
  }

  /// iOS: the schedule's apps come from Apple's picker.
  Future<void> _pickApps(BlockSchedule schedule) async {
    final id = AppSelection.forSchedule(schedule.id);
    final picked = await ref.read(selectionsProvider.notifier).pick(id);
    if (picked == null) return;
    await ref.read(schedulesProvider.notifier).replace(schedule.withAppIds(picked.isEmpty ? const {} : {id}));
  }

  @override
  Widget build(BuildContext context) {
    final blockingOff = ref.watch(blockingOffProvider);
    final ios = ref.watch(nativeUsageReportsProvider);
    // Dart gets today's apps on Android only; iOS lists picks instead.
    final AsyncValue<(List<AppUsage>, List<AppSelection>)> choices = ios
        ? ref.watch(selectionsProvider).whenData((picks) => (const <AppUsage>[], picks))
        : ref.watch(todayUsageProvider).whenData((usage) => (usage.apps, const <AppSelection>[]));
    return AsyncView(
      value: combineAsync(ref.watch(schedulesProvider), choices),
      builder: (context, data) {
        final (schedules, (apps, picks)) = data;
        final notifier = ref.read(schedulesProvider.notifier);
        return ScreenScroll(
          children: [
            const ScreenHeader(title: 'Хуваарь', subtitle: 'Тодорхой цагт аппуудыг автоматаар хаах'),
            if (blockingOff) const BlockingBanner(),
            for (final schedule in schedules)
              _ScheduleCard(
                schedule: schedule,
                apps: apps,
                pick: picks.where((p) => p.id == AppSelection.forSchedule(schedule.id)).firstOrNull,
                onPickApps: ios ? () => _pickApps(schedule) : null,
                expanded: _expanded == schedule.id,
                onToggleExpanded: () => setState(() => _expanded = _expanded == schedule.id ? null : schedule.id),
                onChanged: notifier.replace,
              ),
            OutlinedButton.icon(
              onPressed: _addSchedule,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Шинэ хуваарь нэмэх'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.inactive, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(fontFamily: 'Onest', fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _daysSummary(Set<int> weekdays) {
  final sorted = weekdays.toList()..sort();
  return switch (sorted.join()) {
    '1234567' => 'Өдөр бүр',
    '12345' => 'Ажлын өдөр',
    '67' => 'Амралтын өдөр',
    '' => 'Өдөр сонгоогүй',
    _ => sorted.map(weekdayShort).join(', '),
  };
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.apps,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onChanged,
    this.pick,
    this.onPickApps,
  });

  static const _hour = 60;

  final BlockSchedule schedule;
  final List<AppUsage> apps;

  /// iOS: the schedule's pick from Apple's picker, changed through [onPickApps]
  /// instead of choosing from [apps].
  final AppSelection? pick;
  final VoidCallback? onPickApps;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<BlockSchedule> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    final start = formatMinuteOfDay(s.startMinute);
    final end = formatMinuteOfDay(s.endMinute);

    return SectionCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  expanded: expanded,
                  child: InkWell(
                    onTap: onToggleExpanded,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        spacing: 12,
                        children: [
                          IconTile(icon: s.kind.icon, color: s.enabled ? s.kind.tileColor : AppColors.inactive),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 2,
                              children: [
                                Text(s.name, style: AppText.cardTitle),
                                Text('$start – $end · ${_daysSummary(s.weekdays)}', style: AppText.body.copyWith(fontSize: 13)),
                              ],
                            ),
                          ),
                          Icon(
                            expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: AppColors.inactive,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                label: '${s.name} асаах',
                child: Switch(value: s.enabled, onChanged: (v) => onChanged(s.copyWith(enabled: v))),
              ),
              const SizedBox(width: 4),
            ],
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        StepperRow(
                          label: 'Эхлэх',
                          value: start,
                          onDecrement: () => onChanged(s.shiftStart(-_hour)),
                          onIncrement: () => onChanged(s.shiftStart(_hour)),
                          decrementTooltip: 'Эхлэх цагийг 1 цагаар багасгах',
                          incrementTooltip: 'Эхлэх цагийг 1 цагаар нэмэх',
                        ),
                        const Divider(color: AppColors.line),
                        StepperRow(
                          label: 'Дуусах',
                          value: end,
                          onDecrement: () => onChanged(s.shiftEnd(-_hour)),
                          onIncrement: () => onChanged(s.shiftEnd(_hour)),
                          decrementTooltip: 'Дуусах цагийг 1 цагаар багасгах',
                          incrementTooltip: 'Дуусах цагийг 1 цагаар нэмэх',
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${formatDuration(s.length)} үргэлжилнэ${s.crossesMidnight ? ' · шөнө дундыг дамжина' : ''}',
                    style: AppText.caption,
                  ),
                  Row(
                    spacing: 4,
                    children: [
                      for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                        Expanded(
                          child: ChoicePill(
                            label: weekdayShort(day),
                            semanticsLabel: weekdayName(day),
                            selected: s.weekdays.contains(day),
                            borderRadius: 12,
                            padding: EdgeInsets.zero,
                            onTap: () => onChanged(s.toggleWeekday(day)),
                          ),
                        ),
                    ],
                  ),
                  if (s.blocksAllApps)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        onPickApps == null
                            ? 'Дуудлага, мессежээс бусад бүх апп хаагдана.'
                            : 'Бүх апп хаагдана. Яаралтай дуудлага үргэлж боломжтой.',
                        style: AppText.body.copyWith(fontSize: 13, color: AppColors.ink),
                      ),
                    )
                  else ...[
                    const Text('Хаах аппууд', style: AppText.label),
                    if (onPickApps case final onPickApps?)
                      Material(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: onPickApps,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              spacing: 10,
                              children: [
                                const Icon(Icons.apps_rounded, color: AppColors.accent),
                                Expanded(
                                  child: Text(
                                    pick?.label ?? 'Апп сонгоогүй',
                                    style: AppText.rowTitle.copyWith(fontSize: 14),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.inactive),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final app in apps)
                            ChoicePill(
                              label: app.name,
                              selected: s.appIds!.contains(app.appId),
                              leading: AppTile(appId: app.appId, name: app.name, icon: app.icon, size: 30),
                              onTap: () => onChanged(s.toggleApp(app.appId)),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

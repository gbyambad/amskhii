import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_visuals.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/tiles.dart';
import '../../data/models/app_selection.dart';
import '../../data/models/app_usage.dart';
import '../../data/models/limit_rule.dart';
import '../../state/pin_gate.dart';
import '../../state/screen_time_providers.dart';
import '../pin/pin_screen.dart';
import 'blocking_banner.dart';

class LimitsScreen extends ConsumerStatefulWidget {
  const LimitsScreen({super.key});

  @override
  ConsumerState<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends ConsumerState<LimitsScreen> {
  static const _step = Duration(minutes: 15);

  bool _byCategory = false;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(nativeUsageReportsProvider)) return const _IosLimits();
    final blockingOff = ref.watch(blockingOffProvider);
    return AsyncView(
      value: combineAsync(ref.watch(todayUsageProvider), ref.watch(rulesProvider)),
      builder: (context, data) {
        final (usage, rules) = data;
        final notifier = ref.read(rulesProvider.notifier);
        return ScreenScroll(
          children: [
            const ScreenHeader(
              title: 'Хязгаар',
              subtitle: 'Апп эсвэл ангилал бүрт өдрийн хязгаар тавих, хэрэггүй үед нь идэвхгүй болгох',
            ),
            if (blockingOff) const BlockingBanner(),
            SegmentedPills(
              options: const [(false, 'Апп'), (true, 'Ангилал')],
              selected: _byCategory,
              onChanged: (v) => setState(() => _byCategory = v),
              background: AppColors.segmentStrong,
            ),
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _byCategory ? 'Ангилал ба өдрийн хязгаар' : 'Апп ба өдрийн хязгаар',
                            style: AppText.label,
                          ),
                        ),
                        const Text('Идэвхгүй', style: AppText.label),
                      ],
                    ),
                  ),
                  if (_byCategory)
                    for (final category in AppCategory.values)
                      _RuleRow(
                        leading: IconTile(
                          icon: category.icon,
                          color: rules.forCategory(category).blocked ? AppColors.inactive : category.tileColor,
                        ),
                        title: category.label,
                        subtitle: '${formatDuration(usage.screenTimeIn(category))} · '
                            '${usage.apps.where((a) => a.category == category).map((a) => a.name).join(', ')}',
                        rule: rules.forCategory(category),
                        used: usage.screenTimeIn(category),
                        blockedNote: 'Энэ ангиллын бүх апп хаалттай',
                        onToggleBlocked: () => notifier.toggleCategoryBlocked(category),
                        onStep: (sign) => notifier.stepCategoryLimit(category, _step * sign),
                      )
                  else
                    for (final app in usage.apps)
                      _RuleRow(
                        leading: AppTile(appId: app.appId, name: app.name, icon: app.icon, dimmed: rules.forApp(app.appId).blocked),
                        title: app.name,
                        subtitle: 'Өнөөдөр ${formatDuration(app.screenTime)} · ${app.opens} удаа нээсэн',
                        rule: rules.forApp(app.appId),
                        used: app.screenTime,
                        blockedNote: 'Хаалттай — дахин асаах хүртэл нээгдэхгүй',
                        onToggleBlocked: () => notifier.toggleAppBlocked(app.appId),
                        onStep: (sign) => notifier.stepAppLimit(app.appId, _step * sign),
                      ),
                ],
              ),
            ),
            _TotalLimitCard(used: usage.total, limit: rules.totalDailyLimit),
            _PinCard(enabled: rules.pinEnabled),
          ],
        );
      },
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.rule,
    required this.used,
    required this.blockedNote,
    required this.onToggleBlocked,
    required this.onStep,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final LimitRule rule;
  final Duration used;
  final String blockedNote;
  final VoidCallback onToggleBlocked;

  /// Called with -1 or 1.
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final limit = rule.dailyLimit;
    final left = rule.remaining(used);
    final near = rule.isNear(used);
    final statusColor = near ? AppColors.warmText : AppColors.muted;

    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            MergeSemantics(
              child: Row(
                spacing: 12,
                children: [
                  leading,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(title, style: AppText.rowTitle),
                        Text(subtitle, style: AppText.caption),
                      ],
                    ),
                  ),
                  Switch(value: rule.blocked, onChanged: (_) => onToggleBlocked(), activeTrackColor: AppColors.ink),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: rule.blocked
                  ? Text(blockedNote, style: AppText.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        ProgressTrack(
                          value: rule.usedFraction(used) ?? 0,
                          color: near ? AppColors.warm : AppColors.accent,
                        ),
                        Row(
                          spacing: 4,
                          children: [
                            Expanded(
                              child: Text(
                                switch (left) {
                                  null => 'Хязгааргүй',
                                  Duration.zero => 'Хязгаарт хүрсэн',
                                  final rest => '${formatMinutes(rest)} үлдсэн',
                                },
                                style: AppText.caption.copyWith(fontWeight: FontWeight.w600, color: statusColor),
                              ),
                            ),
                            RoundIconButton(
                              icon: Icons.remove_rounded,
                              tooltip: '$title хязгаарыг 15 минутаар багасгах',
                              onPressed: limit == null ? null : () => onStep(-1),
                              filled: true,
                            ),
                            SizedBox(
                              width: 84,
                              child: Text(
                                limit == null ? 'Хязгааргүй' : formatDuration(limit),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                            RoundIconButton(
                              icon: Icons.add_rounded,
                              tooltip: '$title хязгаарыг 15 минутаар нэмэх',
                              onPressed: () => onStep(1),
                              filled: true,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalLimitCard extends ConsumerWidget {
  const _TotalLimitCard({required this.used, required this.limit});

  static const _step = Duration(minutes: 30);

  final Duration used;
  final Duration? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = this.limit;
    final left = limit == null ? null : limit - used;
    final notifier = ref.read(rulesProvider.notifier);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Өдрийн нийт хязгаар', style: AppText.cardTitle)),
              Text(limit == null ? 'Хязгааргүй' : formatDuration(limit), style: AppText.numeric(18)),
            ],
          ),
          if (limit != null && left != null) ...[
            ProgressTrack(
              value: used.inSeconds / limit.inSeconds,
              height: 8,
              color: left <= const Duration(minutes: 30) ? AppColors.warm : AppColors.accent,
            ),
            Text(
              left.isNegative
                  ? '${formatDuration(used)} ашигласан · хязгаараас ${formatDuration(-left)} хэтэрсэн'
                  : '${formatDuration(used)} ашигласан · ${formatDuration(left)} үлдсэн',
              style: AppText.caption,
            ),
          ],
          StepperBar(
            caption: '30 минутаар өөрчлөх',
            onDecrement: () => notifier.stepTotalDailyLimit(-_step),
            onIncrement: () => notifier.stepTotalDailyLimit(_step),
            decrementTooltip: 'Нийт хязгаарыг 30 минутаар багасгах',
            incrementTooltip: 'Нийт хязгаарыг 30 минутаар нэмэх',
          ),
        ],
      ),
    );
  }
}

class _PinCard extends ConsumerWidget {
  const _PinCard({required this.enabled});

  final bool enabled;

  /// A new PIN is set up each time protection goes on.
  Future<void> _turnOn(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PinSetupScreen()),
    );
    if (created == true) await ref.read(rulesProvider.notifier).setPinEnabled(true);
  }

  Future<void> _turnOff(WidgetRef ref) async {
    if (await ref.read(rulesProvider.notifier).setPinEnabled(false)) await ref.read(pinStoreProvider).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A switch turned on before PINs existed has no PIN behind it: show it off.
    final on = enabled && ref.watch(pinStoreProvider).hasPin;
    return SectionCard(
      child: MergeSemantics(
        child: Row(
          spacing: 12,
          children: [
            const IconTile(icon: Icons.lock_outline_rounded, color: AppColors.ink),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text('PIN кодоор хамгаалах', style: AppText.cardTitle),
                  Text('Хаалт унтраах, хязгаар нэмэхэд PIN асууна', style: AppText.caption),
                ],
              ),
            ),
            Switch(value: on, onChanged: (v) => v ? _turnOn(context, ref) : _turnOff(ref)),
          ],
        ),
      ),
    );
  }
}

/// iOS: Dart never sees usage or app names there, so instead of listing
/// today's apps the tab lists picks from Apple's picker. Each pick can be
/// blocked or given a shared daily limit; Screen Time enforces both.
class _IosLimits extends ConsumerWidget {
  const _IosLimits();

  Future<void> _add(WidgetRef ref) async {
    final id = '${AppSelection.limitPrefix}${DateTime.now().microsecondsSinceEpoch}';
    await ref.read(selectionsProvider.notifier).pick(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: combineAsync(ref.watch(selectionsProvider), ref.watch(rulesProvider)),
      builder: (context, data) {
        final (selections, rules) = data;
        final picks = selections.where((s) => s.id.startsWith(AppSelection.limitPrefix)).toList();
        return ScreenScroll(
          children: [
            const ScreenHeader(
              title: 'Хязгаар',
              subtitle: 'Аппуудаа сонгоод өдрийн хязгаар тавих эсвэл бүр хаах',
            ),
            if (picks.isEmpty)
              const SectionCard(
                child: Text(
                  'Хязгаарлах аппуудаа сонгоно уу. Нэг дор сонгосон аппууд өдрийн хязгаараа хамтдаа хуваана.',
                  style: AppText.body,
                ),
              ),
            for (final pick in picks) _IosPickCard(pick: pick, rule: rules.forApp(pick.id)),
            OutlinedButton.icon(
              onPressed: () => _add(ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Апп сонгох'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.inactive, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(fontFamily: 'Onest', fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            _PinCard(enabled: rules.pinEnabled),
          ],
        );
      },
    );
  }
}

class _IosPickCard extends ConsumerWidget {
  const _IosPickCard({required this.pick, required this.rule});

  static const _step = Duration(minutes: 15);

  final AppSelection pick;
  final LimitRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.read(rulesProvider.notifier);
    final limit = rule.dailyLimit;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => ref.read(selectionsProvider.notifier).pick(pick.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    spacing: 12,
                    children: [
                      IconTile(icon: Icons.apps_rounded, color: rule.blocked ? AppColors.inactive : AppColors.accent),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(pick.label, style: AppText.rowTitle),
                            Text(
                              rule.blocked ? 'Хаалттай — дахин асаах хүртэл нээгдэхгүй' : 'Дарж аппуудаа өөрчлөх',
                              style: AppText.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Semantics(
                label: '${pick.label} хаах',
                child: Switch(
                  value: rule.blocked,
                  onChanged: (_) => rules.toggleAppBlocked(pick.id),
                  activeTrackColor: AppColors.ink,
                ),
              ),
            ],
          ),
          if (!rule.blocked) ...[
            StepperRow(
              label: 'Өдрийн хязгаар',
              value: limit == null ? 'Хязгааргүй' : formatDuration(limit),
              onDecrement: limit == null ? null : () => rules.stepAppLimit(pick.id, -_step),
              onIncrement: () => rules.stepAppLimit(pick.id, _step),
              decrementTooltip: 'Хязгаарыг 15 минутаар багасгах',
              incrementTooltip: 'Хязгаарыг 15 минутаар нэмэх',
            ),
            if (limit != null)
              SegmentedPills(
                options: const [(LimitAction.warn, 'Сануулах'), (LimitAction.block, 'Хаах')],
                selected: rule.onLimit,
                onChanged: (a) => rules.setAppRule(pick.id, rule.copyWith(onLimit: a)),
              ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                if (await rules.removeApp(pick.id)) await ref.read(selectionsProvider.notifier).remove(pick.id);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Устгах'),
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

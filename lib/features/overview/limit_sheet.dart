import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/tiles.dart';
import '../../data/models/app_usage.dart';
import '../../data/models/limit_rule.dart';
import '../../state/screen_time_providers.dart';

Future<void> showLimitSheet(BuildContext context, AppUsage app) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => LimitSheet(app: app),
    );

/// Edits one app's limit as a draft; nothing changes until "Хадгалах".
class LimitSheet extends ConsumerStatefulWidget {
  const LimitSheet({super.key, required this.app});

  final AppUsage app;

  @override
  ConsumerState<LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends ConsumerState<LimitSheet> {
  static const _presets = <Duration?>[
    null,
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
  ];
  static const _step = Duration(minutes: 15);

  late LimitRule _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(rulesProvider).requireValue.forApp(widget.app.appId);
  }

  void _edit(LimitRule Function(LimitRule) change) => setState(() => _draft = change(_draft));

  Future<void> _save() async {
    await ref.read(rulesProvider.notifier).setAppRule(widget.app.appId, _draft);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final used = app.screenTime;
    final limit = _draft.dailyLimit;
    final left = _draft.remaining(used);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 18,
        children: [
          Row(
            spacing: 12,
            children: [
              AppTile(appId: app.appId, name: app.name, icon: app.icon, size: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(app.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(
                      'Өнөөдөр ${formatDuration(used)} · ${app.opens} удаа · ${app.notifications} мэдэгдэл',
                      style: AppText.caption.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Хаах',
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.segment, foregroundColor: AppColors.ink),
              ),
            ],
          ),
          SwitchListTile(
            value: _draft.blocked,
            onChanged: (v) => _edit((r) => r.copyWith(blocked: v)),
            title: const Text('Идэвхгүй болгох', style: AppText.rowTitle),
            subtitle: const Text('Асаасан үед апп нээгдэхгүй', style: AppText.caption),
            activeTrackColor: AppColors.ink,
            tileColor: AppColors.surfaceMuted,
            contentPadding: const EdgeInsets.only(left: 16, right: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          if (_draft.blocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: AppColors.warmSurface, borderRadius: BorderRadius.circular(18)),
              child: Text(
                'Та дахин асаах хүртэл ${app.name} нээгдэхгүй, мэдэгдэл ирэхгүй.',
                style: AppText.body.copyWith(fontSize: 13, color: AppColors.warmInk),
              ),
            )
          else ...[
            Row(
              children: [
                const Expanded(child: Text('Өдрийн хязгаар', style: AppText.rowTitle)),
                Text(limit == null ? 'Хязгааргүй' : formatDuration(limit), style: AppText.numeric(16)),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ChoicePill(
                    label: preset == null ? 'Хязгааргүй' : formatDuration(preset),
                    selected: limit == preset,
                    onTap: () => _edit((r) => r.copyWith(dailyLimit: () => preset)),
                  ),
              ],
            ),
            StepperBar(
              caption: '15 минутаар өөрчлөх',
              onDecrement: limit == null ? null : () => _edit((r) => r.stepLimit(-_step)),
              onIncrement: () => _edit((r) => r.stepLimit(_step)),
              decrementTooltip: '15 минутаар багасгах',
              incrementTooltip: '15 минутаар нэмэх',
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                ProgressTrack(
                  value: _draft.usedFraction(used) ?? 0,
                  height: 8,
                  color: _draft.isNear(used) ? AppColors.warm : AppColors.accent,
                ),
                Text(
                  switch (left) {
                    null => 'Хязгааргүй — зөвхөн хугацааг тоолно',
                    Duration.zero => 'Өнөөдрийн хязгаарт хүрсэн',
                    final rest => '${formatDuration(used)} ашигласан · ${formatMinutes(rest)} үлдсэн',
                  },
                  style: AppText.caption,
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text('Хязгаарт хүрэхэд', style: AppText.rowTitle)),
                SegmentedPills(
                  expand: false,
                  options: const [(LimitAction.warn, 'Сануулах'), (LimitAction.block, 'Хаах')],
                  selected: _draft.onLimit,
                  onChanged: (a) => _edit((r) => r.copyWith(onLimit: a)),
                ),
              ],
            ),
          ],
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.segment, foregroundColor: AppColors.ink),
                  child: const Text('Болих'),
                ),
              ),
              Expanded(child: FilledButton(onPressed: _save, child: const Text('Хадгалах'))),
            ],
          ),
        ],
      ),
    );
  }
}

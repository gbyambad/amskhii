import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/native_usage_report.dart';
import '../../core/widgets/tiles.dart';
import '../../data/models/app_usage.dart';
import '../../data/models/limit_rule.dart';
import '../../state/screen_time_providers.dart';
import 'limit_sheet.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(nativeUsageReportsProvider)) return const NativeUsageReport(UsageReport.today);
    return AsyncView(
      value: combineAsync(ref.watch(todayUsageProvider), ref.watch(rulesProvider)),
      builder: (context, data) {
        final (usage, rules) = data;
        final nearLimit = <(AppUsage, Duration)>[];
        for (final app in usage.apps) {
          final rule = rules.forApp(app.appId);
          final left = rule.remaining(app.screenTime);
          if (left != null && left > Duration.zero && rule.isNear(app.screenTime)) nearLimit.add((app, left));
        }
        return ScreenScroll(
          onRefresh: () => ref.refresh(todayUsageProvider.future),
          children: [
            ScreenHeader(caption: formatDate(usage.asOf), title: 'Дэлгэцийн цаг'),
            if (nearLimit.isNotEmpty) _NearLimitBanner(items: nearLimit),
            _TodayCard(usage: usage),
            _PickupsCard(usage: usage),
            _AppListCard(usage: usage, rules: rules),
          ],
        );
      },
    );
  }
}

class _NearLimitBanner extends StatelessWidget {
  const _NearLimitBanner({required this.items});

  final List<(AppUsage, Duration)> items;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.warmSurface, borderRadius: BorderRadius.circular(20)),
        child: Row(
          spacing: 12,
          children: [
            const IconTile(icon: Icons.hourglass_bottom_rounded, color: AppColors.warm, size: 36),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    '${items.length} апп хязгаартаа ойртож байна',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warmInk),
                  ),
                  Text(
                    items.map((e) => '${e.$1.name} · ${formatMinutes(e.$2)} үлдсэн').join(', '),
                    style: AppText.caption.copyWith(color: AppColors.warmInk),
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

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.usage});

  final DayUsage usage;

  @override
  Widget build(BuildContext context) {
    final diff = usage.total - usage.previousDayTotal;
    final peak = usage.peakUsageHour;
    final peakText = '${formatHour(peak)}–${formatHour(peak + 1)} · ${formatMinutes(usage.hourlyScreenTime[peak])}';
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    const Text('Өнөөдөр нийт', style: AppText.label),
                    Text(formatDuration(usage.total), style: AppText.numeric(36)),
                  ],
                ),
              ),
              // No history yesterday (new install, new phone): nothing to compare.
              if (usage.previousDayTotal > Duration.zero)
                StatChip(
                  icon: diff.isNegative ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  label: '${formatMinutes(diff.abs())} өчигдрөөс',
                ),
            ],
          ),
          HourlyBarChart(
            values: [for (final d in usage.hourlyScreenTime) d.inSeconds],
            currentHour: usage.currentHour,
            colorFor: (_) => AppColors.accent,
            height: 80,
            semanticsLabel: 'Цаг тутмын ашиглалт. Хамгийн их нь $peakText',
          ),
          Text('Хамгийн их: $peakText', style: AppText.caption),
        ],
      ),
    );
  }
}

class _PickupsCard extends StatefulWidget {
  const _PickupsCard({required this.usage});

  final DayUsage usage;

  @override
  State<_PickupsCard> createState() => _PickupsCardState();
}

class _PickupsCardState extends State<_PickupsCard> {
  int _start = 9;
  int _end = 17;

  @override
  Widget build(BuildContext context) {
    final usage = widget.usage;
    final count = usage.pickupsBetween(_start, _end);
    final span = '${formatHour(_start)}–${formatHour(_end)}';
    final peak = usage.peakPickupHour;
    final lastPickupAt = usage.lastPickupAt;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    const Text('Утсаа шалгасан', style: AppText.label),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${usage.pickups}', style: AppText.numeric(36)),
                          const TextSpan(text: '  удаа', style: AppText.body),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (lastPickupAt != null)
                StatChip(
                  label: 'Сүүлд ${formatAgo(usage.asOf.difference(lastPickupAt)).toLowerCase()}',
                  background: AppColors.warmSurface,
                  foreground: AppColors.warmText,
                ),
            ],
          ),
          const Text('Хэдээс хэдийн хооронд', style: AppText.rowTitle),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                StepperRow(
                  label: 'Эхлэх',
                  value: formatHour(_start),
                  onDecrement: _start > 0 ? () => setState(() => _start--) : null,
                  onIncrement: _start < _end - 1 ? () => setState(() => _start++) : null,
                  decrementTooltip: 'Эхлэх цагийг 1 цагаар багасгах',
                  incrementTooltip: 'Эхлэх цагийг 1 цагаар нэмэх',
                ),
                const Divider(color: AppColors.line),
                StepperRow(
                  label: 'Дуусах',
                  value: formatHour(_end),
                  onDecrement: _end > _start + 1 ? () => setState(() => _end--) : null,
                  onIncrement: _end < 24 ? () => setState(() => _end++) : null,
                  decrementTooltip: 'Дуусах цагийг 1 цагаар багасгах',
                  incrementTooltip: 'Дуусах цагийг 1 цагаар нэмэх',
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 6,
            children: [
              Text('$count', style: AppText.numeric(26, color: AppColors.warmText)),
              Expanded(child: Text('удаа · $span', style: AppText.caption.copyWith(fontSize: 13))),
              Text('цагт дунджаар ${(count / (_end - _start)).round()}', style: AppText.caption),
            ],
          ),
          HourlyBarChart(
            values: usage.hourlyPickups,
            currentHour: usage.currentHour,
            colorFor: (h) => h >= _start && h < _end ? AppColors.warm : AppColors.idleBar,
            height: 56,
            semanticsLabel: 'Цаг тутам утсаа шалгасан тоо, $span хооронд $count удаа',
          ),
          Text(
            'Хамгийн их: ${formatHour(peak)}–${formatHour(peak + 1)} · ${usage.hourlyPickups[peak]} удаа',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

enum _Metric {
  time('Цаг', 'Хамгийн их ашигласан'),
  opens('Нээсэн', 'Хамгийн олон нээсэн'),
  notifications('Мэдэгдэл', 'Хамгийн их мэдэгдэл'),
  data('Дата', 'Хамгийн их дата');

  const _Metric(this.label, this.title);

  final String label;
  final String title;

  num valueOf(AppUsage app) => switch (this) {
        _Metric.time => app.screenTime.inSeconds,
        _Metric.opens => app.opens,
        _Metric.notifications => app.notifications,
        _Metric.data => app.dataBytes,
      };

  String format(AppUsage app) => switch (this) {
        _Metric.time => formatDuration(app.screenTime),
        _Metric.opens => '${app.opens} удаа',
        _Metric.notifications => '${app.notifications} мэдэгдэл',
        _Metric.data => formatDataSize(app.dataBytes),
      };

  String total(List<AppUsage> apps) => switch (this) {
        _Metric.time => 'Нийт ${formatDuration(apps.fold(Duration.zero, (s, a) => s + a.screenTime))}',
        _Metric.opens => 'Нийт ${apps.fold(0, (s, a) => s + a.opens)} удаа',
        _Metric.notifications => 'Нийт ${apps.fold(0, (s, a) => s + a.notifications)}',
        _Metric.data => 'Нийт ${formatDataSize(apps.fold(0, (s, a) => s + a.dataBytes))}',
      };
}

class _AppListCard extends StatefulWidget {
  const _AppListCard({required this.usage, required this.rules});

  final DayUsage usage;
  final ScreenTimeRules rules;

  @override
  State<_AppListCard> createState() => _AppListCardState();
}

class _AppListCardState extends State<_AppListCard> {
  _Metric _metric = _Metric.time;

  @override
  Widget build(BuildContext context) {
    final apps = [...widget.usage.apps]..sort((a, b) => _metric.valueOf(b).compareTo(_metric.valueOf(a)));
    final maxValue = apps.isEmpty ? 1 : _metric.valueOf(apps.first);

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_metric.title, style: AppText.cardTitle)),
                    Text(_metric.total(apps), style: AppText.caption),
                  ],
                ),
                SegmentedPills(
                  options: [for (final m in _Metric.values) (m, m.label)],
                  selected: _metric,
                  onChanged: (m) => setState(() => _metric = m),
                ),
                const Text('Аппаа сонгоод хязгаар тавих эсвэл идэвхгүй болгох', style: AppText.caption),
              ],
            ),
          ),
          if (apps.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Text('Өнөөдөр ашигласан апп алга байна.', style: AppText.body),
            ),
          for (final app in apps)
            _AppUsageRow(
              app: app,
              rule: widget.rules.forApp(app.appId),
              metric: _metric,
              share: maxValue == 0 ? 0 : _metric.valueOf(app) / maxValue,
            ),
        ],
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({required this.app, required this.rule, required this.metric, required this.share});

  final AppUsage app;
  final LimitRule rule;
  final _Metric metric;

  /// This app's value relative to the top app for [metric].
  final double share;

  @override
  Widget build(BuildContext context) {
    final used = app.screenTime;
    final left = rule.remaining(used);
    final near = rule.isNear(used);

    var status = 'Хязгааргүй';
    if (rule.blocked) {
      status = 'Хаалттай';
    } else if (left != null) {
      final limit = formatDuration(rule.dailyLimit!);
      status = left > Duration.zero ? 'Хязгаар $limit · ${formatMinutes(left)} үлдсэн' : 'Хязгаарт хүрсэн · $limit';
    }
    if (metric != _Metric.time) status = '${formatDuration(used)} · $status';

    final limitBar = metric == _Metric.time && !rule.blocked && rule.dailyLimit != null;
    final barColor = rule.blocked
        ? AppColors.inactive
        : limitBar && near
            ? AppColors.warm
            : AppColors.accent;

    return InkWell(
      onTap: () => showLimitSheet(context, app),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
        child: Row(
          spacing: 12,
          children: [
            AppTile(appId: app.appId, name: app.name, icon: app.icon, dimmed: rule.blocked),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      // One text run, so a narrow row ellipsizes instead of overflowing.
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: app.name),
                              if (rule.blocked)
                                const WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(padding: EdgeInsets.only(left: 6), child: TagLabel('Идэвхгүй')),
                                ),
                            ],
                          ),
                          style: AppText.rowTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(metric.format(app), style: AppText.rowTitle.copyWith(fontSize: 14)),
                    ],
                  ),
                  ProgressTrack(value: limitBar ? rule.usedFraction(used)! : share, color: barColor),
                  Text(
                    status,
                    style: AppText.caption.copyWith(color: near ? AppColors.warmText : AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inactive),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_visuals.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/native_usage_report.dart';
import '../../core/widgets/tiles.dart';
import '../../data/models/week_report.dart';
import '../../state/screen_time_providers.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  /// Index into the week; `null` follows today.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(nativeUsageReportsProvider)) return const NativeUsageReport(UsageReport.week);
    return AsyncView(
      value: combineAsync(ref.watch(weekReportProvider), ref.watch(rulesProvider)),
      builder: (context, data) {
        final (report, rules) = data;
        final limit = rules.totalDailyLimit;
        final hasUsage = report.total > Duration.zero;
        return ScreenScroll(
          onRefresh: () => ref.refresh(weekReportProvider.future),
          children: [
            ScreenHeader(caption: _rangeLabel(report), title: '7 хоногийн тайлан'),
            _AverageCard(
              report: report,
              limit: limit,
              selected: _selected ?? report.days.length - 1,
              onSelect: (i) => setState(() => _selected = i),
            ),
            if (limit != null) _StreakCard(report: report, limit: limit),
            if (hasUsage) _CategoryCard(report: report),
            if (report.topApps.isNotEmpty) _TopAppsCard(report: report),
          ],
        );
      },
    );
  }

  static String _rangeLabel(WeekReport report) {
    final first = report.days.first.date;
    final last = report.days.last.date;
    return first.month == last.month
        ? '${first.month}-р сарын ${first.day}–${last.day}'
        : '${first.month}-р сарын ${first.day} – ${last.month}-р сарын ${last.day}';
  }
}

String _dayLabel(WeekReport report, int index) {
  final date = report.days[index].date;
  final name = index == report.days.length - 1 ? 'Өнөөдөр' : weekdayName(date.weekday);
  return '$name, ${formatShortDate(date)}';
}

class _AverageCard extends StatelessWidget {
  const _AverageCard({required this.report, required this.limit, required this.selected, required this.onSelect});

  final WeekReport report;
  final Duration? limit;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final change = report.changeVsPrevious;
    final day = report.days[selected];
    final busiest = report.mostPickupsDay;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              const Text('Өдрийн дундаж', style: AppText.label),
              Text(formatDuration(report.dailyAverage), style: AppText.numeric(36)),
              if (change != null)
                StatChip(
                  icon: change.isNegative ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  label: 'Өмнөх 7 хоногоос ${(change.abs() * 100).round()}% ${change.isNegative ? 'бага' : 'их'}',
                ),
            ],
          ),
          _WeekChart(report: report, limit: limit, selected: selected, onSelect: onSelect),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _dayLabel(report, selected),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                TextSpan(text: ' · ${formatDuration(day.screenTime)} · ${day.pickups} удаа шалгасан'),
              ],
            ),
            style: AppText.caption.copyWith(fontSize: 13),
          ),
          const Divider(),
          Text(
            'Өдөрт дунджаар ${report.averagePickups} удаа утсаа шалгасан · '
            'Хамгийн их: ${weekdayName(busiest.date.weekday)}, ${busiest.pickups}',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.report, required this.limit, required this.selected, required this.onSelect});

  static const _barArea = 136.0;
  static const _labelArea = 24.0;

  final WeekReport report;
  final Duration? limit;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final limit = this.limit;
    final longest = report.days.map((d) => d.screenTime.inMinutes).fold(0, math.max);
    // Leave headroom so the tallest bar or the limit line sits below the top.
    final scale = math.max(math.max(longest, limit?.inMinutes ?? 0), 1) / 0.92;
    final limitY = limit == null ? null : _labelArea + limit.inMinutes / scale * _barArea;

    return SizedBox(
      height: _barArea + _labelArea,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              for (var i = 0; i < report.days.length; i++)
                Expanded(child: _dayBar(i, report.days[i], scale)),
            ],
          ),
          if (limitY != null) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: limitY,
              child: const IgnorePointer(child: CustomPaint(size: Size(double.infinity, 1.5), painter: _DashPainter())),
            ),
            Positioned(
              right: 0,
              bottom: limitY + 4,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'Хязгаар ${formatDuration(limit!)}',
                    style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayBar(int index, DaySummary day, double scale) {
    final isSelected = index == selected;
    final over = limit != null && day.screenTime > limit!;
    final color = over ? AppColors.warm : AppColors.accent;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${_dayLabel(report, index)}: ${formatDuration(day.screenTime)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onSelect(index),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: day.screenTime.inMinutes / scale * _barArea,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(4)),
              ),
            ),
            SizedBox(
              height: _labelArea,
              child: Center(
                child: Text(
                  weekdayShort(day.date.weekday),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.muted
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 4, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.report, required this.limit});

  static const _goal = 7;

  final WeekReport report;
  final Duration limit;

  @override
  Widget build(BuildContext context) {
    final streak = report.streakWithin(limit);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Row(
            spacing: 14,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: AppColors.warmSurface, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.local_fire_department_outlined, color: AppColors.warm, size: 28),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$streak', style: AppText.numeric(24)),
                          // Onest: Unbounded has no "ө".
                          const TextSpan(text: ' өдөр', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Text('дараалан өдрийн хязгаараа (${formatDuration(limit)}) барьсан', style: AppText.body),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (final day in report.days)
                Expanded(child: _StreakDot(date: day.date, met: day.screenTime <= limit)),
            ],
          ),
          Column(
            spacing: 6,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      streak >= _goal ? '7 хоногийн зорилго биеллээ' : 'Дараагийн шат: $_goal өдөр',
                      style: AppText.caption,
                    ),
                  ),
                  Text('${math.min(streak, _goal)}/$_goal', style: AppText.caption),
                ],
              ),
              ProgressTrack(value: streak / _goal, height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakDot extends StatelessWidget {
  const _StreakDot({required this.date, required this.met});

  final DateTime date;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${weekdayName(date.weekday)}: ${met ? 'хязгаараа барьсан' : 'хязгаараас хэтэрсэн'}',
      excludeSemantics: true,
      child: Column(
        spacing: 6,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: met ? AppColors.accent : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: met ? AppColors.accent : AppColors.inactive, width: 2),
            ),
            child: met ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
          ),
          Text(weekdayShort(date.weekday), style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.report});

  final WeekReport report;

  @override
  Widget build(BuildContext context) {
    final total = report.total.inSeconds;
    final entries = report.byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    int percent(Duration d) => math.max(1, (d.inSeconds / total * 100).round());

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Ангиллаар', style: AppText.cardTitle)),
              Text('Нийт ${formatDuration(report.total)}', style: AppText.caption),
            ],
          ),
          Semantics(
            label: entries.map((e) => '${e.key.label} ${percent(e.value)}%').join(', '),
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                height: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 2,
                  children: [
                    for (final e in entries)
                      Expanded(flex: percent(e.value), child: ColoredBox(color: e.key.chartColor)),
                  ],
                ),
              ),
            ),
          ),
          for (final e in entries)
            Row(
              spacing: 10,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: e.key.chartColor, shape: BoxShape.circle),
                ),
                Expanded(child: Text(e.key.label, style: AppText.rowTitle.copyWith(fontSize: 14))),
                Text(formatDuration(e.value), style: AppText.rowTitle.copyWith(fontSize: 13)),
                SizedBox(
                  width: 40,
                  child: Text('${percent(e.value)}%', textAlign: TextAlign.right, style: AppText.caption),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard({required this.report});

  final WeekReport report;

  @override
  Widget build(BuildContext context) {
    final days = report.days.length;
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Text('Энэ 7 хоногт', style: AppText.cardTitle),
          ),
          for (final app in report.topApps)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                spacing: 12,
                children: [
                  AppTile(appId: app.appId, name: app.name, icon: app.icon, size: 36),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(app.name, style: AppText.rowTitle),
                        Text('Өдөрт дунджаар ${formatDuration(app.screenTime ~/ days)}', style: AppText.caption),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 2,
                    children: [
                      Text(formatDuration(app.screenTime), style: AppText.rowTitle.copyWith(fontSize: 14)),
                      if (app.change case final change?)
                        Text(
                          '${formatChange(change)} өмнөхөөс',
                          style: AppText.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: change > 0 ? AppColors.warmText : AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

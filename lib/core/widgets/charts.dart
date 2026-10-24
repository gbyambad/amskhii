import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value, this.color = AppColors.accent, this.height = 6});

  /// 0..1; values outside are clamped.
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(color: AppColors.track, borderRadius: radius),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: radius)),
        ),
      ),
    );
  }
}

/// A row of bottom-aligned bars filling the available height.
class UsageBars extends StatelessWidget {
  const UsageBars({super.key, required this.fractions, required this.colors, this.gap = 3})
      : assert(fractions.length == colors.length);

  /// Bar heights as 0..1 of the available height.
  final List<double> fractions;
  final List<Color> colors;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: gap,
        children: [
          for (var i = 0; i < fractions.length; i++)
            Expanded(
              child: Container(
                height: math.max(3, fractions[i].clamp(0.0, 1.0) * constraints.maxHeight),
                decoration: BoxDecoration(color: colors[i], borderRadius: BorderRadius.circular(3)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 24 hourly bars with a 00–24 axis; hours after [currentHour] stay empty.
class HourlyBarChart extends StatelessWidget {
  const HourlyBarChart({
    super.key,
    required this.values,
    required this.currentHour,
    required this.colorFor,
    required this.semanticsLabel,
    this.height = 64,
  });

  final List<num> values;
  final int currentHour;
  final Color Function(int hour) colorFor;
  final String semanticsLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<num>(0, math.max);
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          spacing: 6,
          children: [
            SizedBox(
              height: height,
              child: UsageBars(
                fractions: [
                  for (var h = 0; h < values.length; h++)
                    h > currentHour || maxValue == 0 ? 0 : values[h] / maxValue,
                ],
                colors: [
                  for (var h = 0; h < values.length; h++)
                    h > currentHour || values[h] == 0 ? AppColors.line : colorFor(h),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final label in const ['00', '06', '12', '18', '24'])
                  Text(label, style: AppText.caption.copyWith(fontSize: 11, color: AppColors.faint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

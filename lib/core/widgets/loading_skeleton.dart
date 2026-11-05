import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

import '../theme/app_colors.dart';

/// Shown while a screen loads: grey blocks in the shape of a screen header
/// and cards, with a shimmer passing over them.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ачаалж байна',
      child: ExcludeSemantics(
        child: Shimmer(
          // Holds still for people who turned animations off.
          enabled: !MediaQuery.disableAnimationsOf(context),
          duration: const Duration(milliseconds: 1600),
          colorOpacity: 0.7,
          child: SafeArea(
            bottom: false,
            // Same gutters and gaps as ScreenScroll; a list so short screens clip instead of overflowing.
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      _Bar(width: 150, height: 28, color: AppColors.segmentStrong),
                      _Bar(width: 250, height: 14, color: AppColors.segmentStrong),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                _SummaryCard(),
                SizedBox(height: 16),
                _RowsCard(),
                SizedBox(height: 16),
                _RowsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Like a total-and-chart card.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          _Bar(width: 90, height: 12),
          _Bar(width: 130, height: 34),
          SizedBox(height: 4),
          _Bar(height: 88),
        ],
      ),
    );
  }
}

/// Like a card of app rows.
class _RowsCard extends StatelessWidget {
  const _RowsCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        spacing: 18,
        children: [_Row(), _Row()],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row();

  @override
  Widget build(BuildContext context) {
    return const Row(
      spacing: 12,
      children: [
        _Bar(width: 40, height: 40, radius: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              _Bar(width: 120, height: 14),
              _Bar(width: 180, height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({this.width, required this.height, this.radius = 8, this.color = AppColors.track});

  /// `null` fills the width.
  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

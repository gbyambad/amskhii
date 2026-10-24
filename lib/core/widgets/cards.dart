import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Scrolling page body with the design's 16px gutters and gaps.
class ScreenScroll extends StatelessWidget {
  const ScreenScroll({super.key, required this.children, this.onRefresh});

  final List<Widget> children;

  /// Enables pull-to-refresh.
  final RefreshCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      itemCount: children.length,
      itemBuilder: (_, i) => children[i],
      separatorBuilder: (_, _) => const SizedBox(height: 16),
    );
    final onRefresh = this.onRefresh;
    return SafeArea(
      bottom: false,
      child: onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh, child: list),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.caption, this.subtitle});

  final String title;
  final String? caption;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          if (caption case final caption?) Text(caption, style: AppText.body.copyWith(fontSize: 13)),
          Semantics(header: true, child: Text(title, style: AppText.screenTitle)),
          if (subtitle case final subtitle?) Text(subtitle, style: AppText.body),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    this.icon,
    this.background = AppColors.segment,
    this.foreground = AppColors.ink,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (icon case final icon?) Icon(icon, size: 14, color: foreground),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dark label, e.g. "Идэвхгүй" next to a blocked app.
class TagLabel extends StatelessWidget {
  const TagLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

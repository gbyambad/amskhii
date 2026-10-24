import 'package:flutter/material.dart';

import '../data/models/app_usage.dart';
import '../data/models/block_schedule.dart';
import 'theme/app_colors.dart';

const _knownTiles = {
  'com.facebook.katana': Color(0xFF2B3A67),
  'com.zhiliaoapp.musically': Color(0xFF2A2E38),
  'com.google.android.youtube': Color(0xFF7A2E1F),
  'com.facebook.orca': Color(0xFF3D2F6B),
  'com.instagram.android': Color(0xFF6B2F4F),
  'com.android.chrome': Color(0xFF2F5A4A),
};

const _fallbackTiles = [Color(0xFF2B3A67), Color(0xFF3D2F6B), Color(0xFF2F5A4A), Color(0xFF7A2E1F), Color(0xFF6B2F4F)];

/// Placeholder tile colour until real icons come from the platform.
Color appTileColor(String appId) => _knownTiles[appId] ?? _fallbackTiles[appId.hashCode.abs() % _fallbackTiles.length];

extension AppCategoryVisuals on AppCategory {
  String get label => switch (this) {
        AppCategory.social => 'Сошиал',
        AppCategory.video => 'Видео',
        AppCategory.chat => 'Чат',
        AppCategory.other => 'Бусад',
      };

  IconData get icon => switch (this) {
        AppCategory.social => Icons.people_outline_rounded,
        AppCategory.video => Icons.play_arrow_rounded,
        AppCategory.chat => Icons.chat_bubble_outline_rounded,
        AppCategory.other => Icons.public_rounded,
      };

  /// Background behind a white icon.
  Color get tileColor => switch (this) {
        AppCategory.social => AppColors.warmText,
        AppCategory.video => AppColors.accent,
        AppCategory.chat => const Color(0xFF5B4BB7),
        AppCategory.other => AppColors.faint,
      };

  /// Chart series colour; the four differ in lightness, not hue alone.
  Color get chartColor => switch (this) {
        AppCategory.video => AppColors.accent,
        AppCategory.social => AppColors.warm,
        AppCategory.chat => AppColors.chat,
        AppCategory.other => AppColors.idleBar,
      };
}

extension ScheduleKindVisuals on ScheduleKind {
  IconData get icon => switch (this) {
        ScheduleKind.bedtime => Icons.bedtime_outlined,
        ScheduleKind.work => Icons.work_outline_rounded,
        ScheduleKind.family => Icons.home_outlined,
        ScheduleKind.custom => Icons.schedule_rounded,
      };

  Color get tileColor => switch (this) {
        ScheduleKind.bedtime => AppColors.night,
        ScheduleKind.work => const Color(0xFF2F5A4A),
        ScheduleKind.family => AppColors.warmText,
        ScheduleKind.custom => AppColors.accent,
      };
}

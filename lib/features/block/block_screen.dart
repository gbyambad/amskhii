import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_visuals.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tiles.dart';
import '../../data/models/app_usage.dart';

enum BlockKind { appBlocked, categoryBlocked, schedule, appLimit, categoryLimit, totalLimit }

/// Why Android's `BlockingService` stopped an app.
@immutable
class BlockReason {
  const BlockReason({
    required this.appName,
    required this.kind,
    this.warnOnly = false,
    this.category,
    this.limit,
    this.scheduleName,
    this.startMinute,
    this.endMinute,
    this.allApps = false,
  });

  /// The JSON `BlockActivity.intent` sends:
  /// ```
  /// {appId, appName, warnOnly, kind, category?, limitMinutes?,
  ///  scheduleName?, startMinute?, endMinute?, allApps?}
  /// ```
  factory BlockReason.fromJson(String raw) {
    final json = jsonDecode(raw) as Map<String, Object?>;
    final minutes = json['limitMinutes'] as int?;
    return BlockReason(
      appName: json['appName'] as String? ?? '',
      kind: BlockKind.values.asNameMap()[json['kind']] ?? BlockKind.appBlocked,
      warnOnly: json['warnOnly'] as bool? ?? false,
      category: AppCategory.values.asNameMap()[json['category']],
      limit: minutes == null ? null : Duration(minutes: minutes),
      scheduleName: json['scheduleName'] as String?,
      startMinute: json['startMinute'] as int?,
      endMinute: json['endMinute'] as int?,
      allApps: json['allApps'] as bool? ?? false,
    );
  }

  final String appName;
  final BlockKind kind;

  /// The limit is set to "Сануулах": say so once, then let the user carry on.
  final bool warnOnly;
  final AppCategory? category;
  final Duration? limit;
  final String? scheduleName;
  final int? startMinute;
  final int? endMinute;

  /// The schedule blocks every app except calls and messages.
  final bool allApps;

  String get title => switch (kind) {
        BlockKind.appLimit || BlockKind.categoryLimit => 'Өдрийн хязгаар дууслаа',
        BlockKind.totalLimit => 'Өнөөдрийн дэлгэцийн цаг дууслаа',
        BlockKind.appBlocked || BlockKind.categoryBlocked || BlockKind.schedule => '$appName хаалттай',
      };

  String get message {
    final limit = formatDuration(this.limit ?? Duration.zero);
    final label = category?.label ?? '';
    final tomorrow = warnOnly ? '' : ' Маргааш дахин нээгдэнэ.';
    return switch (kind) {
      BlockKind.appBlocked => 'Энэ аппыг Хязгаар хэсэгт хаасан байна. Дахин нээх бол тэндээс хаалтыг нь унтраана уу.',
      BlockKind.categoryBlocked => '«$label» ангиллын аппуудыг Хязгаар хэсэгт хаасан байна.',
      BlockKind.schedule => '«$scheduleName» хуваарийн дагуу '
          '${formatMinuteOfDay(startMinute ?? 0)}–${formatMinuteOfDay(endMinute ?? 0)} хооронд хаалттай.'
          '${allApps ? ' Дуудлага, мессеж нээлттэй.' : ''}',
      BlockKind.appLimit => '$appName-д өгсөн өдрийн $limit хязгаар дууссан.$tomorrow',
      BlockKind.categoryLimit => '«$label» ангилалд өгсөн өдрийн $limit хязгаар дууссан.$tomorrow',
      BlockKind.totalLimit => 'Өдрийн нийт $limit хязгаарт хүрлээ. Маргааш хүртэл дуудлага, мессеж л нээлттэй.',
    };
  }
}

/// Shown by Android's `BlockActivity`: instead of a blocked app, or over an
/// app whose "Сануулах" limit just ran out.
class BlockScreen extends StatelessWidget {
  const BlockScreen({super.key, required this.reason, this.channel = const MethodChannel('amskhii/block')});

  final BlockReason reason;
  final MethodChannel channel;

  /// Leaves for the home screen; the blocked app is never shown again from here.
  Future<void> _goHome() => channel.invokeMethod<void>('goHome');

  @override
  Widget build(BuildContext context) {
    final warn = reason.warnOnly;
    return PopScope(
      // Back carries on after a warning, but never returns to a blocked app.
      canPop: warn,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  icon: warn ? Icons.hourglass_bottom_rounded : Icons.lock_outline_rounded,
                  color: warn ? AppColors.warm : AppColors.accent,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(reason.title, style: AppText.screenTitle),
                const SizedBox(height: 12),
                Text(reason.message, style: AppText.body),
                const Spacer(),
                FilledButton(onPressed: _goHome, child: Text(warn ? 'Аппаас гарах' : 'Ойлголоо')),
                if (warn) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: SystemNavigator.pop,
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppColors.muted),
                    child: const Text('Үргэлжлүүлэх'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

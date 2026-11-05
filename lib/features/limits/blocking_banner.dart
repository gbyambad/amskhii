import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tiles.dart';
import '../../state/screen_time_providers.dart';

/// Tops the Limits and Schedule tabs while [blockingOffProvider] is true:
/// rules still save, but nothing stops the apps until the service is on.
class BlockingBanner extends ConsumerWidget {
  const BlockingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.warmSurface,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                const IconTile(icon: Icons.lock_open_rounded, color: AppColors.warm),
                Expanded(child: Text('Хаалт ажиллахгүй байна', style: AppText.rowTitle.copyWith(color: AppColors.warmInk))),
              ],
            ),
            Text(
              'Хязгаар, хуваарь ажиллахын тулд Тохиргоо → Хүртээмж (Accessibility) хэсэгт Амсхийг асаана уу. '
              'Амсхий зөвхөн аль апп нээгдсэнийг харна.',
              style: AppText.body.copyWith(color: AppColors.warmInk),
            ),
            FilledButton(
              onPressed: () => ref.read(screenTimeRepositoryProvider).requestBlockingAccess(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.warm),
              child: const Text('Тохиргоо нээх'),
            ),
          ],
        ),
      ),
    );
  }
}

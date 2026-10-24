import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tiles.dart';
import '../../state/screen_time_providers.dart';

/// Shown until the user grants usage access: in system Settings on Android,
/// in the Screen Time prompt on iOS.
class PermissionScreen extends ConsumerWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ios = ref.watch(nativeUsageReportsProvider);
    final points = [
      (Icons.hourglass_empty_rounded, 'Апп бүрт хэр их цаг зарцуулсныг'),
      (Icons.smartphone_rounded, 'Утсаа хэдэн удаа шалгасныг'),
      // iOS doesn't report data use.
      (Icons.notifications_none_rounded, ios ? 'Ирсэн мэдэгдлийг' : 'Ирсэн мэдэгдэл, дата хэрэглээг'),
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(icon: Icons.bar_chart_rounded, color: AppColors.accent, size: 64),
              const SizedBox(height: 24),
              const Text('Ашиглалтын мэдээлэлд хандах зөвшөөрөл', style: AppText.screenTitle),
              const SizedBox(height: 12),
              Text(
                ios
                    ? 'Дэлгэцийн цагийг харуулахын тулд Screen Time-ийн мэдээлэлд хандахыг зөвшөөрнө үү. '
                        'Мэдээлэл зөвхөн таны утсанд үлдэнэ.'
                    : 'Дэлгэцийн цагийг харуулахын тулд Тохиргоо доторх «Ашиглалтын хандалт» хэсэгт '
                        'энэ аппыг асаана уу. Мэдээлэл зөвхөн таны утсанд үлдэнэ.',
                style: AppText.body,
              ),
              const SizedBox(height: 28),
              for (final (icon, label) in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    spacing: 12,
                    children: [
                      Icon(icon, color: AppColors.accent),
                      Expanded(child: Text(label, style: AppText.rowTitle)),
                    ],
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => _request(context, ref),
                child: Text(ios ? 'Зөвшөөрөх' : 'Тохиргоо нээх'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(usageAccessProvider),
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppColors.muted),
                child: const Text('Зөвшөөрсөн, дахин шалгах'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(screenTimeRepositoryProvider).requestUsageAccess();
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      final detail = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail == null ? 'Зөвшөөрөл авч чадсангүй.' : 'Зөвшөөрөл авч чадсангүй. $detail')),
      );
      return;
    }
    // iOS answers in place; Android comes back through the app resuming.
    if (context.mounted) ref.invalidate(usageAccessProvider);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/screen_time_providers.dart';
import '../limits/limits_screen.dart';
import '../overview/overview_screen.dart';
import '../report/report_screen.dart';
import '../schedule/schedule_screen.dart';
import 'permission_screen.dart';

/// Bottom navigation between the four tabs; each keeps its scroll and state.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _tabs = [OverviewScreen(), ReportScreen(), LimitsScreen(), ScheduleScreen()];

  late final AppLifecycleListener _lifecycle;
  int _index = 0;

  /// Tabs are built on first visit so the week report isn't computed at launch.
  final _visited = <int>{0};

  @override
  void initState() {
    super.initState();
    // Usage keeps growing and access may change in Settings while we're away.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref
        ..invalidate(usageAccessProvider)
        ..invalidate(todayUsageProvider)
        ..invalidate(weekReportProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(usageAccessProvider);
    if (access.value == false) return const PermissionScreen();
    if (!access.hasValue && !access.hasError) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++) _visited.contains(i) ? _tabs[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Тойм'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Тайлан'),
          NavigationDestination(icon: Icon(Icons.hourglass_empty_rounded), label: 'Хязгаар'),
          NavigationDestination(icon: Icon(Icons.schedule_rounded), label: 'Хуваарь'),
        ],
      ),
    );
  }
}

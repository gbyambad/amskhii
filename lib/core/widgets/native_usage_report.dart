import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A scene of the iOS Screen Time report extension (`ios/ScreenTimeReport`).
enum UsageReport { today, week }

/// iOS draws usage only inside its report extension and never hands the
/// numbers to Dart, so the usage tabs embed that view whole, header included.
class NativeUsageReport extends StatelessWidget {
  const NativeUsageReport(this.report, {super.key});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: UiKitView(
        viewType: 'amskhii/usage_report',
        creationParams: {'report': report.name},
        creationParamsCodec: const StandardMessageCodec(),
        // The report scrolls itself; give it touches without waiting on Flutter.
        gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
      ),
    );
  }
}

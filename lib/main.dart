import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/device/biometrics.dart';
import 'data/device/device_screen_time_repository.dart';
import 'data/device/local_settings_store.dart';
import 'data/device/pin_store.dart';
import 'features/block/block_screen.dart';
import 'features/pin/prompting_pin_gate.dart';
import 'state/pin_gate.dart';
import 'state/screen_time_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Android hands the phone's usage to Dart. iOS keeps it inside its Screen
  // Time report extension, so there the usage screens embed that view.
  final repository = DeviceScreenTimeRepository(store: LocalSettingsStore(prefs), ios: Platform.isIOS);
  unawaited(repository.applyRules());

  runApp(
    ProviderScope(
      overrides: [
        screenTimeRepositoryProvider.overrideWithValue(repository),
        nativeUsageReportsProvider.overrideWithValue(Platform.isIOS),
        pinStoreProvider.overrideWithValue(PrefsPinStore(prefs)),
        biometricsProvider.overrideWithValue(DeviceBiometrics()),
        pinGateProvider.overrideWith(PromptingPinGate.new),
      ],
      child: const ScreenTimeApp(),
    ),
  );
}

/// Started by Android's `BlockingService`, through `BlockActivity`, when it
/// stops an app; [args] holds the [BlockReason] JSON.
@pragma('vm:entry-point')
void blockMain(List<String> args) => runApp(ScreenTimeApp(home: BlockScreen(reason: BlockReason.fromJson(args.first))));

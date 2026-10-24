import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/device/device_screen_time_repository.dart';
import 'data/device/local_settings_store.dart';
import 'state/screen_time_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Android hands the phone's usage to Dart. iOS keeps it inside its Screen
  // Time report extension, so there the usage screens embed that view.
  final repository = DeviceScreenTimeRepository(store: LocalSettingsStore(prefs));

  runApp(
    ProviderScope(
      overrides: [
        screenTimeRepositoryProvider.overrideWithValue(repository),
        nativeUsageReportsProvider.overrideWithValue(Platform.isIOS),
      ],
      child: const ScreenTimeApp(),
    ),
  );
}

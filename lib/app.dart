import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/navigation.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/home_shell.dart';

class ScreenTimeApp extends StatelessWidget {
  const ScreenTimeApp({super.key, this.home = const HomeShell()});

  /// `blockMain` swaps in the block screen.
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Амсхий',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('mn'),
      supportedLocales: const [Locale('mn')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );
  }
}

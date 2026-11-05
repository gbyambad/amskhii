import 'package:flutter/widgets.dart';

/// The app's navigator, so a gate in the state layer can show a screen
/// (the PIN prompt) without a [BuildContext].
final rootNavigatorKey = GlobalKey<NavigatorState>();

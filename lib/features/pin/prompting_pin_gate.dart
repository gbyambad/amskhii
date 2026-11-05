import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../state/pin_gate.dart';
import '../../state/screen_time_providers.dart';
import 'pin_screen.dart';

/// The app's [PinGate]: while the PIN is on, shows [PinEntryScreen] before a
/// loosening change. One unlock covers further changes for [grace], until
/// the app goes to the background.
class PromptingPinGate implements PinGate {
  PromptingPinGate(this._ref);

  static const grace = Duration(minutes: 5);

  final Ref _ref;
  DateTime? _openUntil;

  @override
  Future<bool> unlock(String reason) async {
    final pinOn = _ref.read(rulesProvider).value?.pinEnabled ?? false;
    if (!pinOn || !_ref.read(pinStoreProvider).hasPin) return true;
    final openUntil = _openUntil;
    if (openUntil != null && DateTime.now().isBefore(openUntil)) return true;

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return false;
    final ok = await navigator.push<bool>(
          MaterialPageRoute(fullscreenDialog: true, builder: (_) => PinEntryScreen(reason: reason)),
        ) ??
        false;
    if (ok) _openUntil = DateTime.now().add(grace);
    return ok;
  }

  @override
  void lock() => _openUntil = null;
}

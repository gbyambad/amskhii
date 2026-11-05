import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device/biometrics.dart';
import '../data/device/pin_store.dart';

/// Stands between the user and any change that loosens the rules: unblocking,
/// more time, a shorter schedule, turning the PIN off. The notifiers ask it;
/// `PromptingPinGate` (set in `main`) shows the PIN screen when the PIN is on.
abstract interface class PinGate {
  /// Whether the change may go ahead; [reason] says what it is for.
  Future<bool> unlock(String reason);

  /// Forgets a recent unlock, e.g. when the app goes to the background.
  void lock();
}

/// Lets everything through: the default until `main` swaps in the real gate.
class OpenPinGate implements PinGate {
  const OpenPinGate();

  @override
  Future<bool> unlock(String reason) async => true;

  @override
  void lock() {}
}

final pinGateProvider = Provider<PinGate>((ref) => const OpenPinGate());

final pinStoreProvider = Provider<PinStore>((ref) => MemoryPinStore());

final biometricsProvider = Provider<Biometrics>((ref) => const NoBiometrics());

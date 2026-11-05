import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Face ID or a fingerprint in place of typing the PIN, and the phone's own
/// lock as the way back in when the PIN is forgotten.
abstract interface class Biometrics {
  /// Whether a face or finger is enrolled.
  Future<bool> available();

  /// Face or finger only.
  Future<bool> authenticate(String reason);

  /// Face, finger or the phone's passcode.
  Future<bool> authenticateDevice(String reason);
}

class DeviceBiometrics implements Biometrics {
  final _auth = LocalAuthentication();

  static const _messages = [
    AndroidAuthMessages(signInTitle: 'Амсхий', signInHint: 'Мэдрэгчид хүрнэ үү', cancelButton: 'Болих'),
    IOSAuthMessages(cancelButton: 'Болих', localizedFallbackTitle: 'PIN оруулах'),
  ];

  @override
  Future<bool> available() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Exception catch (e) {
      debugPrint('Biometrics unavailable: $e');
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) => _run(reason, biometricOnly: true);

  @override
  Future<bool> authenticateDevice(String reason) => _run(reason, biometricOnly: false);

  /// Cancelling, a lockout or a missing sensor all just mean "not this way".
  Future<bool> _run(String reason, {required bool biometricOnly}) async {
    try {
      return await _auth.authenticate(localizedReason: reason, authMessages: _messages, biometricOnly: biometricOnly);
    } on Exception catch (e) {
      debugPrint('Authentication ended: $e');
      return false;
    }
  }
}

/// Until `main` swaps in [DeviceBiometrics]; tests keep this one.
class NoBiometrics implements Biometrics {
  const NoBiometrics();

  @override
  Future<bool> available() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;

  @override
  Future<bool> authenticateDevice(String reason) async => false;
}

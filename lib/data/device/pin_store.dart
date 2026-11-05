import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The 4-digit PIN that guards loosening the rules. Only a salted SHA-256
/// hash is kept, never the digits.
abstract interface class PinStore {
  bool get hasPin;

  bool verify(String pin);

  Future<void> setPin(String pin);

  Future<void> clear();
}

class PrefsPinStore implements PinStore {
  PrefsPinStore(this._prefs);

  static const _hashKey = 'pin.hash.v1';
  static const _saltKey = 'pin.salt.v1';

  final SharedPreferences _prefs;

  @override
  bool get hasPin => _prefs.getString(_hashKey) != null;

  @override
  bool verify(String pin) {
    final hash = _prefs.getString(_hashKey);
    final salt = _prefs.getString(_saltKey);
    return hash != null && salt != null && _hash(pin, salt) == hash;
  }

  @override
  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final salt = base64Encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);
    await _prefs.setString(_saltKey, salt);
    await _prefs.setString(_hashKey, _hash(pin, salt));
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_hashKey);
    await _prefs.remove(_saltKey);
  }

  static String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();
}

/// Until `main` swaps in [PrefsPinStore]; tests keep this one.
class MemoryPinStore implements PinStore {
  String? _pin;

  @override
  bool get hasPin => _pin != null;

  @override
  bool verify(String pin) => pin == _pin;

  @override
  Future<void> setPin(String pin) async => _pin = pin;

  @override
  Future<void> clear() async => _pin = null;
}

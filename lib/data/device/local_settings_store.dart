import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/block_schedule.dart';
import '../models/limit_rule.dart';

/// Keeps the user's limits and schedules on the phone as JSON.
class LocalSettingsStore {
  const LocalSettingsStore(this._prefs);

  static const _rulesKey = 'rules.v1';
  static const _schedulesKey = 'schedules.v1';

  final SharedPreferences _prefs;

  ScreenTimeRules? loadRules() {
    final raw = _prefs.getString(_rulesKey);
    return raw == null ? null : ScreenTimeRules.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  Future<void> saveRules(ScreenTimeRules rules) => _prefs.setString(_rulesKey, jsonEncode(rules.toJson()));

  List<BlockSchedule>? loadSchedules() {
    final raw = _prefs.getString(_schedulesKey);
    if (raw == null) return null;
    return [for (final s in jsonDecode(raw) as List) BlockSchedule.fromJson(s as Map<String, Object?>)];
  }

  Future<void> saveSchedules(List<BlockSchedule> schedules) =>
      _prefs.setString(_schedulesKey, jsonEncode([for (final s in schedules) s.toJson()]));
}

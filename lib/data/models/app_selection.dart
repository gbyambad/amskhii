import 'package:flutter/foundation.dart';

/// iOS: apps, categories and websites the user picked in Apple's picker.
///
/// Apple hands out only opaque tokens, which stay on the native side; Dart
/// knows a pick by its [id] and how many items it holds. Ids start with
/// [limitPrefix] for the Limits tab and [schedulePrefix] for a schedule.
@immutable
class AppSelection {
  const AppSelection({required this.id, this.apps = 0, this.categories = 0, this.sites = 0});

  static const limitPrefix = 'limit-';
  static const schedulePrefix = 'schedule-';

  /// The pick a schedule with [scheduleId] blocks.
  static String forSchedule(String scheduleId) => '$schedulePrefix$scheduleId';

  final String id;
  final int apps;
  final int categories;
  final int sites;

  bool get isEmpty => apps + categories + sites == 0;

  /// `3 апп · 1 ангилал`.
  String get label {
    if (isEmpty) return 'Апп сонгоогүй';
    return [
      if (apps > 0) '$apps апп',
      if (categories > 0) '$categories ангилал',
      if (sites > 0) '$sites вэб сайт',
    ].join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is AppSelection && other.id == id && other.apps == apps && other.categories == categories && other.sites == sites;

  @override
  int get hashCode => Object.hash(id, apps, categories, sites);
}

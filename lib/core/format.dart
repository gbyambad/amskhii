/// Formatting helpers for the Mongolian UI copy.
library;

const _weekdays = ['Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан', 'Бямба', 'Ням'];
const _weekdaysShort = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];

/// [weekday] uses [DateTime.monday]..[DateTime.sunday].
String weekdayName(int weekday) => _weekdays[weekday - 1];

String weekdayShort(int weekday) => _weekdaysShort[weekday - 1];

/// `4ц 12м`, `1ц`, `6м`; under a minute of use reads `<1м`, not `0м`.
String formatDuration(Duration d) {
  if (d > Duration.zero && d < const Duration(minutes: 1)) return '<1м';
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours == 0) return '$minutesм';
  return minutes == 0 ? '$hoursц' : '$hoursц $minutesм';
}

/// `18 мин`, `<1 мин`.
String formatMinutes(Duration d) {
  if (d > Duration.zero && d < const Duration(minutes: 1)) return '<1 мин';
  return '${d.inMinutes} мин';
}

/// `09:00`; 24 is allowed so a range can end at midnight.
String formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

/// `07:00`, `23:30` from minutes since midnight.
String formatMinuteOfDay(int minuteOfDay) {
  final h = (minuteOfDay ~/ 60) % 24;
  final m = minuteOfDay % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// `Баасан, 10-р сарын 23`.
String formatDate(DateTime d) => '${weekdayName(d.weekday)}, ${d.month}-р сарын ${d.day}';

/// `10/17`.
String formatShortDate(DateTime d) => '${d.month}/${d.day}';

/// `620 MB`, `1.4 GB` (decimal units, as carriers bill).
String formatDataSize(int bytes) {
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / 1e9).toStringAsFixed(1)} GB';
  }
  return '${(bytes / 1e6).round()} MB';
}

/// `+8%`, `−15%`.
String formatChange(double ratio) {
  final percent = (ratio * 100).round();
  return percent >= 0 ? '+$percent%' : '−${percent.abs()}%';
}

/// `Дөнгөж сая`, `4 мин өмнө`, `2 цагийн өмнө`.
String formatAgo(Duration d) {
  if (d.inMinutes < 1) return 'Дөнгөж сая';
  if (d.inHours < 1) return '${d.inMinutes} мин өмнө';
  return '${d.inHours} цагийн өмнө';
}

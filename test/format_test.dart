import 'package:amskhii/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(const Duration(minutes: 252)), '4ц 12м');
    expect(formatDuration(const Duration(hours: 1)), '1ц');
    expect(formatDuration(const Duration(minutes: 6)), '6м');
    expect(formatDuration(Duration.zero), '0м');
    expect(formatDuration(const Duration(seconds: 37)), '<1м');
    expect(formatMinutes(const Duration(seconds: 37)), '<1 мин');
  });

  test('formatDataSize uses decimal units', () {
    expect(formatDataSize(620000000), '620 MB');
    expect(formatDataSize(1430000000), '1.4 GB');
  });

  test('formatDate', () {
    expect(formatDate(DateTime(2026, 10, 23)), 'Баасан, 10-р сарын 23');
    expect(formatDate(DateTime(2026, 10, 19)), 'Даваа, 10-р сарын 19');
  });

  test('formatChange', () {
    expect(formatChange(0.08), '+8%');
    expect(formatChange(-0.15), '−15%');
  });

  test('formatMinuteOfDay wraps past midnight', () {
    expect(formatMinuteOfDay(23 * 60), '23:00');
    expect(formatMinuteOfDay(24 * 60 + 30), '00:30');
  });
}

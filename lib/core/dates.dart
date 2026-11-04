import 'package:intl/intl.dart';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime monthStart(DateTime value) => DateTime(value.year, value.month);

DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String monthLabel(DateTime month) => '${month.year}年${month.month}月';

String monthShortLabel(DateTime month) => '${month.month}月';

String dayLabel(DateTime date, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final target = dateOnly(date);
  final difference = today.difference(target).inDays;
  if (difference == 0) return '今天';
  if (difference == 1) return '昨天';
  if (difference == 2) return '前天';
  return '${date.month}月${date.day}日 ${weekdayLabel(date)}';
}

String fullDayLabel(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日 ${weekdayLabel(date)}';

String weekdayLabel(DateTime date) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[date.weekday - 1];
}

String timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String compactDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

String csvTimestamp(DateTime date) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

DateTime? parseBillDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final normalized = text.replaceAll('/', '-');
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) return parsed;
  final match = RegExp(
    r'^(\d{4})年(\d{1,2})月(\d{1,2})日(?:\s*(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
  ).firstMatch(text);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.tryParse(match.group(4) ?? '') ?? 0,
    int.tryParse(match.group(5) ?? '') ?? 0,
    int.tryParse(match.group(6) ?? '') ?? 0,
  );
}

int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

DateTime startOfWeek(DateTime date) =>
    dateOnly(date).subtract(Duration(days: date.weekday - 1));

DateTime endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

DateTime endOfMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);

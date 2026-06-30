import 'package:intl/intl.dart';

final _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _time = DateFormat('h:mm a');
final _date = DateFormat('d MMM yyyy');
final _dayShort = DateFormat('EEE, MMM d');
final _weekday = DateFormat('EEE');
final _dayNum = DateFormat('d');
final _month = DateFormat('MMM');
final _fullDate = DateFormat('EEE, MMM d • h:mm a');

//Prices are plain rupee integers from the backend (no paise conversion).
String rupees(int amount) => _rupee.format(amount);

String timeLabel(DateTime dt) => _time.format(dt.toLocal());
String dateLabel(DateTime dt) => _date.format(dt.toLocal());
String dayLabel(DateTime dt) => _dayShort.format(dt.toLocal());
String weekdayLabel(DateTime dt) => _weekday.format(dt.toLocal());
String dayNumber(DateTime dt) => _dayNum.format(dt.toLocal());
String monthLabel(DateTime dt) => _month.format(dt.toLocal());
String fullDateTime(DateTime dt) => _fullDate.format(dt.toLocal());

//"Today" / "Tomorrow" / weekday for date pills.
String relativeDay(DateTime dt) {
  final now = DateTime.now();
  final d = DateTime(dt.year, dt.month, dt.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return weekdayLabel(dt);
}

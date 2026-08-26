import 'package:intl/intl.dart';

/// Date/time helpers. Dates are stored as 'yyyy-MM-dd', times as 'HH:mm'
/// (24h), and full timestamps (Phase 7's recommended_at/completed_at) as
/// 'yyyy-MM-dd HH:mm'.
class DateFormatter {
  static const String dbDateFormat = 'yyyy-MM-dd';
  static const String dbTimeFormat = 'HH:mm';
  static const String dbDateTimeFormat = 'yyyy-MM-dd HH:mm';

  static String toDbDate(DateTime date) => DateFormat(dbDateFormat).format(date);

  static DateTime fromDbDate(String date) => DateFormat(dbDateFormat).parse(date);

  static String toDbDateTime(DateTime dateTime) => DateFormat(dbDateTimeFormat).format(dateTime);

  static DateTime fromDbDateTime(String dateTime) => DateFormat(dbDateTimeFormat).parse(dateTime);

  /// e.g. "Tuesday, Aug 25" for the Dashboard header.
  static String toDisplayDate(DateTime date) => DateFormat('EEEE, MMM d').format(date);

  /// e.g. "2:00 PM" from a stored "14:00".
  static String toDisplayTime(String dbTime) {
    final parsed = DateFormat(dbTimeFormat).parse(dbTime);
    return DateFormat('h:mm a').format(parsed);
  }

  static String todayAsDbDate() => toDbDate(DateTime.now());

  static String nowAsDbTime() => DateFormat(dbTimeFormat).format(DateTime.now());

  static String nowAsDbDateTime() => toDbDateTime(DateTime.now());
}
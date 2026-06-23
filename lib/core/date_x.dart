import 'package:intl/intl.dart';

/// Date / occurrence-id helpers shared across the dose engine and UI.
///
/// The whole app keys scheduled doses on a *calendar date + slot index*, never
/// on the exact clock time, so that editing a dose's time never orphans a
/// previously logged Taken/Skipped event.

final DateFormat _dateKeyFormat = DateFormat('yyyy-MM-dd');
final DateFormat _prettyDate = DateFormat('EEE, d MMM yyyy');
final DateFormat _prettyMonth = DateFormat('MMMM yyyy');

/// `yyyy-MM-dd` for the local calendar date of [d].
String dateKey(DateTime d) => _dateKeyFormat.format(d);

/// Parses a `yyyy-MM-dd` key back into a local midnight [DateTime].
DateTime parseDateKey(String s) => DateTime.parse(s);

/// Strips the time component, keeping the local calendar date at midnight.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String prettyDate(DateTime d) => _prettyDate.format(d);
String prettyMonth(DateTime d) => _prettyMonth.format(d);

/// Deterministic id for one scheduled dose occurrence.
String scheduledOccurrenceId(String medicineId, DateTime date, int slotIndex) =>
    'occ|$medicineId|${dateKey(date)}|$slotIndex';

/// Current instant as an ISO-8601 UTC string (used for createdAt / recordedAt).
String nowIsoUtc() => DateTime.now().toUtc().toIso8601String();

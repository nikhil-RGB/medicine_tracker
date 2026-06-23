import '../core/date_x.dart';
import '../models/dose_occurrence.dart';
import '../models/intake_event.dart';
import '../models/prescribed_medicine.dart';
import '../models/schedule.dart';
import '../models/user_condition.dart';
import 'dose_expander.dart';

/// Adherence summary for one medicine.
class AdherenceStats {
  final int taken;
  final int skipped;
  final int overdue;
  final int remaining; // future pending doses (fixed courses only)
  final int totalExpected; // fixed courses only; 0 when N/A
  final int prnCount; // PRN courses only
  final bool isFinite; // true only for fixed courses with a duration
  final CourseType courseType;

  const AdherenceStats({
    this.taken = 0,
    this.skipped = 0,
    this.overdue = 0,
    this.remaining = 0,
    this.totalExpected = 0,
    this.prnCount = 0,
    this.isFinite = false,
    this.courseType = CourseType.fixed,
  });

  double get progress => totalExpected > 0 ? taken / totalExpected : 0;

  /// Of the doses whose time has passed, the share marked taken.
  double get windowedRate {
    final past = taken + skipped + overdue;
    return past > 0 ? taken / past : 0;
  }
}

class AdherenceService {
  static const int ongoingWindowDays = 30;

  static AdherenceStats forMedicine({
    required PrescribedMedicine med,
    required UserCondition condition,
    required Map<String, IntakeEvent> eventsByOccurrence,
    required DateTime now,
  }) {
    if (med.courseType == CourseType.prn) {
      final count = eventsByOccurrence.values
          .where((e) => e.medicineId == med.id && e.isPrn)
          .length;
      return AdherenceStats(prnCount: count, courseType: CourseType.prn);
    }

    final rule = med.schedule;
    if (rule == null) return AdherenceStats(courseType: med.courseType);

    final start = dateOnly(parseDateKey(rule.startDate));
    final bool isFinite = med.courseType == CourseType.fixed && rule.durationDays != null;

    final DateTime from;
    final DateTime to;
    if (isFinite) {
      from = start;
      to = start.add(Duration(days: rule.durationDays! - 1));
    } else {
      to = dateOnly(now);
      from = to.subtract(const Duration(days: ongoingWindowDays - 1));
    }

    final occ = DoseExpander.expandMedicine(
      med: med,
      condition: condition,
      from: from,
      to: to,
      eventsByOccurrence: eventsByOccurrence,
      now: now,
    );

    var taken = 0, skipped = 0, overdue = 0, pending = 0;
    for (final o in occ) {
      switch (o.state) {
        case DoseState.taken:
          taken++;
          break;
        case DoseState.skipped:
          skipped++;
          break;
        case DoseState.overdue:
          overdue++;
          break;
        case DoseState.pending:
          pending++;
          break;
      }
    }

    return AdherenceStats(
      taken: taken,
      skipped: skipped,
      overdue: overdue,
      remaining: isFinite ? pending : 0,
      totalExpected: isFinite ? occ.length : 0,
      isFinite: isFinite,
      courseType: med.courseType,
    );
  }
}

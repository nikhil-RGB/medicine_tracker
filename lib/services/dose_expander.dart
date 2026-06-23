import '../core/date_x.dart';
import '../models/dose_occurrence.dart';
import '../models/intake_event.dart';
import '../models/prescribed_medicine.dart';
import '../models/schedule.dart';
import '../models/user_condition.dart';

/// Turns schedule rules into concrete [DoseOccurrence]s over a date window and
/// left-joins the intake log to derive each dose's state. This is the single
/// source of truth for Today, the calendar, overdue badges and adherence — no
/// dose is ever materialized to disk.
class DoseExpander {
  /// Expands one medicine over [from]..[to] (inclusive, by calendar date).
  static List<DoseOccurrence> expandMedicine({
    required PrescribedMedicine med,
    required UserCondition condition,
    required DateTime from,
    required DateTime to,
    required Map<String, IntakeEvent> eventsByOccurrence,
    required DateTime now,
  }) {
    if (med.courseType == CourseType.prn) return const [];
    final rule = med.schedule;
    if (rule == null || rule.slots.isEmpty) return const [];

    final start = dateOnly(parseDateKey(rule.startDate));
    var windowStart = dateOnly(from).isAfter(start) ? dateOnly(from) : start;
    var windowEnd = dateOnly(to);

    if (med.courseType == CourseType.fixed && rule.durationDays != null) {
      final courseEnd = start.add(Duration(days: rule.durationDays! - 1));
      if (courseEnd.isBefore(windowEnd)) windowEnd = courseEnd;
    }
    if (med.stoppedAt != null) {
      final stop = dateOnly(DateTime.parse(med.stoppedAt!));
      if (stop.isBefore(windowEnd)) windowEnd = stop;
    }
    if (windowEnd.isBefore(windowStart)) return const [];

    final result = <DoseOccurrence>[];
    for (var d = windowStart; !d.isAfter(windowEnd); d = d.add(const Duration(days: 1))) {
      if (rule.daysOfWeek != null && !rule.daysOfWeek!.contains(d.weekday)) continue;
      for (var i = 0; i < rule.slots.length; i++) {
        final slot = rule.slots[i];
        final dueAt = DateTime(d.year, d.month, d.day, slot.hour, slot.minute);
        final occId = scheduledOccurrenceId(med.id, d, i);
        final event = eventsByOccurrence[occId];
        result.add(DoseOccurrence(
          occurrenceId: occId,
          medicineId: med.id,
          medicineName: med.name,
          conditionId: condition.id,
          conditionName: condition.name,
          colorSeed: condition.colorSeed,
          slotIndex: i,
          dueAt: dueAt,
          state: _stateFor(event, dueAt, now),
          event: event,
        ));
      }
    }
    return result;
  }

  static DoseState _stateFor(IntakeEvent? event, DateTime dueAt, DateTime now) {
    if (event != null) {
      switch (event.status) {
        case IntakeStatus.taken:
        case IntakeStatus.prnTaken:
          return DoseState.taken;
        case IntakeStatus.skipped:
          return DoseState.skipped;
      }
    }
    return dueAt.isBefore(now) ? DoseState.overdue : DoseState.pending;
  }

  /// Expands a set of medicines across a window into one time-sorted list.
  static List<DoseOccurrence> expandAll({
    required List<PrescribedMedicine> medicines,
    required Map<String, UserCondition> conditionsById,
    required DateTime from,
    required DateTime to,
    required Map<String, IntakeEvent> eventsByOccurrence,
    required DateTime now,
    bool includeStopped = true,
  }) {
    final out = <DoseOccurrence>[];
    for (final med in medicines) {
      final cond = conditionsById[med.conditionId];
      if (cond == null) continue;
      if (!includeStopped && !med.isActive) continue;
      out.addAll(expandMedicine(
        med: med,
        condition: cond,
        from: from,
        to: to,
        eventsByOccurrence: eventsByOccurrence,
        now: now,
      ));
    }
    out.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return out;
  }
}

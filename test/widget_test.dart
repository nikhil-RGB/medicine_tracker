// Unit tests for the dose engine — the correctness-critical core that powers
// Today, the calendar, overdue state and adherence.

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminders_app/core/date_x.dart';
import 'package:medicine_reminders_app/models/dose_occurrence.dart';
import 'package:medicine_reminders_app/models/intake_event.dart';
import 'package:medicine_reminders_app/models/prescribed_medicine.dart';
import 'package:medicine_reminders_app/models/schedule.dart';
import 'package:medicine_reminders_app/models/user_condition.dart';
import 'package:medicine_reminders_app/services/dose_expander.dart';

void main() {
  final condition = UserCondition(
    id: 'c1',
    name: 'Test condition',
    colorSeed: 0xFF000000,
    createdAt: nowIsoUtc(),
  );

  PrescribedMedicine fixedMed({required String start, required int days, List<DoseSlot>? slots}) =>
      PrescribedMedicine(
        id: 'm1',
        conditionId: 'c1',
        name: 'Test drug',
        courseType: CourseType.fixed,
        schedule: ScheduleRule(
          startDate: start,
          durationDays: days,
          slots: slots ?? const [DoseSlot(hour: 8, minute: 0), DoseSlot(hour: 20, minute: 0)],
        ),
        createdAt: nowIsoUtc(),
      );

  test('fixed course expands frequency × duration doses', () {
    final med = fixedMed(start: '2026-01-01', days: 3); // 2 slots × 3 days
    final occ = DoseExpander.expandMedicine(
      med: med,
      condition: condition,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 1, 31),
      eventsByOccurrence: const {},
      now: DateTime(2026, 1, 2, 12),
    );
    expect(occ.length, 6);
  });

  test('past unconfirmed dose is overdue; future dose is pending', () {
    final med = fixedMed(start: '2026-01-01', days: 1);
    final occ = DoseExpander.expandMedicine(
      med: med,
      condition: condition,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 1, 1),
      eventsByOccurrence: const {},
      now: DateTime(2026, 1, 1, 12), // between the 08:00 and 20:00 slots
    );
    expect(occ[0].state, DoseState.overdue); // 08:00 has passed
    expect(occ[1].state, DoseState.pending); // 20:00 still to come
  });

  test('a taken event marks the matching occurrence as taken', () {
    final med = fixedMed(start: '2026-01-01', days: 1);
    final occId = scheduledOccurrenceId('m1', DateTime(2026, 1, 1), 0);
    final events = {
      occId: IntakeEvent(
        id: 'e1',
        medicineId: 'm1',
        conditionId: 'c1',
        occurrenceId: occId,
        status: IntakeStatus.taken,
        recordedAt: nowIsoUtc(),
      ),
    };
    final occ = DoseExpander.expandMedicine(
      med: med,
      condition: condition,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 1, 1),
      eventsByOccurrence: events,
      now: DateTime(2026, 1, 1, 23),
    );
    expect(occ[0].state, DoseState.taken);
    expect(occ[1].state, DoseState.overdue); // 20:00 unconfirmed and now past
  });

  test('occurrence id is stable across a dose-time edit (date + slot index)', () {
    final a = scheduledOccurrenceId('m1', DateTime(2026, 1, 1, 8), 0);
    final b = scheduledOccurrenceId('m1', DateTime(2026, 1, 1, 9), 0); // time changed
    expect(a, b); // same date + slot -> same id, so logged events are not orphaned
  });

  test('PRN medicines never expand to scheduled occurrences', () {
    final med = PrescribedMedicine(
      id: 'm2',
      conditionId: 'c1',
      name: 'PRN drug',
      courseType: CourseType.prn,
      createdAt: nowIsoUtc(),
    );
    final occ = DoseExpander.expandMedicine(
      med: med,
      condition: condition,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 12, 31),
      eventsByOccurrence: const {},
      now: DateTime(2026, 6, 1),
    );
    expect(occ, isEmpty);
  });

  test('a stopped medicine produces no occurrences after its stop date', () {
    final med = fixedMed(start: '2026-01-01', days: 10).copyWith(
      isActive: false,
      stoppedAt: DateTime(2026, 1, 3, 12).toIso8601String(),
    );
    final occ = DoseExpander.expandMedicine(
      med: med,
      condition: condition,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 1, 31),
      eventsByOccurrence: const {},
      now: DateTime(2026, 1, 15),
    );
    // Days 1, 2, 3 only (stopped on the 3rd) × 2 slots = 6.
    expect(occ.every((o) => !o.dueAt.isAfter(DateTime(2026, 1, 3, 23, 59))), isTrue);
  });
}

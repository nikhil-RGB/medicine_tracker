import 'intake_event.dart';

/// Derived display state of a single dose.
enum DoseState {
  /// Due in the future, or due earlier today but not yet past.
  pending,
  taken,
  skipped,

  /// Scheduled time is in the past and no taken/skipped event exists.
  overdue;

  bool get isActionable => this == DoseState.pending || this == DoseState.overdue;
}

/// The in-memory unit every screen renders, produced by the dose engine by
/// expanding a medicine's rule over a window and left-joining [IntakeEvent]s by
/// occurrence id. Never persisted — this is what makes ongoing/infinite courses
/// cost nothing on disk.
class DoseOccurrence {
  final String occurrenceId;
  final String medicineId;
  final String medicineName;
  final String conditionId;
  final String conditionName;
  final int colorSeed;
  final int slotIndex;
  final DateTime dueAt; // local
  final DoseState state;
  final IntakeEvent? event; // matched event, if any
  final bool isPrn;

  const DoseOccurrence({
    required this.occurrenceId,
    required this.medicineId,
    required this.medicineName,
    required this.conditionId,
    required this.conditionName,
    required this.colorSeed,
    required this.slotIndex,
    required this.dueAt,
    required this.state,
    this.event,
    this.isPrn = false,
  });
}

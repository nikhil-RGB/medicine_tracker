/// The explicit action a user took on a dose. `pending` / `overdue` are NEVER
/// stored — they are derived from the *absence* of an event for a past dose.
enum IntakeStatus {
  taken('taken'),
  skipped('skipped'),
  prnTaken('prn_taken');

  final String json;
  const IntakeStatus(this.json);

  static IntakeStatus fromJson(Object? v) =>
      IntakeStatus.values.firstWhere((e) => e.json == v, orElse: () => IntakeStatus.taken);
}

/// The only persisted per-dose record. One row per dose the user explicitly
/// Took/Skipped, plus standalone PRN takes.
class IntakeEvent {
  final String id; // uuid v4 (enables undo)
  final String medicineId;
  final String conditionId; // denormalized for cheap calendar/history render
  final String occurrenceId; // JOIN KEY (scheduled: occ|... ; PRN: prn|...)
  final String? scheduledFor; // ISO-8601 local planned due time; null for PRN
  final IntakeStatus status;
  final String recordedAt; // ISO-8601 UTC instant the user confirmed
  final String? note;

  const IntakeEvent({
    required this.id,
    required this.medicineId,
    required this.conditionId,
    required this.occurrenceId,
    this.scheduledFor,
    required this.status,
    required this.recordedAt,
    this.note,
  });

  bool get isPrn => status == IntakeStatus.prnTaken;

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineId': medicineId,
        'conditionId': conditionId,
        'occurrenceId': occurrenceId,
        if (scheduledFor != null) 'scheduledFor': scheduledFor,
        'status': status.json,
        'recordedAt': recordedAt,
        if (note != null) 'note': note,
      };

  factory IntakeEvent.fromJson(Map<String, dynamic> j) => IntakeEvent(
        id: j['id'] as String,
        medicineId: j['medicineId'] as String,
        conditionId: j['conditionId'] as String,
        occurrenceId: j['occurrenceId'] as String,
        scheduledFor: j['scheduledFor'] as String?,
        status: IntakeStatus.fromJson(j['status']),
        recordedAt: j['recordedAt'] as String,
        note: j['note'] as String?,
      );
}

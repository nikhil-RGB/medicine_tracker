import 'schedule.dart';

/// The central scheduling entity: one medicine taken for one [UserCondition],
/// carrying its course type and embedded [ScheduleRule]. Owns the rule that
/// dose occurrences are expanded from; never stores individual dose rows.
class PrescribedMedicine {
  final String id; // uuid v4
  final String conditionId; // FK -> UserCondition.id
  final String? refDrugId; // reference catalog drug id, null for custom
  final String name; // denormalized display drug name
  final bool isCustom;
  final String? dosageNote; // user's own label e.g. "1 tablet, 5mg" (NOT advice)
  final CourseType courseType;
  final ScheduleRule? schedule; // null/empty for PRN
  final bool isActive; // false when the user stops an ongoing/fixed med early
  final String? stoppedAt; // ISO-8601 local date-time when stopped
  final String createdAt; // ISO-8601 UTC

  const PrescribedMedicine({
    required this.id,
    required this.conditionId,
    this.refDrugId,
    required this.name,
    this.isCustom = false,
    this.dosageNote,
    required this.courseType,
    this.schedule,
    this.isActive = true,
    this.stoppedAt,
    required this.createdAt,
  });

  bool get isScheduled => courseType != CourseType.prn && schedule != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'conditionId': conditionId,
        if (refDrugId != null) 'refDrugId': refDrugId,
        'name': name,
        'isCustom': isCustom,
        if (dosageNote != null) 'dosageNote': dosageNote,
        'courseType': courseType.toJson(),
        if (schedule != null) 'schedule': schedule!.toJson(),
        'isActive': isActive,
        if (stoppedAt != null) 'stoppedAt': stoppedAt,
        'createdAt': createdAt,
      };

  factory PrescribedMedicine.fromJson(Map<String, dynamic> j) => PrescribedMedicine(
        id: j['id'] as String,
        conditionId: j['conditionId'] as String,
        refDrugId: j['refDrugId'] as String?,
        name: j['name'] as String,
        isCustom: j['isCustom'] as bool? ?? false,
        dosageNote: j['dosageNote'] as String?,
        courseType: CourseType.fromJson(j['courseType']),
        schedule: j['schedule'] == null
            ? null
            : ScheduleRule.fromJson((j['schedule'] as Map).cast<String, dynamic>()),
        isActive: j['isActive'] as bool? ?? true,
        stoppedAt: j['stoppedAt'] as String?,
        createdAt: j['createdAt'] as String,
      );

  PrescribedMedicine copyWith({
    String? conditionId,
    String? name,
    String? dosageNote,
    bool clearDosageNote = false,
    CourseType? courseType,
    ScheduleRule? schedule,
    bool clearSchedule = false,
    bool? isActive,
    String? stoppedAt,
    bool clearStoppedAt = false,
  }) =>
      PrescribedMedicine(
        id: id,
        conditionId: conditionId ?? this.conditionId,
        refDrugId: refDrugId,
        name: name ?? this.name,
        isCustom: isCustom,
        dosageNote: clearDosageNote ? null : (dosageNote ?? this.dosageNote),
        courseType: courseType ?? this.courseType,
        schedule: clearSchedule ? null : (schedule ?? this.schedule),
        isActive: isActive ?? this.isActive,
        stoppedAt: clearStoppedAt ? null : (stoppedAt ?? this.stoppedAt),
        createdAt: createdAt,
      );
}

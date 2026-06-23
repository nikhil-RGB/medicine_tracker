/// How a prescribed medicine is taken over time.
enum CourseType {
  /// Taken for a fixed number of days.
  fixed,

  /// Taken indefinitely (chronic) until the user stops it.
  ongoing,

  /// As-needed. No schedule, no reminders; logged manually when taken.
  prn;

  String toJson() => name;

  static CourseType fromJson(Object? v) =>
      CourseType.values.firstWhere((e) => e.name == v, orElse: () => CourseType.fixed);

  String get label => switch (this) {
        CourseType.fixed => 'Fixed course',
        CourseType.ongoing => 'Ongoing',
        CourseType.prn => 'As needed',
      };
}

/// One exact daily clock time. Its index in [ScheduleRule.slots] is the
/// `slotIndex` that anchors occurrence ids.
class DoseSlot {
  final int hour; // 0-23 local wall-clock
  final int minute; // 0-59
  final String? label;

  const DoseSlot({required this.hour, required this.minute, this.label});

  int get minutesOfDay => hour * 60 + minute;

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'minute': minute,
        if (label != null) 'label': label,
      };

  factory DoseSlot.fromJson(Map<String, dynamic> j) => DoseSlot(
        hour: (j['hour'] as num).toInt(),
        minute: (j['minute'] as num).toInt(),
        label: j['label'] as String?,
      );

  DoseSlot copyWith({int? hour, int? minute, String? label}) =>
      DoseSlot(hour: hour ?? this.hour, minute: minute ?? this.minute, label: label ?? this.label);
}

/// The compact recurrence the dose engine expands into concrete occurrences for
/// any date window. The source of truth that replaces materialized dose rows.
class ScheduleRule {
  /// First day the medicine is active (`yyyy-MM-dd`, local). Ignored for PRN.
  final String startDate;

  /// Set only for [CourseType.fixed]; inclusive end = start + durationDays - 1.
  final int? durationDays;

  /// One entry per dose-per-day. `slots.length == frequency-per-day`.
  final List<DoseSlot> slots;

  /// 1=Mon..7=Sun. `null` = every day (the v1 default).
  final List<int>? daysOfWeek;

  const ScheduleRule({
    required this.startDate,
    this.durationDays,
    this.slots = const [],
    this.daysOfWeek,
  });

  Map<String, dynamic> toJson() => {
        'startDate': startDate,
        if (durationDays != null) 'durationDays': durationDays,
        'slots': slots.map((s) => s.toJson()).toList(),
        if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      };

  factory ScheduleRule.fromJson(Map<String, dynamic> j) => ScheduleRule(
        startDate: j['startDate'] as String,
        durationDays: (j['durationDays'] as num?)?.toInt(),
        slots: ((j['slots'] as List?) ?? const [])
            .map((e) => DoseSlot.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        daysOfWeek: (j['daysOfWeek'] as List?)?.map((e) => (e as num).toInt()).toList(),
      );

  ScheduleRule copyWith({
    String? startDate,
    int? durationDays,
    List<DoseSlot>? slots,
    List<int>? daysOfWeek,
  }) =>
      ScheduleRule(
        startDate: startDate ?? this.startDate,
        durationDays: durationDays ?? this.durationDays,
        slots: slots ?? this.slots,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      );
}

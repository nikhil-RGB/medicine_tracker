import 'package:intl/intl.dart';

import '../models/prescribed_medicine.dart';
import '../models/schedule.dart';

final DateFormat _tf = DateFormat('h:mm a');

String courseTypeBadge(CourseType t) => switch (t) {
      CourseType.fixed => 'Fixed',
      CourseType.ongoing => 'Ongoing',
      CourseType.prn => 'As needed',
    };

String formatSlot(DoseSlot s) => _tf.format(DateTime(2000, 1, 1, s.hour, s.minute));

/// Human summary of how a medicine is taken, e.g. "2×/day · 8:00 AM, 8:00 PM · 7 days".
String scheduleSummary(PrescribedMedicine m) {
  if (m.courseType == CourseType.prn) return 'As needed · no fixed schedule';
  final r = m.schedule;
  if (r == null || r.slots.isEmpty) return 'No schedule set';
  final times = r.slots.map(formatSlot).join(', ');
  final freq = '${r.slots.length}×/day';
  if (m.courseType == CourseType.fixed && r.durationDays != null) {
    return '$freq · $times · ${r.durationDays} days';
  }
  return '$freq · $times · ongoing';
}

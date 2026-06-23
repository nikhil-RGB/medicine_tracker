import '../core/date_x.dart';
import '../models/intake_event.dart';
import '../models/prescribed_medicine.dart';
import '../models/user_condition.dart';
import 'dose_expander.dart';
import 'notification_service.dart';

/// Keeps a bounded rolling horizon of scheduled reminders in sync with the
/// schedule rules. Ongoing meds are infinite and iOS caps pending notifications
/// at ~64, so we only ever schedule the earliest [maxPending] doses within the
/// next [horizonDays] days, refreshed on launch / resume / edit.
class NotificationScheduler {
  NotificationScheduler(this._service);
  final NotificationService _service;

  static const int horizonDays = 14;
  static const int maxPending = 56; // safety margin under the iOS ~64 cap

  /// Stable 31-bit FNV-1a hash of an occurrence id -> notification id.
  static int notificationIdFor(String occurrenceId) {
    var hash = 0x811c9dc5;
    for (final c in occurrenceId.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  Future<void> reconcile({
    required List<PrescribedMedicine> medicines,
    required Map<String, UserCondition> conditionsById,
    required Map<String, IntakeEvent> eventsByOccurrence,
  }) async {
    if (!_service.isReady) return;

    final now = DateTime.now();
    final to = dateOnly(now).add(const Duration(days: horizonDays));
    final active = medicines.where((m) => m.isActive && m.isScheduled).toList();

    final occ = DoseExpander.expandAll(
      medicines: active,
      conditionsById: conditionsById,
      from: now,
      to: to,
      eventsByOccurrence: eventsByOccurrence,
      now: now,
      includeStopped: false,
    );

    // Only future, still-unresolved doses are worth a reminder.
    final upcoming = occ.where((o) => o.dueAt.isAfter(now) && o.event == null).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final chosen = upcoming.take(maxPending).toList();
    final desiredIds = {for (final o in chosen) notificationIdFor(o.occurrenceId)};

    final existing = (await _service.pendingIds()).toSet();

    for (final id in existing.difference(desiredIds)) {
      await _service.cancel(id);
    }
    for (final o in chosen) {
      final id = notificationIdFor(o.occurrenceId);
      if (existing.contains(id)) continue;
      await _service.schedule(
        id: id,
        title: 'Time for your ${o.medicineName} dose',
        body: 'For ${o.conditionName}',
        when: o.dueAt,
      );
    }
  }

  Future<void> cancelAll() => _service.cancelAll();
}

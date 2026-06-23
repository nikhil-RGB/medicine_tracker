import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/date_x.dart';
import '../core/palette.dart';
import '../data/app_services.dart';
import '../data/custom_catalog_repository.dart';
import '../models/dose_occurrence.dart';
import '../models/intake_event.dart';
import '../models/prescribed_medicine.dart';
import '../models/schedule.dart';
import '../models/user_condition.dart';
import '../services/dose_expander.dart';

const _uuid = Uuid();

/// One-time async bootstrap of all services/repositories.
final appServicesProvider = FutureProvider<AppServices>((ref) => AppServices.bootstrap());

/// Convenience accessor for the already-bootstrapped services. Only read from
/// screens shown after the boot gate completes.
final servicesProvider = Provider<AppServices>((ref) => ref.watch(appServicesProvider).requireValue);

/// A coarse "current time" the UI reads; refreshed on app resume so the overdue
/// boundary advances without any background work.
final clockProvider = NotifierProvider<ClockNotifier, DateTime>(ClockNotifier.new);

class ClockNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void tick() => state = DateTime.now();
}

/// Immutable snapshot of all mutable domain data, rebuilt after each mutation.
class DataSnapshot {
  final List<UserCondition> conditions;
  final List<PrescribedMedicine> medicines;
  final List<IntakeEvent> events;
  final Map<String, IntakeEvent> eventsByOccurrence;
  final Map<String, UserCondition> conditionsById;

  DataSnapshot({
    required this.conditions,
    required this.medicines,
    required this.events,
  })  : eventsByOccurrence = {for (final e in events) e.occurrenceId: e},
        conditionsById = {for (final c in conditions) c.id: c};

  List<UserCondition> get activeConditions => conditions.where((c) => c.isActive).toList();

  List<PrescribedMedicine> medicinesFor(String conditionId) =>
      medicines.where((m) => m.conditionId == conditionId).toList();

  UserCondition? conditionById(String id) => conditionsById[id];

  PrescribedMedicine? medicineById(String id) {
    for (final m in medicines) {
      if (m.id == id) return m;
    }
    return null;
  }
}

final dataProvider = AsyncNotifierProvider<DataNotifier, DataSnapshot>(DataNotifier.new);

class DataNotifier extends AsyncNotifier<DataSnapshot> {
  late AppServices _s;

  @override
  Future<DataSnapshot> build() async {
    _s = await ref.watch(appServicesProvider.future);
    return _snapshot();
  }

  DataSnapshot _snapshot() => DataSnapshot(
        conditions: _s.appData.conditions,
        medicines: _s.appData.medicines,
        events: _s.intake.events,
      );

  void _refresh() => state = AsyncData(_snapshot());

  Future<void> _reschedule() async {
    final snap = _snapshot();
    await _s.scheduler.reconcile(
      medicines: snap.medicines,
      conditionsById: snap.conditionsById,
      eventsByOccurrence: snap.eventsByOccurrence,
    );
  }

  /// Refresh the rolling reminder horizon from the current schedule (called on
  /// launch / resume).
  Future<void> reconcileNow() async {
    await _reschedule();
    await _s.settings.setLastReconcileEpoch(DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> requestNotificationPermission() => _s.notifications.requestPermissions();

  // ---- Conditions ----

  Future<UserCondition> addCondition({String? refId, required String name, bool isCustom = false}) async {
    final c = UserCondition(
      id: _uuid.v4(),
      refId: refId,
      name: name,
      isCustom: isCustom,
      colorSeed: conditionColorSeedFor(_s.appData.conditions.length),
      createdAt: nowIsoUtc(),
    );
    await _s.appData.addCondition(c);
    if (isCustom) {
      await _s.custom.addCondition(CustomCatalogEntry(id: c.id, name: name));
    }
    _refresh();
    return c;
  }

  Future<void> archiveCondition(String id) async {
    final list = _s.appData.conditions.where((c) => c.id == id).toList();
    if (list.isEmpty) return;
    await _s.appData.updateCondition(list.first.copyWith(archivedAt: nowIsoUtc()));
    _refresh();
    await _reschedule();
  }

  // ---- Medicines ----

  Future<PrescribedMedicine> addMedicine(PrescribedMedicine m) async {
    await _s.appData.addMedicine(m);
    if (m.isCustom) {
      await _s.custom.addDrug(CustomCatalogEntry(id: m.id, name: m.name));
    }
    _refresh();
    await _reschedule();
    return m;
  }

  /// Builds and persists a new prescribed medicine.
  Future<PrescribedMedicine> createMedicine({
    required String conditionId,
    required String name,
    String? refDrugId,
    bool isCustom = false,
    String? dosageNote,
    required CourseType courseType,
    ScheduleRule? schedule,
  }) {
    final m = PrescribedMedicine(
      id: _uuid.v4(),
      conditionId: conditionId,
      refDrugId: refDrugId,
      name: name,
      isCustom: isCustom,
      dosageNote: dosageNote,
      courseType: courseType,
      schedule: schedule,
      createdAt: nowIsoUtc(),
    );
    return addMedicine(m);
  }

  Future<void> updateMedicine(PrescribedMedicine m) async {
    await _s.appData.updateMedicine(m);
    _refresh();
    await _reschedule();
  }

  Future<void> stopMedicine(String id) async {
    final list = _s.appData.medicines.where((m) => m.id == id).toList();
    if (list.isEmpty) return;
    await _s.appData.updateMedicine(
      list.first.copyWith(isActive: false, stoppedAt: DateTime.now().toIso8601String()),
    );
    _refresh();
    await _reschedule();
  }

  Future<void> deleteMedicine(String id) async {
    await _s.appData.deleteMedicine(id);
    _refresh();
    await _reschedule();
  }

  // ---- Doses ----

  Future<void> markDose(DoseOccurrence o, IntakeStatus status) async {
    await _s.intake.record(IntakeEvent(
      id: _uuid.v4(),
      medicineId: o.medicineId,
      conditionId: o.conditionId,
      occurrenceId: o.occurrenceId,
      scheduledFor: o.dueAt.toIso8601String(),
      status: status,
      recordedAt: nowIsoUtc(),
    ));
    _refresh();
    await _reschedule();
  }

  Future<void> undoOccurrence(String occurrenceId) async {
    await _s.intake.removeByOccurrence(occurrenceId);
    _refresh();
    await _reschedule();
  }

  Future<void> logPrn(PrescribedMedicine med, {String? note}) async {
    await _s.intake.addPrn(IntakeEvent(
      id: _uuid.v4(),
      medicineId: med.id,
      conditionId: med.conditionId,
      occurrenceId: 'prn|${med.id}|${_uuid.v4()}',
      status: IntakeStatus.prnTaken,
      recordedAt: nowIsoUtc(),
      note: note,
    ));
    _refresh();
  }

  Future<void> removeEvent(String eventId) async {
    await _s.intake.removeById(eventId);
    _refresh();
  }
}

/// Today's doses plus the still-overdue tail carried from earlier days.
final todayDosesProvider = Provider<List<DoseOccurrence>>((ref) {
  final snap = ref.watch(dataProvider).valueOrNull;
  if (snap == null) return const [];
  final now = ref.watch(clockProvider);
  final today = dateOnly(now);
  const lookbackDays = 180;
  final occ = DoseExpander.expandAll(
    medicines: snap.medicines,
    conditionsById: snap.conditionsById,
    from: today.subtract(const Duration(days: lookbackDays)),
    to: today,
    eventsByOccurrence: snap.eventsByOccurrence,
    now: now,
  );
  return occ.where((o) {
    if (isSameDay(o.dueAt, today)) return true;
    return o.state == DoseState.overdue; // earlier days: only unresolved overdue
  }).toList();
});

/// All occurrences for a given calendar day (yyyy-MM-dd key).
final dosesForDayProvider =
    Provider.autoDispose.family<List<DoseOccurrence>, String>((ref, dayKey) {
  final snap = ref.watch(dataProvider).valueOrNull;
  if (snap == null) return const [];
  final now = ref.watch(clockProvider);
  final day = parseDateKey(dayKey);
  return DoseExpander.expandAll(
    medicines: snap.medicines,
    conditionsById: snap.conditionsById,
    from: day,
    to: day,
    eventsByOccurrence: snap.eventsByOccurrence,
    now: now,
  );
});

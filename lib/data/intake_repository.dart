import '../models/intake_event.dart';
import 'json_store.dart';

/// Hot, ever-growing data: the sparse log of doses the user explicitly acted on
/// (Taken / Skipped / PRN-taken). Stored separately in `intake_log.json` so a
/// confirmation never rewrites the cold app-data document.
class IntakeRepository {
  IntakeRepository(this._store);
  final JsonStore _store;
  static const _file = 'intake_log.json';

  List<IntakeEvent> _events = [];
  Map<String, IntakeEvent> _byOccurrence = {};

  List<IntakeEvent> get events => List.unmodifiable(_events);
  Map<String, IntakeEvent> get byOccurrence => Map.unmodifiable(_byOccurrence);

  Future<void> load() async {
    final data = await _store.read(_file);
    if (data == null) return;
    _events = ((data['events'] as List?) ?? const [])
        .map((e) => IntakeEvent.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    _reindex();
  }

  void _reindex() => _byOccurrence = {for (final e in _events) e.occurrenceId: e};

  IntakeEvent? forOccurrence(String occurrenceId) => _byOccurrence[occurrenceId];

  List<IntakeEvent> forMedicine(String medicineId) =>
      _events.where((e) => e.medicineId == medicineId).toList();

  Future<void> _persist() => _store.write(_file, {
        'schemaVersion': 1,
        'events': _events.map((e) => e.toJson()).toList(),
      });

  /// Records a scheduled-dose action, replacing any existing event for the same
  /// occurrence (one taken/skip wins per scheduled slot).
  Future<void> record(IntakeEvent event) async {
    _events = [
      for (final e in _events)
        if (e.occurrenceId != event.occurrenceId) e,
      event,
    ];
    _reindex();
    await _persist();
  }

  Future<void> addPrn(IntakeEvent event) async {
    _events = [..._events, event];
    _reindex();
    await _persist();
  }

  Future<void> removeByOccurrence(String occurrenceId) async {
    _events = [for (final e in _events) if (e.occurrenceId != occurrenceId) e];
    _reindex();
    await _persist();
  }

  Future<void> removeById(String id) async {
    _events = [for (final e in _events) if (e.id != id) e];
    _reindex();
    await _persist();
  }
}

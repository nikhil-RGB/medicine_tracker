import '../models/prescribed_medicine.dart';
import '../models/user_condition.dart';
import 'json_store.dart';

/// Cold domain data: the user's conditions + prescribed medicines (with their
/// embedded schedule rules). Stored in `app_data.json`; never rewritten on a
/// dose confirmation (those go to the separate intake log).
class AppDataRepository {
  AppDataRepository(this._store);
  final JsonStore _store;
  static const _file = 'app_data.json';

  List<UserCondition> _conditions = [];
  List<PrescribedMedicine> _medicines = [];

  List<UserCondition> get conditions => List.unmodifiable(_conditions);
  List<PrescribedMedicine> get medicines => List.unmodifiable(_medicines);

  Future<void> load() async {
    final data = await _store.read(_file);
    if (data == null) return;
    _conditions = ((data['conditions'] as List?) ?? const [])
        .map((e) => UserCondition.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    _medicines = ((data['medicines'] as List?) ?? const [])
        .map((e) => PrescribedMedicine.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> _persist() => _store.write(_file, {
        'schemaVersion': 1,
        'conditions': _conditions.map((e) => e.toJson()).toList(),
        'medicines': _medicines.map((e) => e.toJson()).toList(),
      });

  List<PrescribedMedicine> medicinesFor(String conditionId) =>
      _medicines.where((m) => m.conditionId == conditionId).toList();

  Future<void> addCondition(UserCondition c) async {
    _conditions = [..._conditions, c];
    await _persist();
  }

  Future<void> updateCondition(UserCondition c) async {
    _conditions = [for (final x in _conditions) if (x.id == c.id) c else x];
    await _persist();
  }

  Future<void> addMedicine(PrescribedMedicine m) async {
    _medicines = [..._medicines, m];
    await _persist();
  }

  Future<void> updateMedicine(PrescribedMedicine m) async {
    _medicines = [for (final x in _medicines) if (x.id == m.id) m else x];
    await _persist();
  }

  Future<void> deleteMedicine(String id) async {
    _medicines = [for (final x in _medicines) if (x.id != id) x];
    await _persist();
  }
}

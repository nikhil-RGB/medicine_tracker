import 'json_store.dart';

/// A user-added custom condition or medicine *name*, kept so it reappears in
/// pickers. Stored in `custom_catalog.json`, separate from the read-only bundle.
class CustomCatalogEntry {
  final String id;
  final String name;
  const CustomCatalogEntry({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory CustomCatalogEntry.fromJson(Map<String, dynamic> j) =>
      CustomCatalogEntry(id: j['id'] as String, name: j['name'] as String);
}

class CustomCatalogRepository {
  CustomCatalogRepository(this._store);
  final JsonStore _store;
  static const _file = 'custom_catalog.json';

  List<CustomCatalogEntry> _conditions = [];
  List<CustomCatalogEntry> _drugs = [];

  List<CustomCatalogEntry> get conditions => List.unmodifiable(_conditions);
  List<CustomCatalogEntry> get drugs => List.unmodifiable(_drugs);

  Future<void> load() async {
    final data = await _store.read(_file);
    if (data == null) return;
    _conditions = ((data['conditions'] as List?) ?? const [])
        .map((e) => CustomCatalogEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    _drugs = ((data['drugs'] as List?) ?? const [])
        .map((e) => CustomCatalogEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> _persist() => _store.write(_file, {
        'schemaVersion': 1,
        'conditions': _conditions.map((e) => e.toJson()).toList(),
        'drugs': _drugs.map((e) => e.toJson()).toList(),
      });

  bool _has(List<CustomCatalogEntry> list, String name) =>
      list.any((x) => x.name.toLowerCase() == name.toLowerCase());

  Future<void> addCondition(CustomCatalogEntry e) async {
    if (_has(_conditions, e.name)) return;
    _conditions = [..._conditions, e];
    await _persist();
  }

  Future<void> addDrug(CustomCatalogEntry e) async {
    if (_has(_drugs, e.name)) return;
    _drugs = [..._drugs, e];
    await _persist();
  }
}

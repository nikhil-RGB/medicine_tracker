import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/reference_models.dart';

/// Lazily loads the read-only bundled condition->drug reference catalog.
///
/// `index.json` (the small manifest + condition search index) is loaded eagerly
/// on first use; per-category drug/condition shards are loaded only when their
/// category is opened or matched, bounding resident memory.
class ReferenceCatalogService {
  ReferenceIndex _index = ReferenceIndex.empty;
  bool _indexLoaded = false;

  final Map<String, List<RefDrug>> _drugsByCat = {};
  final Map<String, Map<String, List<String>>> _condDrugIdsByCat = {};

  ReferenceIndex get index => _index;
  String get disclaimer => _index.disclaimer;
  bool get isEmpty => _index.conditions.isEmpty;

  Future<ReferenceIndex> loadIndex() async {
    if (_indexLoaded) return _index;
    try {
      final text = await rootBundle.loadString('assets/reference/index.json');
      _index = ReferenceIndex.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      _index = ReferenceIndex.empty;
    }
    _indexLoaded = true;
    return _index;
  }

  List<RefCategory> get categories => _index.categories;

  RefCategory? categoryById(String id) {
    for (final c in _index.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Filters the eagerly-loaded condition index by query (and optional category).
  List<RefConditionIndex> searchConditions(String query, {String? categoryId}) {
    final q = query.trim().toLowerCase();
    Iterable<RefConditionIndex> items = _index.conditions;
    if (categoryId != null) items = items.where((c) => c.category == categoryId);
    if (q.isNotEmpty) items = items.where((c) => c.matches(q));
    final list = items.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<RefDrug>> _drugsForCategory(String catId) async {
    final cached = _drugsByCat[catId];
    if (cached != null) return cached;
    List<RefDrug> drugs;
    try {
      final text = await rootBundle.loadString('assets/reference/drugs_$catId.json');
      final data = jsonDecode(text) as Map<String, dynamic>;
      drugs = ((data['drugs'] as List?) ?? const [])
          .map((e) => RefDrug.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      drugs = const [];
    }
    _drugsByCat[catId] = drugs;
    return drugs;
  }

  Future<Map<String, List<String>>> _condDrugIds(String catId) async {
    final cached = _condDrugIdsByCat[catId];
    if (cached != null) return cached;
    final map = <String, List<String>>{};
    try {
      final text = await rootBundle.loadString('assets/reference/conditions_$catId.json');
      final data = jsonDecode(text) as Map<String, dynamic>;
      for (final c in ((data['conditions'] as List?) ?? const [])) {
        final m = (c as Map).cast<String, dynamic>();
        map[m['id'] as String] =
            ((m['drugIds'] as List?) ?? const []).map((e) => e as String).toList();
      }
    } catch (_) {/* leave empty */}
    _condDrugIdsByCat[catId] = map;
    return map;
  }

  /// The drugs typically associated with a reference condition.
  Future<List<RefDrug>> drugsForCondition(RefConditionIndex cond) async {
    final ids = (await _condDrugIds(cond.category))[cond.id] ?? const [];
    final drugs = await _drugsForCategory(cond.category);
    final byId = {for (final d in drugs) d.id: d};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  RefDrug? drugInCategorySync(String catId, String drugId) {
    final list = _drugsByCat[catId];
    if (list == null) return null;
    for (final d in list) {
      if (d.id == drugId) return d;
    }
    return null;
  }

  /// Global drug search across all categories (loads shards lazily on demand).
  Future<List<RefDrug>> searchAllDrugs(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final seen = <String>{};
    final results = <RefDrug>[];
    for (final cat in _index.categories) {
      for (final d in await _drugsForCategory(cat.id)) {
        if (d.matches(q) && seen.add(d.id)) results.add(d);
      }
    }
    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }
}

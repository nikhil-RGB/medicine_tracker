// Read-only models for the bundled condition -> drug reference catalog
// (assets/reference/*). Name-only reference data; never mutated.

class RefCategory {
  final String id;
  final String name;
  final String shard;
  final int conditionCount;

  const RefCategory({
    required this.id,
    required this.name,
    required this.shard,
    this.conditionCount = 0,
  });

  factory RefCategory.fromJson(Map<String, dynamic> j) => RefCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        shard: j['shard'] as String,
        conditionCount: (j['conditionCount'] as num?)?.toInt() ?? 0,
      );
}

/// One entry in the eagerly-loaded condition search index (index.json).
class RefConditionIndex {
  final String id;
  final String name;
  final List<String> aliases;
  final String category; // category id / shard
  final String nameLower;

  const RefConditionIndex({
    required this.id,
    required this.name,
    this.aliases = const [],
    required this.category,
    required this.nameLower,
  });

  factory RefConditionIndex.fromJson(Map<String, dynamic> j) => RefConditionIndex(
        id: j['id'] as String,
        name: j['name'] as String,
        aliases: ((j['aliases'] as List?) ?? const []).map((e) => e as String).toList(),
        category: j['category'] as String,
        nameLower: j['nameLower'] as String? ?? (j['name'] as String).toLowerCase(),
      );

  bool matches(String lowerQuery) {
    if (lowerQuery.isEmpty) return true;
    if (nameLower.contains(lowerQuery)) return true;
    for (final a in aliases) {
      if (a.toLowerCase().contains(lowerQuery)) return true;
    }
    return false;
  }
}

class ReferenceIndex {
  final int schemaVersion;
  final String disclaimer;
  final List<RefCategory> categories;
  final List<RefConditionIndex> conditions;

  const ReferenceIndex({
    this.schemaVersion = 1,
    this.disclaimer = '',
    this.categories = const [],
    this.conditions = const [],
  });

  static const ReferenceIndex empty = ReferenceIndex();

  factory ReferenceIndex.fromJson(Map<String, dynamic> j) => ReferenceIndex(
        schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
        disclaimer: j['disclaimer'] as String? ?? '',
        categories: ((j['categories'] as List?) ?? const [])
            .map((e) => RefCategory.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        conditions: ((j['conditions'] as List?) ?? const [])
            .map((e) => RefConditionIndex.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class RefDrug {
  final String id;
  final String name;
  final List<String> aliases;
  final String nameLower;

  const RefDrug({
    required this.id,
    required this.name,
    this.aliases = const [],
    required this.nameLower,
  });

  factory RefDrug.fromJson(Map<String, dynamic> j) => RefDrug(
        id: j['id'] as String,
        name: j['name'] as String,
        aliases: ((j['aliases'] as List?) ?? const []).map((e) => e as String).toList(),
        nameLower: j['nameLower'] as String? ?? (j['name'] as String).toLowerCase(),
      );

  bool matches(String lowerQuery) {
    if (lowerQuery.isEmpty) return true;
    if (nameLower.contains(lowerQuery)) return true;
    for (final a in aliases) {
      if (a.toLowerCase().contains(lowerQuery)) return true;
    }
    return false;
  }
}

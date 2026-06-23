/// A health condition the user has, chosen from the bundled reference catalog
/// or created custom. Top-level grouping for prescriptions.
class UserCondition {
  final String id; // uuid v4
  final String? refId; // reference catalog condition id, null for custom
  final String name; // denormalized display name
  final bool isCustom;
  final int colorSeed; // ARGB seed for a consistent color chip
  final String createdAt; // ISO-8601 UTC
  final String? archivedAt; // soft-delete; null = active

  const UserCondition({
    required this.id,
    this.refId,
    required this.name,
    this.isCustom = false,
    required this.colorSeed,
    required this.createdAt,
    this.archivedAt,
  });

  bool get isActive => archivedAt == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (refId != null) 'refId': refId,
        'name': name,
        'isCustom': isCustom,
        'colorSeed': colorSeed,
        'createdAt': createdAt,
        if (archivedAt != null) 'archivedAt': archivedAt,
      };

  factory UserCondition.fromJson(Map<String, dynamic> j) => UserCondition(
        id: j['id'] as String,
        refId: j['refId'] as String?,
        name: j['name'] as String,
        isCustom: j['isCustom'] as bool? ?? false,
        colorSeed: (j['colorSeed'] as num?)?.toInt() ?? 0xFF6750A4,
        createdAt: j['createdAt'] as String,
        archivedAt: j['archivedAt'] as String?,
      );

  UserCondition copyWith({
    String? name,
    int? colorSeed,
    String? archivedAt,
    bool clearArchived = false,
  }) =>
      UserCondition(
        id: id,
        refId: refId,
        name: name ?? this.name,
        isCustom: isCustom,
        colorSeed: colorSeed ?? this.colorSeed,
        createdAt: createdAt,
        archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
      );
}

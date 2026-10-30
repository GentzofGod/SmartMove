class CommodityCategory {
  final String id;
  final String name;
  final String slug;
  final String? iconName;
  final String? description;
  final int displayOrder;
  final bool isActive;

  const CommodityCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.iconName,
    this.description,
    this.displayOrder = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'iconName': iconName,
        'description': description,
        'displayOrder': displayOrder,
        'isActive': isActive,
      };

  Map<String, dynamic> toDbMap() => {
        'name': name,
        'slug': slug,
        'icon_name': iconName,
        'description': description,
        'display_order': displayOrder,
        'is_active': isActive,
      };

  factory CommodityCategory.fromJson(Map<String, dynamic> json) =>
      CommodityCategory(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        iconName: (json['iconName'] ?? json['icon_name'])?.toString(),
        description: json['description']?.toString(),
        displayOrder:
            (json['displayOrder'] ?? json['display_order']) as int? ?? 0,
        isActive:
            (json['isActive'] ?? json['is_active']) as bool? ?? true,
      );

  CommodityCategory copyWith({
    String? id,
    String? name,
    String? slug,
    String? iconName,
    String? description,
    int? displayOrder,
    bool? isActive,
  }) {
    return CommodityCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      iconName: iconName ?? this.iconName,
      description: description ?? this.description,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}


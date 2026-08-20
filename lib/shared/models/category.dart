class Category {
  const Category({
    required this.id,
    required this.parentId,
    required this.itemType,
    required this.name,
    this.sortOrder = 0,
  });

  final int id;

  /// Null for a top-level category (e.g. "Fashion & Clothing").
  final int? parentId;
  final String itemType;
  final String name;
  final int sortOrder;

  bool get isTopLevel => parentId == null;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      parentId: json['parent_id'] as int?,
      itemType: json['item_type'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

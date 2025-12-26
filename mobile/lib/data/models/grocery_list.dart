import 'package:equatable/equatable.dart';

/// Grocery list item model.
class GroceryListItem extends Equatable {
  /// Unique identifier for the item.
  final String id;

  /// Name of the item (e.g., "flour", "milk", "eggs").
  final String name;

  /// How many of this item to buy (default 1).
  final int quantity;

  /// Additional notes for the item.
  final String? notes;

  /// Linked product ID if matched.
  final int? productId;

  /// Position in the list for ordering.
  final int position;

  /// Whether the item has been checked off.
  final bool isChecked;

  /// Creates a grocery list item.
  const GroceryListItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.notes,
    this.productId,
    this.position = 0,
    this.isChecked = false,
  });

  /// Creates a copy with updated fields.
  GroceryListItem copyWith({
    String? id,
    String? name,
    int? quantity,
    String? notes,
    int? productId,
    int? position,
    bool? isChecked,
  }) {
    return GroceryListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      productId: productId ?? this.productId,
      position: position ?? this.position,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  /// Creates an item from JSON.
  factory GroceryListItem.fromJson(Map<String, dynamic> json) {
    return GroceryListItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      notes: json['notes'] as String?,
      productId: json['product_id'] is int ? json['product_id'] as int : int.tryParse(json['product_id']?.toString() ?? ''),
      position: json['position'] is int ? json['position'] as int : int.tryParse(json['position']?.toString() ?? '') ?? 0,
      isChecked: json['is_checked'] as bool? ?? false,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'notes': notes,
      'product_id': productId,
      'position': position,
      'is_checked': isChecked,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        quantity,
        notes,
        productId,
        position,
        isChecked,
      ];
}

/// Grocery list model.
class GroceryList extends Equatable {
  /// Unique identifier for the list.
  final String id;

  /// Name of the list.
  final String name;

  /// User ID who owns the list.
  final String userId;

  /// Items in the list.
  final List<GroceryListItem> items;

  /// When the list was created.
  final DateTime createdAt;

  /// When the list was last updated.
  final DateTime updatedAt;

  /// Creates a grocery list.
  const GroceryList({
    required this.id,
    required this.name,
    required this.userId,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy with updated fields.
  GroceryList copyWith({
    String? id,
    String? name,
    String? userId,
    List<GroceryListItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GroceryList(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates a list from JSON.
  factory GroceryList.fromJson(Map<String, dynamic> json) {
    return GroceryList(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String,
      userId: json['user_id'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => GroceryListItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'user_id': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get the total number of items.
  int get itemCount => items.length;

  /// Get the number of checked items.
  int get checkedItemCount => items.where((item) => item.isChecked).length;

  @override
  List<Object?> get props => [id, name, userId, items, createdAt, updatedAt];
}

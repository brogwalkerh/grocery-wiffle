import 'package:equatable/equatable.dart';

/// Product model for autocomplete and matching.
class Product extends Equatable {
  /// Unique identifier.
  final int id;

  /// Product name.
  final String name;

  /// Brand name.
  final String? brand;

  /// Product category.
  final String? category;

  /// UPC code.
  final String? upc;

  /// Unit size.
  final double? unitSize;

  /// Unit type.
  final String? unitType;

  /// Creates a product.
  const Product({
    required this.id,
    required this.name,
    this.brand,
    this.category,
    this.upc,
    this.unitSize,
    this.unitType,
  });

  /// Creates from JSON.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      category: json['category'] as String?,
      upc: json['upc'] as String?,
      unitSize: (json['unit_size'] as num?)?.toDouble(),
      unitType: json['unit_type'] as String?,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'category': category,
      'upc': upc,
      'unit_size': unitSize,
      'unit_type': unitType,
    };
  }

  /// Get display name with brand.
  String get displayName {
    if (brand != null && brand!.isNotEmpty) {
      return '$brand $name';
    }
    return name;
  }

  /// Get size description.
  String? get sizeDescription {
    if (unitSize != null && unitType != null) {
      return '${unitSize!.toStringAsFixed(unitSize! == unitSize!.truncateToDouble() ? 0 : 1)} $unitType';
    }
    return null;
  }

  @override
  List<Object?> get props => [id, name, brand, category, upc, unitSize, unitType];
}

/// Product search result with match score.
class ProductSearchResult extends Equatable {
  /// The matched product.
  final Product product;

  /// Match confidence score (0-100).
  final double score;

  /// Creates a product search result.
  const ProductSearchResult({
    required this.product,
    required this.score,
  });

  /// Creates from JSON.
  factory ProductSearchResult.fromJson(Map<String, dynamic> json) {
    return ProductSearchResult(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      score: (json['score'] as num).toDouble(),
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'score': score,
    };
  }

  @override
  List<Object?> get props => [product, score];
}

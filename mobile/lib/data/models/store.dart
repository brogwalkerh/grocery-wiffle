import 'package:equatable/equatable.dart';

/// Store model.
class Store extends Equatable {
  /// Unique identifier for the store.
  final int id;

  /// Store name.
  final String name;

  /// Store chain name.
  final String chain;

  /// Store address.
  final String? address;

  /// Store ZIP code.
  final String zipCode;

  /// Latitude coordinate.
  final double? lat;

  /// Longitude coordinate.
  final double? lng;

  /// Creates a store.
  const Store({
    required this.id,
    required this.name,
    required this.chain,
    this.address,
    required this.zipCode,
    this.lat,
    this.lng,
  });

  /// Creates a store from JSON.
  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as int,
      name: json['name'] as String,
      chain: json['chain'] as String,
      address: json['address'] as String?,
      zipCode: json['zip_code'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'chain': chain,
      'address': address,
      'zip_code': zipCode,
      'lat': lat,
      'lng': lng,
    };
  }

  @override
  List<Object?> get props => [id, name, chain, address, zipCode, lat, lng];
}

/// Store price for an item.
class StorePrice extends Equatable {
  /// Store ID.
  final int storeId;

  /// Store name.
  final String storeName;

  /// Store chain.
  final String storeChain;

  /// Regular price.
  final double regularPrice;

  /// Current price (may include sale).
  final double currentPrice;

  /// Whether the item is on sale.
  final bool isOnSale;

  /// When the sale expires.
  final DateTime? saleExpires;

  /// Unit price.
  final double? unitPrice;

  /// Creates a store price.
  const StorePrice({
    required this.storeId,
    required this.storeName,
    required this.storeChain,
    required this.regularPrice,
    required this.currentPrice,
    this.isOnSale = false,
    this.saleExpires,
    this.unitPrice,
  });

  /// Creates a store price from JSON.
  factory StorePrice.fromJson(Map<String, dynamic> json) {
    return StorePrice(
      storeId: json['store_id'] as int,
      storeName: json['store_name'] as String,
      storeChain: json['store_chain'] as String,
      regularPrice: (json['regular_price'] as num).toDouble(),
      currentPrice: (json['current_price'] as num).toDouble(),
      isOnSale: json['is_on_sale'] as bool? ?? false,
      saleExpires: json['sale_expires'] != null
          ? DateTime.parse(json['sale_expires'] as String)
          : null,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'store_id': storeId,
      'store_name': storeName,
      'store_chain': storeChain,
      'regular_price': regularPrice,
      'current_price': currentPrice,
      'is_on_sale': isOnSale,
      'sale_expires': saleExpires?.toIso8601String(),
      'unit_price': unitPrice,
    };
  }

  /// Calculate savings if on sale.
  double get savings => isOnSale ? regularPrice - currentPrice : 0;

  @override
  List<Object?> get props => [
        storeId,
        storeName,
        storeChain,
        regularPrice,
        currentPrice,
        isOnSale,
        saleExpires,
        unitPrice,
      ];
}

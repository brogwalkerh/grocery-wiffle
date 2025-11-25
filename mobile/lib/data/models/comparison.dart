import 'package:equatable/equatable.dart';

import 'store.dart';

/// Item-level price comparison.
class ItemPriceComparison extends Equatable {
  /// Item name.
  final String itemName;

  /// Product ID if matched.
  final int? productId;

  /// Quantity.
  final double quantity;

  /// Unit of measurement.
  final String? unit;

  /// Match confidence score (0-100).
  final double matchConfidence;

  /// Prices at each store.
  final List<StorePrice> pricesByStore;

  /// ID of the store with the cheapest price.
  final int? cheapestStoreId;

  /// Creates an item price comparison.
  const ItemPriceComparison({
    required this.itemName,
    this.productId,
    required this.quantity,
    this.unit,
    required this.matchConfidence,
    required this.pricesByStore,
    this.cheapestStoreId,
  });

  /// Creates from JSON.
  factory ItemPriceComparison.fromJson(Map<String, dynamic> json) {
    return ItemPriceComparison(
      itemName: json['item_name'] as String,
      productId: json['product_id'] as int?,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String?,
      matchConfidence: (json['match_confidence'] as num).toDouble(),
      pricesByStore: (json['prices_by_store'] as List<dynamic>)
          .map((price) => StorePrice.fromJson(price as Map<String, dynamic>))
          .toList(),
      cheapestStoreId: json['cheapest_store_id'] as int?,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'item_name': itemName,
      'product_id': productId,
      'quantity': quantity,
      'unit': unit,
      'match_confidence': matchConfidence,
      'prices_by_store': pricesByStore.map((p) => p.toJson()).toList(),
      'cheapest_store_id': cheapestStoreId,
    };
  }

  /// Get the cheapest price for this item.
  StorePrice? get cheapestPrice {
    if (cheapestStoreId == null) return null;
    return pricesByStore.cast<StorePrice?>().firstWhere(
          (p) => p?.storeId == cheapestStoreId,
          orElse: () => null,
        );
  }

  /// Get the total price for this item (quantity * price).
  double getTotalPrice(int storeId) {
    final storePrice = pricesByStore.cast<StorePrice?>().firstWhere(
          (p) => p?.storeId == storeId,
          orElse: () => null,
        );
    return storePrice != null ? storePrice.currentPrice * quantity : 0;
  }

  @override
  List<Object?> get props => [
        itemName,
        productId,
        quantity,
        unit,
        matchConfidence,
        pricesByStore,
        cheapestStoreId,
      ];
}

/// Store total in comparison results.
class StoreTotalComparison extends Equatable {
  /// Store ID.
  final int storeId;

  /// Store name.
  final String storeName;

  /// Store chain.
  final String storeChain;

  /// Store address.
  final String? storeAddress;

  /// Total price for all items.
  final double totalPrice;

  /// Number of items found at this store.
  final int itemsFound;

  /// Number of items on sale.
  final int itemsOnSale;

  /// Whether this is the cheapest store.
  final bool isCheapest;

  /// Creates a store total comparison.
  const StoreTotalComparison({
    required this.storeId,
    required this.storeName,
    required this.storeChain,
    this.storeAddress,
    required this.totalPrice,
    required this.itemsFound,
    required this.itemsOnSale,
    this.isCheapest = false,
  });

  /// Creates from JSON.
  factory StoreTotalComparison.fromJson(Map<String, dynamic> json) {
    return StoreTotalComparison(
      storeId: json['store_id'] as int,
      storeName: json['store_name'] as String,
      storeChain: json['store_chain'] as String,
      storeAddress: json['store_address'] as String?,
      totalPrice: (json['total_price'] as num).toDouble(),
      itemsFound: json['items_found'] as int,
      itemsOnSale: json['items_on_sale'] as int,
      isCheapest: json['is_cheapest'] as bool? ?? false,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'store_id': storeId,
      'store_name': storeName,
      'store_chain': storeChain,
      'store_address': storeAddress,
      'total_price': totalPrice,
      'items_found': itemsFound,
      'items_on_sale': itemsOnSale,
      'is_cheapest': isCheapest,
    };
  }

  @override
  List<Object?> get props => [
        storeId,
        storeName,
        storeChain,
        storeAddress,
        totalPrice,
        itemsFound,
        itemsOnSale,
        isCheapest,
      ];
}

/// Full comparison response.
class ComparisonResult extends Equatable {
  /// List ID.
  final int listId;

  /// List name.
  final String listName;

  /// ZIP code used for comparison.
  final String zipCode;

  /// Store totals.
  final List<StoreTotalComparison> storeTotals;

  /// Item-by-item breakdown.
  final List<ItemPriceComparison> itemBreakdown;

  /// ID of the cheapest store overall.
  final int? cheapestStoreId;

  /// Potential savings vs most expensive option.
  final double potentialSavings;

  /// Creates a comparison result.
  const ComparisonResult({
    required this.listId,
    required this.listName,
    required this.zipCode,
    required this.storeTotals,
    required this.itemBreakdown,
    this.cheapestStoreId,
    required this.potentialSavings,
  });

  /// Creates from JSON.
  factory ComparisonResult.fromJson(Map<String, dynamic> json) {
    return ComparisonResult(
      listId: json['list_id'] as int,
      listName: json['list_name'] as String,
      zipCode: json['zip_code'] as String,
      storeTotals: (json['store_totals'] as List<dynamic>)
          .map((st) => StoreTotalComparison.fromJson(st as Map<String, dynamic>))
          .toList(),
      itemBreakdown: (json['item_breakdown'] as List<dynamic>)
          .map((ib) => ItemPriceComparison.fromJson(ib as Map<String, dynamic>))
          .toList(),
      cheapestStoreId: json['cheapest_store_id'] as int?,
      potentialSavings: (json['potential_savings'] as num).toDouble(),
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'list_id': listId,
      'list_name': listName,
      'zip_code': zipCode,
      'store_totals': storeTotals.map((st) => st.toJson()).toList(),
      'item_breakdown': itemBreakdown.map((ib) => ib.toJson()).toList(),
      'cheapest_store_id': cheapestStoreId,
      'potential_savings': potentialSavings,
    };
  }

  /// Get the cheapest store.
  StoreTotalComparison? get cheapestStore {
    if (cheapestStoreId == null) return null;
    return storeTotals.cast<StoreTotalComparison?>().firstWhere(
          (st) => st?.storeId == cheapestStoreId,
          orElse: () => null,
        );
  }

  @override
  List<Object?> get props => [
        listId,
        listName,
        zipCode,
        storeTotals,
        itemBreakdown,
        cheapestStoreId,
        potentialSavings,
      ];
}

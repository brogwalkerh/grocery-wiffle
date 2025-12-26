import '../models/comparison.dart';
import '../models/grocery_list.dart';
import '../models/store.dart';
import 'price_aggregator.dart';

/// Compares prices for grocery list items across multiple stores.
/// 
/// For each item, finds the cheapest option at each store and calculates
/// the total cost based on quantity.
class LocalComparisonEngine {
  final PriceAggregator _priceAggregator;

  /// Create a comparison engine with the default price aggregator.
  LocalComparisonEngine() : _priceAggregator = PriceAggregator();
  
  /// Create a comparison engine with a custom price aggregator (for testing).
  LocalComparisonEngine.withAggregator(this._priceAggregator);

  /// Compare prices for all items in a grocery list.
  Future<ComparisonResult> comparePrices({
    required GroceryList groceryList,
    required String zipCode,
    int radiusMiles = 10,
    Function(String itemName, int current, int total)? onProgress,
  }) async {
    final itemBreakdown = <ItemPriceComparison>[];
    final storeTotals = <int, _MutableStoreTotalComparison>{};

    int storeIdCounter = 1;
    final storeIdMap = <String, int>{}; // storeLocationKey -> storeId

    // Process each item in the list
    for (int i = 0; i < groceryList.items.length; i++) {
      final item = groceryList.items[i];
      
      if (onProgress != null) {
        onProgress(item.name, i + 1, groceryList.items.length);
      }

      try {
        // Search for this item using the multi-store price aggregator
        final priceResults = await _priceAggregator.searchPrices(
          item.name,
          zipCode: zipCode,
        );

        if (priceResults.isEmpty) {
          // No results found for this item
          itemBreakdown.add(ItemPriceComparison(
            itemName: item.name,
            productId: null,
            quantity: item.quantity,
            productSize: null,
            matchConfidence: 0.0,
            pricesByStore: const [],
            cheapestStoreId: null,
          ));
          continue;
        }

        final pricesByStore = <StorePrice>[];
        double? cheapestPrice;
        int? cheapestStoreId;
        String? foundProductSize;

        // Group results by store and find best (cheapest) match per store
        final resultsByStore = <String, PriceResult>{};
        for (final result in priceResults) {
          final storeKey = '${result.storeChain}_${result.storeName}';
          
          // Keep the cheapest result with a price for each store
          if (!resultsByStore.containsKey(storeKey)) {
            resultsByStore[storeKey] = result;
          } else if (result.price != null) {
            final existing = resultsByStore[storeKey]!;
            if (existing.price == null || result.price! < existing.price!) {
              resultsByStore[storeKey] = result;
            }
          }
        }

        for (final entry in resultsByStore.entries) {
          final result = entry.value;
          final storeKey = entry.key;

          // Get or create store ID
          if (!storeIdMap.containsKey(storeKey)) {
            storeIdMap[storeKey] = storeIdCounter++;
          }
          final storeId = storeIdMap[storeKey]!;

          // Initialize store total if needed
          if (!storeTotals.containsKey(storeId)) {
            storeTotals[storeId] = _MutableStoreTotalComparison(
              storeId: storeId,
              storeName: result.storeName,
              storeChain: result.storeChain,
              storeAddress: null,
            );
          }

          // Skip if no price available
          if (result.price == null) continue;

          final currentPrice = result.price!;
          
          // Simple calculation: price * quantity
          final itemTotal = currentPrice * item.quantity;

          pricesByStore.add(StorePrice(
            storeId: storeId,
            storeName: result.storeName,
            storeChain: result.storeChain,
            regularPrice: result.originalPrice ?? currentPrice,
            currentPrice: currentPrice,
            isOnSale: result.isOnSale,
            saleExpires: null,
            unitPrice: null,
            calculatedTotal: itemTotal,
            productSize: result.size, // Store the product size found
            isEstimate: result.isEstimate, // Pass through estimate flag
          ));

          // Update store totals
          storeTotals[storeId]!.totalPrice += itemTotal;
          storeTotals[storeId]!.itemsFound += 1;
          if (result.isOnSale) {
            storeTotals[storeId]!.itemsOnSale += 1;
          }

          // Track cheapest and its size
          if (cheapestPrice == null || currentPrice < cheapestPrice) {
            cheapestPrice = currentPrice;
            cheapestStoreId = storeId;
            foundProductSize = result.size;
          }
        }

        // Calculate match confidence based on name similarity
        final bestMatch = priceResults.first;
        final matchConfidence = _calculateMatchConfidence(item.name, bestMatch.productName);

        itemBreakdown.add(ItemPriceComparison(
          itemName: item.name,
          productId: null,
          quantity: item.quantity,
          productSize: foundProductSize, // Size of the cheapest product found
          matchConfidence: matchConfidence,
          pricesByStore: pricesByStore,
          cheapestStoreId: cheapestStoreId,
        ));
      } catch (e) {
        print('Error searching for ${item.name}: $e');
        itemBreakdown.add(ItemPriceComparison(
          itemName: item.name,
          productId: null,
          quantity: item.quantity,
          productSize: null,
          matchConfidence: 0.0,
          pricesByStore: const [],
          cheapestStoreId: null,
        ));
      }
    }

    // Build store totals list
    final totalItems = groceryList.items.length;
    final storeTotalsList = storeTotals.values.map((st) {
      return StoreTotalComparison(
        storeId: st.storeId,
        storeName: st.storeName,
        storeChain: st.storeChain,
        storeAddress: st.storeAddress,
        totalPrice: double.parse(st.totalPrice.toStringAsFixed(2)),
        itemsFound: st.itemsFound,
        itemsOnSale: st.itemsOnSale,
        hasAllItems: st.itemsFound >= totalItems,
        isCheapest: false,
        estimatedDriveTimeMinutes: null,
        distanceMiles: null,
      );
    }).toList();

    // Sort by total price
    storeTotalsList.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));

    // Mark cheapest
    int? cheapestStoreId;
    int? cheapestCompleteStoreId;
    double potentialSavings = 0;

    if (storeTotalsList.isNotEmpty) {
      // Mark overall cheapest
      final cheapest = storeTotalsList.first;
      cheapestStoreId = cheapest.storeId;

      // Find cheapest complete store
      final completeStores = storeTotalsList.where((st) => st.hasAllItems).toList();
      if (completeStores.isNotEmpty) {
        cheapestCompleteStoreId = completeStores.first.storeId;
      }

      // Calculate potential savings
      if (storeTotalsList.length > 1) {
        potentialSavings = storeTotalsList.last.totalPrice - storeTotalsList.first.totalPrice;
      }
    }

    // Update isCheapest flag
    final updatedStoreTotals = storeTotalsList.map((st) {
      if (st.storeId == cheapestStoreId) {
        return StoreTotalComparison(
          storeId: st.storeId,
          storeName: st.storeName,
          storeChain: st.storeChain,
          storeAddress: st.storeAddress,
          totalPrice: st.totalPrice,
          itemsFound: st.itemsFound,
          itemsOnSale: st.itemsOnSale,
          hasAllItems: st.hasAllItems,
          isCheapest: true,
          estimatedDriveTimeMinutes: st.estimatedDriveTimeMinutes,
          distanceMiles: st.distanceMiles,
        );
      }
      return st;
    }).toList();

    return ComparisonResult(
      listId: int.tryParse(groceryList.id) ?? 0,
      listName: groceryList.name,
      zipCode: zipCode,
      totalItems: totalItems,
      storeTotals: updatedStoreTotals,
      itemBreakdown: itemBreakdown,
      cheapestStoreId: cheapestStoreId,
      cheapestCompleteStoreId: cheapestCompleteStoreId,
      potentialSavings: double.parse(potentialSavings.toStringAsFixed(2)),
    );
  }

  /// Calculate match confidence between search term and result name.
  double _calculateMatchConfidence(String searchTerm, String resultName) {
    final searchLower = searchTerm.toLowerCase().trim();
    final resultLower = resultName.toLowerCase().trim();

    // Exact match
    if (searchLower == resultLower) return 100.0;

    // Contains the search term
    if (resultLower.contains(searchLower)) return 90.0;

    // Search term contains result (e.g., "whole milk" contains "milk")
    if (searchLower.contains(resultLower)) return 85.0;

    // Check word overlap
    final searchWords = searchLower.split(RegExp(r'\s+'));
    final resultWords = resultLower.split(RegExp(r'\s+'));
    
    int matchingWords = 0;
    for (final word in searchWords) {
      if (word.length < 3) continue; // Skip short words
      if (resultWords.any((rw) => rw.contains(word) || word.contains(rw))) {
        matchingWords++;
      }
    }

    if (searchWords.isNotEmpty) {
      return (matchingWords / searchWords.length * 80).clamp(0, 80);
    }

    return 50.0; // Default moderate confidence
  }
}

/// Mutable helper class for building store totals.
class _MutableStoreTotalComparison {
  final int storeId;
  final String storeName;
  final String storeChain;
  final String? storeAddress;
  double totalPrice = 0.0;
  int itemsFound = 0;
  int itemsOnSale = 0;

  _MutableStoreTotalComparison({
    required this.storeId,
    required this.storeName,
    required this.storeChain,
    this.storeAddress,
  });
}

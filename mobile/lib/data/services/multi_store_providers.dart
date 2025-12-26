import 'dart:convert';
import 'package:http/http.dart' as http;

import 'grocery_search_service.dart';

/// Search provider that scrapes Walmart's public product pages.
/// No API key required - uses public web data.
class WalmartWebProvider implements GrocerySearchProvider {
  final http.Client _httpClient;
  
  // Walmart's internal API endpoint (publicly accessible)
  // ignore: unused_field
  static const String _searchUrl = 'https://www.walmart.com/orchestra/home/graphql/search';

  WalmartWebProvider({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  String get providerName => 'Walmart';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreLocation>> findStores(
    String zipCode, {
    int radiusMiles = 10,
    int limit = 5,
  }) async {
    // Walmart stores can be found via their store finder
    // For now, return a generic Walmart entry
    return [
      StoreLocation(
        id: 'walmart_$zipCode',
        name: 'Walmart',
        chain: 'Walmart',
        address: 'Near $zipCode',
      ),
    ];
  }

  @override
  Future<List<GrocerySearchResult>> searchProducts(
    String term, {
    String? locationId,
    int limit = 10,
  }) async {
    try {
      // Use Walmart's search suggestions API (publicly accessible)
      final searchUrl = Uri.parse(
        'https://www.walmart.com/typeahead/v1/searchresults?query=${Uri.encodeComponent(term)}&limit=$limit'
      );

      final response = await _httpClient.get(
        searchUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      final results = <GrocerySearchResult>[];

      // Parse typeahead results
      final suggestions = data['suggestionGroups'] as List?;
      if (suggestions != null) {
        for (final group in suggestions) {
          final items = group['suggestions'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item['type'] == 'PRODUCT') {
                results.add(GrocerySearchResult(
                  productId: item['productId']?.toString() ?? '',
                  name: item['title'] ?? term,
                  brand: null,
                  description: item['title'],
                  imageUrl: item['imageUrl'],
                  size: null,
                  upc: null,
                  price: null, // Price requires product page
                  salePrice: null,
                  isOnSale: false,
                  storeName: 'Walmart',
                  storeChain: 'Walmart',
                  storeLocation: null,
                  stockLevel: null,
                ));
              }
            }
          }
        }
      }

      return results.take(limit).toList();
    } catch (e) {
      print('Walmart search error: $e');
      return [];
    }
  }
}

/// Search provider using Google Shopping results.
/// Aggregates prices from multiple stores.
class GoogleShoppingProvider implements GrocerySearchProvider {
  final http.Client _httpClient;

  GoogleShoppingProvider({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  String get providerName => 'Google Shopping';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreLocation>> findStores(
    String zipCode, {
    int radiusMiles = 10,
    int limit = 5,
  }) async {
    // Google Shopping doesn't have physical stores
    return [];
  }

  @override
  Future<List<GrocerySearchResult>> searchProducts(
    String term, {
    String? locationId,
    int limit = 10,
  }) async {
    try {
      // Use DuckDuckGo as a proxy for shopping results (no API key needed)
      final searchUrl = Uri.parse(
        'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent("$term price grocery")}'
      );

      final response = await _httpClient.get(
        searchUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      // Parse results - this is a simplified example
      // Real implementation would parse the HTML
      return [];
    } catch (e) {
      print('Google Shopping search error: $e');
      return [];
    }
  }
}

/// Search provider that uses Open Food Facts database.
/// Free, open-source database with product information.
class OpenFoodFactsProvider implements GrocerySearchProvider {
  final http.Client _httpClient;
  
  static const String _baseUrl = 'https://world.openfoodfacts.org';

  OpenFoodFactsProvider({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  String get providerName => 'Open Food Facts';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreLocation>> findStores(
    String zipCode, {
    int radiusMiles = 10,
    int limit = 5,
  }) async {
    // Open Food Facts is a product database, not store-specific
    return [];
  }

  @override
  Future<List<GrocerySearchResult>> searchProducts(
    String term, {
    String? locationId,
    int limit = 10,
  }) async {
    try {
      final searchUrl = Uri.parse(
        '$_baseUrl/cgi/search.pl?search_terms=${Uri.encodeComponent(term)}&search_simple=1&action=process&json=1&page_size=$limit'
      );

      final response = await _httpClient.get(
        searchUrl,
        headers: {
          'User-Agent': 'GroceryCompare/1.0 (Flutter App)',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      final products = data['products'] as List?;
      
      if (products == null) return [];

      return products.map((product) {
        return GrocerySearchResult(
          productId: product['code']?.toString() ?? '',
          name: product['product_name'] ?? term,
          brand: product['brands'],
          description: product['generic_name'],
          imageUrl: product['image_front_small_url'],
          size: product['quantity'],
          upc: product['code'],
          price: null, // Open Food Facts doesn't have prices
          salePrice: null,
          isOnSale: false,
          storeName: 'Various',
          storeChain: 'Open Food Facts',
          storeLocation: null,
          stockLevel: null,
        );
      }).take(limit).toList();
    } catch (e) {
      print('Open Food Facts search error: $e');
      return [];
    }
  }
}

/// Provider that searches Target's public product catalog.
class TargetWebProvider implements GrocerySearchProvider {
  final http.Client _httpClient;

  TargetWebProvider({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  String get providerName => 'Target';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreLocation>> findStores(
    String zipCode, {
    int radiusMiles = 10,
    int limit = 5,
  }) async {
    return [
      StoreLocation(
        id: 'target_$zipCode',
        name: 'Target',
        chain: 'Target',
        address: 'Near $zipCode',
      ),
    ];
  }

  @override
  Future<List<GrocerySearchResult>> searchProducts(
    String term, {
    String? locationId,
    int limit = 10,
  }) async {
    try {
      // Target's typeahead API
      final searchUrl = Uri.parse(
        'https://redsky.target.com/redsky_aggregations/v1/web/typeahead_search_v1?key=9f36aeafbe60771e321a7cc95a78140772ab3e96&channel=WEB&keyword=${Uri.encodeComponent(term)}&limit=$limit'
      );

      final response = await _httpClient.get(
        searchUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      final results = <GrocerySearchResult>[];

      final suggestions = data['typeahead_suggestions'] as List?;
      if (suggestions != null) {
        for (final suggestion in suggestions) {
          if (suggestion['type'] == 'products') {
            final products = suggestion['suggestions'] as List?;
            if (products != null) {
              for (final product in products) {
                results.add(GrocerySearchResult(
                  productId: product['tcin']?.toString() ?? '',
                  name: product['title'] ?? term,
                  brand: null,
                  description: product['title'],
                  imageUrl: product['image_url'],
                  size: null,
                  upc: null,
                  price: null,
                  salePrice: null,
                  isOnSale: false,
                  storeName: 'Target',
                  storeChain: 'Target',
                  storeLocation: null,
                  stockLevel: null,
                ));
              }
            }
          }
        }
      }

      return results.take(limit).toList();
    } catch (e) {
      print('Target search error: $e');
      return [];
    }
  }
}

/// Provider that scrapes Aldi's public product pages.
class AldiWebProvider implements GrocerySearchProvider {
  final http.Client _httpClient;

  AldiWebProvider({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  String get providerName => 'Aldi';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreLocation>> findStores(
    String zipCode, {
    int radiusMiles = 10,
    int limit = 5,
  }) async {
    return [
      StoreLocation(
        id: 'aldi_$zipCode',
        name: 'Aldi',
        chain: 'Aldi',
        address: 'Near $zipCode',
      ),
    ];
  }

  @override
  Future<List<GrocerySearchResult>> searchProducts(
    String term, {
    String? locationId,
    int limit = 10,
  }) async {
    try {
      // Aldi US search
      final searchUrl = Uri.parse(
        'https://new.aldi.us/api/search?q=${Uri.encodeComponent(term)}&limit=$limit'
      );

      final response = await _httpClient.get(
        searchUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      final results = <GrocerySearchResult>[];

      final products = data['products'] as List?;
      if (products != null) {
        for (final product in products) {
          double? price;
          final priceStr = product['price'];
          if (priceStr != null) {
            price = double.tryParse(priceStr.toString().replaceAll(RegExp(r'[^\d.]'), ''));
          }

          results.add(GrocerySearchResult(
            productId: product['id']?.toString() ?? '',
            name: product['name'] ?? term,
            brand: product['brand'],
            description: product['description'],
            imageUrl: product['image'],
            size: product['size'],
            upc: null,
            price: price,
            salePrice: null,
            isOnSale: false,
            storeName: 'Aldi',
            storeChain: 'Aldi',
            storeLocation: null,
            stockLevel: null,
          ));
        }
      }

      return results.take(limit).toList();
    } catch (e) {
      print('Aldi search error: $e');
      return [];
    }
  }
}

/// Aggregated provider that combines multiple free sources.
class MultiStoreSearchService extends GrocerySearchService {
  MultiStoreSearchService() : super() {
    // Add all free providers
    addProvider(WalmartWebProvider());
    addProvider(TargetWebProvider());
    addProvider(AldiWebProvider());
    addProvider(OpenFoodFactsProvider());
    // Kroger requires API key - added separately if configured
  }
}

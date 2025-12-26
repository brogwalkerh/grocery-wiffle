import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result from a grocery product search.
class GrocerySearchResult {
  final String productId;
  final String name;
  final String? brand;
  final String? description;
  final String? imageUrl;
  final String? size;
  final String? upc;
  final double? price;
  final double? salePrice;
  final bool isOnSale;
  final String storeName;
  final String storeChain;
  final String? storeLocation;
  final String? stockLevel;

  GrocerySearchResult({
    required this.productId,
    required this.name,
    this.brand,
    this.description,
    this.imageUrl,
    this.size,
    this.upc,
    this.price,
    this.salePrice,
    this.isOnSale = false,
    required this.storeName,
    required this.storeChain,
    this.storeLocation,
    this.stockLevel,
  });

  /// Current effective price (sale price if on sale, otherwise regular price).
  double? get currentPrice => isOnSale ? salePrice : price;

  /// Display name with brand if available.
  String get displayName => brand != null ? '$brand $name' : name;
}

/// Store location for searches.
class StoreLocation {
  final String id;
  final String name;
  final String chain;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distanceMiles;

  StoreLocation({
    required this.id,
    required this.name,
    required this.chain,
    this.address,
    this.latitude,
    this.longitude,
    this.distanceMiles,
  });
}

/// Abstract interface for grocery store search providers.
abstract class GrocerySearchProvider {
  String get providerName;
  
  /// Search for products by term at a specific store location.
  Future<List<GrocerySearchResult>> searchProducts(
    String term, {
    String? locationId,
    int limit = 10,
  });

  /// Find store locations near a ZIP code.
  Future<List<StoreLocation>> findStores(
    String zipCode, {
    int radiusMiles = 10,
    int limit = 5,
  });

  /// Check if the provider is configured and available.
  Future<bool> isAvailable();
}

/// Kroger API search provider.
/// 
/// Requires API credentials from https://developer.kroger.com
/// Covers: Kroger, Ralphs, Fred Meyer, Fry's, Smith's, King Soopers,
/// QFC, Mariano's, Pick 'n Save, Metro Market, and more.
class KrogerSearchProvider implements GrocerySearchProvider {
  final String clientId;
  final String clientSecret;
  final http.Client _httpClient;

  String? _accessToken;
  DateTime? _tokenExpiry;

  static const String _baseUrl = 'https://api.kroger.com/v1';
  static const String _authUrl = 'https://api.kroger.com/v1/connect/oauth2/token';

  KrogerSearchProvider({
    required this.clientId,
    required this.clientSecret,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  String get providerName => 'Kroger';

  @override
  Future<bool> isAvailable() async {
    if (clientId.isEmpty || clientSecret.isEmpty) return false;
    try {
      await _ensureAuthenticated();
      return _accessToken != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _ensureAuthenticated() async {
    if (_accessToken != null && 
        _tokenExpiry != null && 
        DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }

    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    
    final response = await _httpClient.post(
      Uri.parse(_authUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic $credentials',
      },
      body: 'grant_type=client_credentials&scope=product.compact',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      final expiresIn = data['expires_in'] as int;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
    } else {
      throw Exception('Failed to authenticate with Kroger API: ${response.body}');
    }
  }

  @override
  Future<List<StoreLocation>> findStores(
    String zipCode, {
    int radiusMiles = 10,
    int limit = 5,
  }) async {
    await _ensureAuthenticated();

    final uri = Uri.parse('$_baseUrl/locations').replace(
      queryParameters: {
        'filter.zipCode.near': zipCode,
        'filter.radiusInMiles': radiusMiles.toString(),
        'filter.limit': limit.toString(),
      },
    );

    final response = await _httpClient.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to find stores: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final stores = <StoreLocation>[];

    for (final store in data['data'] ?? []) {
      final address = store['address'];
      stores.add(StoreLocation(
        id: store['locationId'] ?? '',
        name: store['name'] ?? 'Unknown',
        chain: store['chain'] ?? 'Kroger',
        address: address != null 
            ? '${address['addressLine1']}, ${address['city']}, ${address['state']} ${address['zipCode']}'
            : null,
        latitude: store['geolocation']?['latitude']?.toDouble(),
        longitude: store['geolocation']?['longitude']?.toDouble(),
        distanceMiles: store['distance']?.toDouble(),
      ));
    }

    return stores;
  }

  @override
  Future<List<GrocerySearchResult>> searchProducts(
    String term, {
    String? locationId,
    int limit = 10,
  }) async {
    await _ensureAuthenticated();

    final queryParams = <String, String>{
      'filter.term': term,
      'filter.limit': limit.toString(),
    };

    if (locationId != null) {
      queryParams['filter.locationId'] = locationId;
    }

    final uri = Uri.parse('$_baseUrl/products').replace(
      queryParameters: queryParams,
    );

    final response = await _httpClient.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to search products: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final results = <GrocerySearchResult>[];

    for (final product in data['data'] ?? []) {
      // Get primary image
      String? imageUrl;
      final images = product['images'] as List?;
      if (images != null && images.isNotEmpty) {
        final perspectives = images.first['sizes'] as List?;
        if (perspectives != null && perspectives.isNotEmpty) {
          imageUrl = perspectives.last['url'];
        }
      }

      // Get size from items
      String? size;
      final items = product['items'] as List?;
      if (items != null && items.isNotEmpty) {
        final item = items.first;
        final itemSize = item['size'];
        if (itemSize != null) {
          size = itemSize;
        }
      }

      // Get price if locationId was provided
      double? price;
      double? salePrice;
      bool isOnSale = false;
      final priceData = items?.first?['price'];
      if (priceData != null) {
        price = priceData['regular']?.toDouble();
        salePrice = priceData['promo']?.toDouble();
        isOnSale = salePrice != null && salePrice > 0 && salePrice < (price ?? 0);
      }

      // Get stock level
      String? stockLevel;
      final fulfillment = items?.first?['fulfillment'];
      if (fulfillment != null) {
        stockLevel = fulfillment['stockLevel'];
      }

      results.add(GrocerySearchResult(
        productId: product['productId'] ?? '',
        name: product['description'] ?? 'Unknown Product',
        brand: product['brand'],
        description: product['description'],
        imageUrl: imageUrl,
        size: size,
        upc: product['upc'],
        price: price,
        salePrice: isOnSale ? salePrice : null,
        isOnSale: isOnSale,
        storeName: 'Kroger',
        storeChain: 'Kroger',
        stockLevel: stockLevel,
      ));
    }

    return results;
  }
}

/// Aggregated grocery search service that combines multiple providers.
class GrocerySearchService {
  final List<GrocerySearchProvider> _providers;
  final Map<String, List<StoreLocation>> _storeCache = {};

  GrocerySearchService({List<GrocerySearchProvider>? providers})
      : _providers = providers ?? [];

  /// Add a search provider.
  void addProvider(GrocerySearchProvider provider) {
    _providers.add(provider);
  }

  /// Get all available providers.
  Future<List<GrocerySearchProvider>> getAvailableProviders() async {
    final available = <GrocerySearchProvider>[];
    for (final provider in _providers) {
      if (await provider.isAvailable()) {
        available.add(provider);
      }
    }
    return available;
  }

  /// Find all stores near a ZIP code from all providers.
  Future<List<StoreLocation>> findAllStores(
    String zipCode, {
    int radiusMiles = 10,
    int limitPerProvider = 5,
  }) async {
    // Check cache first
    if (_storeCache.containsKey(zipCode)) {
      return _storeCache[zipCode]!;
    }

    final allStores = <StoreLocation>[];

    for (final provider in _providers) {
      try {
        if (await provider.isAvailable()) {
          final stores = await provider.findStores(
            zipCode,
            radiusMiles: radiusMiles,
            limit: limitPerProvider,
          );
          allStores.addAll(stores);
        }
      } catch (e) {
        // Log error but continue with other providers
        print('Error finding stores from ${provider.providerName}: $e');
      }
    }

    // Sort by distance
    allStores.sort((a, b) {
      if (a.distanceMiles == null && b.distanceMiles == null) return 0;
      if (a.distanceMiles == null) return 1;
      if (b.distanceMiles == null) return -1;
      return a.distanceMiles!.compareTo(b.distanceMiles!);
    });

    _storeCache[zipCode] = allStores;
    return allStores;
  }

  /// Search for a product across all stores.
  Future<List<GrocerySearchResult>> searchProduct(
    String term, {
    required String zipCode,
    int radiusMiles = 10,
    int maxStores = 5,
  }) async {
    final stores = await findAllStores(
      zipCode,
      radiusMiles: radiusMiles,
      limitPerProvider: maxStores,
    );

    final allResults = <GrocerySearchResult>[];
    final seenProductsAtStore = <String>{};

    for (final provider in _providers) {
      try {
        if (!await provider.isAvailable()) continue;

        // Get stores for this provider
        final providerStores = stores
            .where((s) => s.chain.toLowerCase().contains(provider.providerName.toLowerCase()) ||
                         provider.providerName.toLowerCase().contains(s.chain.toLowerCase()))
            .take(maxStores)
            .toList();

        // If no matching stores, search without location
        if (providerStores.isEmpty) {
          final results = await provider.searchProducts(term, limit: 10);
          for (final result in results) {
            final key = '${result.productId}_${result.storeChain}';
            if (!seenProductsAtStore.contains(key)) {
              seenProductsAtStore.add(key);
              allResults.add(result);
            }
          }
        } else {
          // Search at each store location
          for (final store in providerStores) {
            final results = await provider.searchProducts(
              term,
              locationId: store.id,
              limit: 5,
            );

            for (var result in results) {
              final key = '${result.productId}_${store.id}';
              if (!seenProductsAtStore.contains(key)) {
                seenProductsAtStore.add(key);
                // Update store info
                allResults.add(GrocerySearchResult(
                  productId: result.productId,
                  name: result.name,
                  brand: result.brand,
                  description: result.description,
                  imageUrl: result.imageUrl,
                  size: result.size,
                  upc: result.upc,
                  price: result.price,
                  salePrice: result.salePrice,
                  isOnSale: result.isOnSale,
                  storeName: store.name,
                  storeChain: store.chain,
                  storeLocation: store.address,
                  stockLevel: result.stockLevel,
                ));
              }
            }
          }
        }
      } catch (e) {
        print('Error searching ${provider.providerName}: $e');
      }
    }

    // Sort by price
    allResults.sort((a, b) {
      if (a.currentPrice == null && b.currentPrice == null) return 0;
      if (a.currentPrice == null) return 1;
      if (b.currentPrice == null) return -1;
      return a.currentPrice!.compareTo(b.currentPrice!);
    });

    return allResults;
  }

  /// Clear the store cache.
  void clearCache() {
    _storeCache.clear();
  }
}

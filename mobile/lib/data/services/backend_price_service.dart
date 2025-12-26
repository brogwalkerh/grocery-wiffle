import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Service for connecting to the backend price API.
/// 
/// The backend crawls prices server-side and caches them in a database,
/// then pushes updates to connected clients.
class BackendPriceService {
  final String baseUrl;
  final http.Client _httpClient;
  
  /// Timeout for HTTP requests
  static const _timeout = Duration(seconds: 10);

  BackendPriceService({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Search for prices from the backend cache.
  /// 
  /// [query] - Product name to search for
  /// [maxAgeHours] - Maximum age of cached prices (default 24 hours)
  /// [forceCrawl] - If true, triggers a fresh crawl instead of using cache
  Future<PriceSearchResponse> searchPrices(
    String query, {
    int maxAgeHours = 24,
    bool forceCrawl = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/prices/search').replace(
      queryParameters: {
        'q': query,
        'max_age_hours': maxAgeHours.toString(),
        'force_crawl': forceCrawl.toString(),
      },
    );

    try {
      final response = await _httpClient.get(uri).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PriceSearchResponse.fromJson(json);
      } else {
        throw BackendException(
          'Search failed',
          statusCode: response.statusCode,
          body: response.body,
        );
      }
    } on TimeoutException {
      throw BackendException('Request timed out');
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException('Network error: $e');
    }
  }

  /// Get cached prices only (no crawling).
  Future<PriceSearchResponse> getCachedPrices(
    String query, {
    int maxAgeDays = 7,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/prices/cached').replace(
      queryParameters: {
        'q': query,
        'max_age_days': maxAgeDays.toString(),
      },
    );

    try {
      final response = await _httpClient.get(uri).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PriceSearchResponse.fromJson(json);
      } else {
        throw BackendException(
          'Failed to get cached prices',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw BackendException('Request timed out');
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException('Network error: $e');
    }
  }

  /// Request a price crawl for a product (queued for background processing).
  Future<void> requestCrawl(String query, {int priority = 1}) async {
    final uri = Uri.parse('$baseUrl/api/v1/prices/crawl');

    try {
      final response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'priority': priority,
        }),
      ).timeout(_timeout);
      
      if (response.statusCode != 200) {
        throw BackendException(
          'Failed to request crawl',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw BackendException('Request timed out');
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException('Network error: $e');
    }
  }

  /// Search for prices for multiple products at once.
  Future<Map<String, List<BackendPriceResult>>> batchSearch(
    List<String> products,
  ) async {
    final uri = Uri.parse('$baseUrl/api/v1/prices/batch-search').replace(
      queryParameters: {
        'products': products,
      },
    );

    try {
      final response = await _httpClient.get(uri).timeout(
        const Duration(seconds: 30), // Longer timeout for batch
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final productsMap = json['products'] as Map<String, dynamic>;
        
        return productsMap.map((key, value) {
          final prices = (value as List)
              .map((p) => BackendPriceResult.fromJson(p as Map<String, dynamic>))
              .toList();
          return MapEntry(key, prices);
        });
      } else {
        throw BackendException(
          'Batch search failed',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw BackendException('Request timed out');
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException('Network error: $e');
    }
  }

  /// Get crawler scheduler statistics.
  Future<SchedulerStats> getSchedulerStats() async {
    final uri = Uri.parse('$baseUrl/api/v1/prices/scheduler/stats');

    try {
      final response = await _httpClient.get(uri).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SchedulerStats.fromJson(json);
      } else {
        throw BackendException(
          'Failed to get stats',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException('Network error: $e');
    }
  }

  /// Check if the backend is healthy.
  Future<bool> healthCheck() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Search for deals from weekly circulars (Flipp API).
  /// 
  /// These are real, current sale prices that stores are actively advertising.
  /// This is the most reliable source of price data.
  Future<CircularSearchResponse> searchDeals(
    String query, {
    String zipCode = '92117',
  }) async {
    final uri = Uri.parse('$baseUrl/api/deals/search').replace(
      queryParameters: {
        'q': query,
        'zip_code': zipCode,
      },
    );

    try {
      final response = await _httpClient.get(uri).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return CircularSearchResponse.fromJson(json);
      } else {
        throw BackendException(
          'Deals search failed',
          statusCode: response.statusCode,
          body: response.body,
        );
      }
    } on TimeoutException {
      throw BackendException('Request timed out');
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException('Network error: $e');
    }
  }

  /// Get all current deals for a specific store chain.
  Future<List<CircularDeal>> getStoreDeals(
    String storeChain, {
    String zipCode = '92117',
  }) async {
    final uri = Uri.parse('$baseUrl/api/deals/store/$storeChain').replace(
      queryParameters: {
        'zip_code': zipCode,
      },
    );

    try {
      final response = await _httpClient.get(uri).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final deals = json['deals'] as List;
        return deals
            .map((d) => CircularDeal.fromJson(d as Map<String, dynamic>))
            .toList();
      } else {
        throw BackendException(
          'Failed to get store deals',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw BackendException('Request timed out');
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException('Network error: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}


// ================================================================
// MODELS
// ================================================================

class BackendPriceResult {
  final String productName;
  final double price;
  final double? originalPrice;
  final bool isOnSale;
  final String? size;
  final String storeChain;
  final String storeName;
  final String? updatedAt;

  BackendPriceResult({
    required this.productName,
    required this.price,
    this.originalPrice,
    this.isOnSale = false,
    this.size,
    required this.storeChain,
    required this.storeName,
    this.updatedAt,
  });

  factory BackendPriceResult.fromJson(Map<String, dynamic> json) {
    return BackendPriceResult(
      productName: json['product_name'] as String,
      price: (json['price'] as num).toDouble(),
      originalPrice: json['original_price'] != null
          ? (json['original_price'] as num).toDouble()
          : null,
      isOnSale: json['is_on_sale'] as bool? ?? false,
      size: json['size'] as String?,
      storeChain: json['store_chain'] as String,
      storeName: json['store_name'] as String,
      updatedAt: json['updated_at'] as String?,
    );
  }
}


class PriceSearchResponse {
  final String query;
  final List<BackendPriceResult> results;
  final bool fromCache;
  final String? crawledAt;

  PriceSearchResponse({
    required this.query,
    required this.results,
    required this.fromCache,
    this.crawledAt,
  });

  factory PriceSearchResponse.fromJson(Map<String, dynamic> json) {
    return PriceSearchResponse(
      query: json['query'] as String,
      results: (json['results'] as List)
          .map((r) => BackendPriceResult.fromJson(r as Map<String, dynamic>))
          .toList(),
      fromCache: json['from_cache'] as bool,
      crawledAt: json['crawled_at'] as String?,
    );
  }
}


class SchedulerStats {
  final int totalCrawls;
  final int successfulCrawls;
  final int failedCrawls;
  final double successRate;
  final int queueLength;
  final int scheduledJobs;
  final String? lastCrawl;

  SchedulerStats({
    required this.totalCrawls,
    required this.successfulCrawls,
    required this.failedCrawls,
    required this.successRate,
    required this.queueLength,
    required this.scheduledJobs,
    this.lastCrawl,
  });

  factory SchedulerStats.fromJson(Map<String, dynamic> json) {
    return SchedulerStats(
      totalCrawls: json['total_crawls'] as int,
      successfulCrawls: json['successful_crawls'] as int,
      failedCrawls: json['failed_crawls'] as int,
      successRate: (json['success_rate'] as num).toDouble(),
      queueLength: json['queue_length'] as int,
      scheduledJobs: json['scheduled_jobs'] as int,
      lastCrawl: json['last_crawl'] as String?,
    );
  }
}


class BackendException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  BackendException(this.message, {this.statusCode, this.body});

  @override
  String toString() {
    if (statusCode != null) {
      return 'BackendException: $message (status: $statusCode)';
    }
    return 'BackendException: $message';
  }
}


/// A deal from a weekly circular (Flipp API).
class CircularDeal {
  final String productName;
  final double salePrice;
  final double? regularPrice;
  final String? unit;
  final String storeChain;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool isBogo;
  final String? imageUrl;

  CircularDeal({
    required this.productName,
    required this.salePrice,
    this.regularPrice,
    this.unit,
    required this.storeChain,
    this.validFrom,
    this.validUntil,
    this.isBogo = false,
    this.imageUrl,
  });

  factory CircularDeal.fromJson(Map<String, dynamic> json) {
    return CircularDeal(
      productName: json['product_name'] as String,
      salePrice: (json['sale_price'] as num).toDouble(),
      regularPrice: json['regular_price'] != null
          ? (json['regular_price'] as num).toDouble()
          : null,
      unit: json['unit'] as String?,
      storeChain: json['store_chain'] as String,
      validFrom: json['valid_from'] != null
          ? DateTime.tryParse(json['valid_from'] as String)
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'] as String)
          : null,
      isBogo: json['is_bogo'] as bool? ?? false,
      imageUrl: json['image_url'] as String?,
    );
  }

  /// Check if the deal is still valid.
  bool get isValid {
    if (validUntil == null) return true;
    return DateTime.now().isBefore(validUntil!);
  }

  /// Check if the deal is a sale (has regular price higher than sale price).
  bool get isOnSale {
    if (regularPrice == null) return false;
    return salePrice < regularPrice!;
  }
}


class CircularSearchResponse {
  final String query;
  final List<CircularDeal> results;
  final int count;

  CircularSearchResponse({
    required this.query,
    required this.results,
    required this.count,
  });

  factory CircularSearchResponse.fromJson(Map<String, dynamic> json) {
    return CircularSearchResponse(
      query: json['query'] as String,
      results: (json['results'] as List)
          .map((r) => CircularDeal.fromJson(r as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int,
    );
  }
}

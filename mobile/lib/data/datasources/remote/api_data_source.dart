import 'package:dio/dio.dart';

import '../../../core/config/api_config.dart';
import '../../models/comparison.dart';
import '../../models/grocery_list.dart';

/// Remote data source for API calls.
class ApiDataSource {
  /// Dio HTTP client.
  final Dio _dio;

  /// Creates an API data source.
  ApiDataSource({Dio? dio}) : _dio = dio ?? _createDio();

  /// Creates a configured Dio instance.
  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.apiBaseUrl,
        connectTimeout: Duration(seconds: ApiConfig.connectionTimeout),
        receiveTimeout: Duration(seconds: ApiConfig.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  // Grocery Lists API

  /// Get all grocery lists for a user.
  Future<List<GroceryList>> getGroceryLists(String userId) async {
    try {
      final response = await _dio.get(
        ApiConfig.listsEndpoint,
        queryParameters: {'user_id': userId},
      );

      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => GroceryList.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get a specific grocery list.
  Future<GroceryList> getGroceryList(String listId) async {
    try {
      final response = await _dio.get('${ApiConfig.listsEndpoint}/$listId');
      return GroceryList.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new grocery list.
  Future<GroceryList> createGroceryList({
    required String name,
    required String userId,
    List<GroceryListItem>? items,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.listsEndpoint,
        data: {
          'name': name,
          'user_id': userId,
          'items': items?.map((item) => item.toJson()).toList() ?? [],
        },
      );
      return GroceryList.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update a grocery list.
  Future<GroceryList> updateGroceryList({
    required String listId,
    String? name,
    List<GroceryListItem>? items,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.listsEndpoint}/$listId',
        data: {
          if (name != null) 'name': name,
          if (items != null) 'items': items.map((item) => item.toJson()).toList(),
        },
      );
      return GroceryList.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a grocery list.
  Future<void> deleteGroceryList(String listId) async {
    try {
      await _dio.delete('${ApiConfig.listsEndpoint}/$listId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Comparison API

  /// Compare prices for a grocery list.
  Future<ComparisonResult> comparePrices({
    required int listId,
    required String zipCode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.compareEndpoint,
        data: {
          'list_id': listId,
          'zip_code': zipCode,
        },
      );
      return ComparisonResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors and convert to exceptions.
  Exception _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return Exception('Connection timed out. Please try again.');
      case DioExceptionType.connectionError:
        return Exception('Unable to connect to server. Please check your internet connection.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['detail'] ?? 'An error occurred';
        if (statusCode == 404) {
          return Exception('Resource not found: $message');
        } else if (statusCode == 400) {
          return Exception('Invalid request: $message');
        } else if (statusCode != null && statusCode >= 500) {
          return Exception('Server error. Please try again later.');
        }
        return Exception(message.toString());
      default:
        return Exception('An unexpected error occurred. Please try again.');
    }
  }
}

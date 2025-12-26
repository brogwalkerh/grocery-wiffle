import 'package:flutter/foundation.dart';

/// API configuration settings.
class ApiConfig {
  /// Private constructor to prevent instantiation.
  ApiConfig._();

  /// Base URL for the backend API.
  /// Uses the Android emulator loopback when needed so the mobile app can
  /// reach a backend running on the host machine.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://localhost:8000';
    }
  }

  /// API prefix for all endpoints.
  static const String apiPrefix = '/api';

  /// Full API base URL.
  static String get apiBaseUrl => '$baseUrl$apiPrefix';

  /// Connection timeout in seconds.
  static const int connectionTimeout = 30;

  /// Receive timeout in seconds.
  static const int receiveTimeout = 30;

  /// API endpoints.
  static const String listsEndpoint = '/lists';
  static const String compareEndpoint = '/compare';
  static const String productsEndpoint = '/products';
  static const String storesEndpoint = '/stores';
  static const String dealsSearchEndpoint = '/deals/search';
  static const String dealsStoreEndpoint = '/deals/store';
  static const String pricesSearchEndpoint = '/prices/search';

  /// Get the full URL for an endpoint.
  static String getEndpointUrl(String endpoint) => '$apiBaseUrl$endpoint';
}

/// API configuration settings.
class ApiConfig {
  /// Private constructor to prevent instantiation.
  ApiConfig._();

  /// Base URL for the backend API.
  /// In development, use localhost or emulator address.
  /// In production, use the actual API URL.
  static const String baseUrl = 'http://localhost:8000';

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

  /// Get the full URL for an endpoint.
  static String getEndpointUrl(String endpoint) => '$apiBaseUrl$endpoint';
}

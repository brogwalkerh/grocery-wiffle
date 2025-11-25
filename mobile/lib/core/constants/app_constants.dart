/// Application-wide constants.
class AppConstants {
  /// Private constructor to prevent instantiation.
  AppConstants._();

  /// Application name.
  static const String appName = 'GroceryCompare';

  /// Default user ID for demo purposes.
  /// In production, this would come from authentication.
  static const String defaultUserId = 'demo_user_1';

  /// Default ZIP code.
  static const String defaultZipCode = '92101';

  /// Maximum items in autocomplete suggestions.
  static const int maxAutocompleteSuggestions = 10;

  /// Debounce duration for search in milliseconds.
  static const int searchDebounceDuration = 300;

  /// Cache duration for prices in minutes.
  static const int priceCacheDuration = 60;

  /// Animation duration in milliseconds.
  static const int animationDuration = 200;

  /// Minimum quantity for an item.
  static const double minQuantity = 0.1;

  /// Maximum quantity for an item.
  static const double maxQuantity = 999;

  /// Default quantity step.
  static const double quantityStep = 1.0;
}

/// Error messages.
class ErrorMessages {
  /// Private constructor to prevent instantiation.
  ErrorMessages._();

  static const String networkError = 'Unable to connect. Please check your internet connection.';
  static const String serverError = 'Something went wrong. Please try again later.';
  static const String notFound = 'The requested item was not found.';
  static const String invalidInput = 'Please check your input and try again.';
  static const String loadingFailed = 'Failed to load data. Pull to refresh.';
}

/// Success messages.
class SuccessMessages {
  /// Private constructor to prevent instantiation.
  SuccessMessages._();

  static const String listCreated = 'List created successfully';
  static const String listUpdated = 'List updated successfully';
  static const String listDeleted = 'List deleted successfully';
  static const String itemAdded = 'Item added to list';
  static const String itemRemoved = 'Item removed from list';
}

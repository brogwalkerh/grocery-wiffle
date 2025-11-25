import 'package:intl/intl.dart';

/// Utility functions for formatting values.
class Formatters {
  /// Private constructor to prevent instantiation.
  Formatters._();

  /// Currency formatter.
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );

  /// Compact currency formatter for large values.
  static final _compactCurrencyFormat = NumberFormat.compactCurrency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );

  /// Percentage formatter.
  static final _percentFormat = NumberFormat.percentPattern('en_US');

  /// Date formatter.
  static final _dateFormat = DateFormat.yMMMd('en_US');

  /// Time formatter.
  static final _timeFormat = DateFormat.jm('en_US');

  /// Format a value as currency.
  static String formatCurrency(double value) {
    return _currencyFormat.format(value);
  }

  /// Format a value as compact currency.
  static String formatCompactCurrency(double value) {
    return _compactCurrencyFormat.format(value);
  }

  /// Format a value as percentage.
  static String formatPercent(double value) {
    return _percentFormat.format(value);
  }

  /// Format a date.
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format a time.
  static String formatTime(DateTime time) {
    return _timeFormat.format(time);
  }

  /// Format a date and time.
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${formatTime(dateTime)}';
  }

  /// Format quantity with appropriate precision.
  static String formatQuantity(double quantity) {
    if (quantity == quantity.truncateToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(1);
  }

  /// Format savings amount.
  static String formatSavings(double savings) {
    if (savings <= 0) return 'No savings';
    return 'Save ${formatCurrency(savings)}';
  }

  /// Format price difference as percentage.
  static String formatPriceDifference(double basePrice, double comparePrice) {
    if (basePrice <= 0) return '0%';
    final difference = ((comparePrice - basePrice) / basePrice) * 100;
    final sign = difference > 0 ? '+' : '';
    return '$sign${difference.toStringAsFixed(1)}%';
  }
}

/// Utility functions for validation.
class Validators {
  /// Private constructor to prevent instantiation.
  Validators._();

  /// Validate a ZIP code.
  static bool isValidZipCode(String zipCode) {
    final regex = RegExp(r'^\d{5}(-\d{4})?$');
    return regex.hasMatch(zipCode);
  }

  /// Validate that a string is not empty.
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Validate that a quantity is positive.
  static bool isValidQuantity(double quantity) {
    return quantity > 0 && quantity <= 999;
  }
}

import '../datasources/remote/api_data_source.dart';
import '../models/comparison.dart';

/// Repository for price comparison operations.
class ComparisonRepository {
  /// Remote API data source.
  final ApiDataSource _apiDataSource;

  /// Creates a comparison repository.
  ComparisonRepository({
    ApiDataSource? apiDataSource,
  }) : _apiDataSource = apiDataSource ?? ApiDataSource();

  /// Compare prices for a grocery list across stores.
  Future<ComparisonResult> comparePrices({
    required int listId,
    required String zipCode,
  }) async {
    return _apiDataSource.comparePrices(
      listId: listId,
      zipCode: zipCode,
    );
  }
}

import '../datasources/local/local_data_source.dart';
import '../datasources/remote/api_data_source.dart';
import '../models/grocery_list.dart';

/// Repository for managing grocery lists.
class GroceryListRepository {
  /// Remote API data source.
  final ApiDataSource _apiDataSource;

  /// Local storage data source.
  final LocalDataSource _localDataSource;

  /// Creates a grocery list repository.
  GroceryListRepository({
    ApiDataSource? apiDataSource,
    LocalDataSource? localDataSource,
  })  : _apiDataSource = apiDataSource ?? ApiDataSource(),
        _localDataSource = localDataSource ?? LocalDataSource();

  /// Get all grocery lists for a user.
  ///
  /// Tries to fetch from API first, falls back to local storage if offline.
  Future<List<GroceryList>> getGroceryLists(String userId) async {
    try {
      final lists = await _apiDataSource.getGroceryLists(userId);
      // Cache locally for offline access
      for (final list in lists) {
        await _localDataSource.saveGroceryList(list);
      }
      return lists;
    } catch (e) {
      // Fallback to local storage
      final localLists = await _localDataSource.getGroceryLists();
      return localLists.where((list) => list.userId == userId).toList();
    }
  }

  /// Get a specific grocery list.
  Future<GroceryList?> getGroceryList(String listId) async {
    try {
      final list = await _apiDataSource.getGroceryList(listId);
      await _localDataSource.saveGroceryList(list);
      return list;
    } catch (e) {
      return _localDataSource.getGroceryList(listId);
    }
  }

  /// Create a new grocery list.
  Future<GroceryList> createGroceryList({
    required String name,
    required String userId,
    List<GroceryListItem>? items,
  }) async {
    final list = await _apiDataSource.createGroceryList(
      name: name,
      userId: userId,
      items: items,
    );
    await _localDataSource.saveGroceryList(list);
    return list;
  }

  /// Update a grocery list.
  Future<GroceryList> updateGroceryList({
    required String listId,
    String? name,
    List<GroceryListItem>? items,
  }) async {
    final list = await _apiDataSource.updateGroceryList(
      listId: listId,
      name: name,
      items: items,
    );
    await _localDataSource.saveGroceryList(list);
    return list;
  }

  /// Delete a grocery list.
  Future<void> deleteGroceryList(String listId) async {
    await _apiDataSource.deleteGroceryList(listId);
    await _localDataSource.deleteGroceryList(listId);
  }

  /// Add an item to a grocery list.
  Future<GroceryList> addItemToList({
    required String listId,
    required GroceryListItem item,
  }) async {
    final list = await getGroceryList(listId);
    if (list == null) {
      throw Exception('List not found');
    }

    final updatedItems = [...list.items, item];
    return updateGroceryList(listId: listId, items: updatedItems);
  }

  /// Remove an item from a grocery list.
  Future<GroceryList> removeItemFromList({
    required String listId,
    required String itemId,
  }) async {
    final list = await getGroceryList(listId);
    if (list == null) {
      throw Exception('List not found');
    }

    final updatedItems = list.items.where((item) => item.id != itemId).toList();
    return updateGroceryList(listId: listId, items: updatedItems);
  }

  /// Update an item in a grocery list.
  Future<GroceryList> updateItemInList({
    required String listId,
    required GroceryListItem updatedItem,
  }) async {
    final list = await getGroceryList(listId);
    if (list == null) {
      throw Exception('List not found');
    }

    final updatedItems = list.items.map((item) {
      if (item.id == updatedItem.id) {
        return updatedItem;
      }
      return item;
    }).toList();

    return updateGroceryList(listId: listId, items: updatedItems);
  }
}

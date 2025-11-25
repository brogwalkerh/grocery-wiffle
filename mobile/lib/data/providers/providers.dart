import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/local/local_data_source.dart';
import '../datasources/remote/api_data_source.dart';
import '../models/comparison.dart';
import '../models/grocery_list.dart';
import '../repositories/comparison_repository.dart';
import '../repositories/grocery_list_repository.dart';
import '../../core/constants/app_constants.dart';

// Data Sources

/// Provider for the API data source.
final apiDataSourceProvider = Provider<ApiDataSource>((ref) {
  return ApiDataSource();
});

/// Provider for the local data source.
final localDataSourceProvider = Provider<LocalDataSource>((ref) {
  return LocalDataSource();
});

// Repositories

/// Provider for the grocery list repository.
final groceryListRepositoryProvider = Provider<GroceryListRepository>((ref) {
  return GroceryListRepository(
    apiDataSource: ref.watch(apiDataSourceProvider),
    localDataSource: ref.watch(localDataSourceProvider),
  );
});

/// Provider for the comparison repository.
final comparisonRepositoryProvider = Provider<ComparisonRepository>((ref) {
  return ComparisonRepository(
    apiDataSource: ref.watch(apiDataSourceProvider),
  );
});

// State Notifiers

/// State for grocery lists.
class GroceryListsState {
  final List<GroceryList> lists;
  final bool isLoading;
  final String? error;

  const GroceryListsState({
    this.lists = const [],
    this.isLoading = false,
    this.error,
  });

  GroceryListsState copyWith({
    List<GroceryList>? lists,
    bool? isLoading,
    String? error,
  }) {
    return GroceryListsState(
      lists: lists ?? this.lists,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing grocery lists.
class GroceryListsNotifier extends StateNotifier<GroceryListsState> {
  final GroceryListRepository _repository;
  final String _userId;

  GroceryListsNotifier(this._repository, this._userId)
      : super(const GroceryListsState());

  /// Load all grocery lists.
  Future<void> loadLists() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final lists = await _repository.getGroceryLists(_userId);
      state = state.copyWith(lists: lists, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new grocery list.
  Future<GroceryList?> createList(String name) async {
    try {
      final list = await _repository.createGroceryList(
        name: name,
        userId: _userId,
      );
      state = state.copyWith(lists: [...state.lists, list]);
      return list;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Delete a grocery list.
  Future<bool> deleteList(String listId) async {
    try {
      await _repository.deleteGroceryList(listId);
      state = state.copyWith(
        lists: state.lists.where((list) => list.id != listId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update a list in state after modification.
  void updateListInState(GroceryList updatedList) {
    state = state.copyWith(
      lists: state.lists.map((list) {
        if (list.id == updatedList.id) return updatedList;
        return list;
      }).toList(),
    );
  }
}

/// Provider for grocery lists state.
final groceryListsProvider =
    StateNotifierProvider<GroceryListsNotifier, GroceryListsState>((ref) {
  final repository = ref.watch(groceryListRepositoryProvider);
  return GroceryListsNotifier(repository, AppConstants.defaultUserId);
});

// Single Grocery List

/// State for a single grocery list.
class GroceryListState {
  final GroceryList? list;
  final bool isLoading;
  final String? error;

  const GroceryListState({
    this.list,
    this.isLoading = false,
    this.error,
  });

  GroceryListState copyWith({
    GroceryList? list,
    bool? isLoading,
    String? error,
  }) {
    return GroceryListState(
      list: list ?? this.list,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for a single grocery list.
class GroceryListNotifier extends StateNotifier<GroceryListState> {
  final GroceryListRepository _repository;
  final String _listId;

  GroceryListNotifier(this._repository, this._listId)
      : super(const GroceryListState());

  /// Load the grocery list.
  Future<void> loadList() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repository.getGroceryList(_listId);
      state = state.copyWith(list: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add an item to the list.
  Future<bool> addItem(GroceryListItem item) async {
    try {
      final updatedList = await _repository.addItemToList(
        listId: _listId,
        item: item,
      );
      state = state.copyWith(list: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Remove an item from the list.
  Future<bool> removeItem(String itemId) async {
    try {
      final updatedList = await _repository.removeItemFromList(
        listId: _listId,
        itemId: itemId,
      );
      state = state.copyWith(list: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update an item in the list.
  Future<bool> updateItem(GroceryListItem item) async {
    try {
      final updatedList = await _repository.updateItemInList(
        listId: _listId,
        updatedItem: item,
      );
      state = state.copyWith(list: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update the list name.
  Future<bool> updateName(String name) async {
    try {
      final updatedList = await _repository.updateGroceryList(
        listId: _listId,
        name: name,
      );
      state = state.copyWith(list: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// Provider family for individual grocery lists.
final groceryListProvider = StateNotifierProvider.family<GroceryListNotifier,
    GroceryListState, String>((ref, listId) {
  final repository = ref.watch(groceryListRepositoryProvider);
  return GroceryListNotifier(repository, listId);
});

// Comparison

/// State for price comparison.
class ComparisonState {
  final ComparisonResult? result;
  final bool isLoading;
  final String? error;

  const ComparisonState({
    this.result,
    this.isLoading = false,
    this.error,
  });

  ComparisonState copyWith({
    ComparisonResult? result,
    bool? isLoading,
    String? error,
  }) {
    return ComparisonState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for price comparison.
class ComparisonNotifier extends StateNotifier<ComparisonState> {
  final ComparisonRepository _repository;

  ComparisonNotifier(this._repository) : super(const ComparisonState());

  /// Compare prices for a list.
  Future<void> comparePrices({
    required int listId,
    required String zipCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.comparePrices(
        listId: listId,
        zipCode: zipCode,
      );
      state = state.copyWith(result: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear comparison results.
  void clearResults() {
    state = const ComparisonState();
  }
}

/// Provider for comparison state.
final comparisonProvider =
    StateNotifierProvider<ComparisonNotifier, ComparisonState>((ref) {
  final repository = ref.watch(comparisonRepositoryProvider);
  return ComparisonNotifier(repository);
});

// Settings

/// Provider for the current ZIP code.
final zipCodeProvider = StateProvider<String>((ref) {
  return AppConstants.defaultZipCode;
});

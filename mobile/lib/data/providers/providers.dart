import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../datasources/local/local_data_source.dart';
import '../models/comparison.dart';
import '../models/grocery_list.dart';
import '../services/grocery_search_service.dart';
import '../services/local_comparison_engine.dart';
import '../../core/config/grocery_api_config.dart';
import '../../core/constants/app_constants.dart';

// Data Sources

/// Provider for the local data source.
final localDataSourceProvider = Provider<LocalDataSource>((ref) {
  return LocalDataSource();
});

// Grocery Search Service (Live API)

/// Provider for the grocery search service.
final grocerySearchServiceProvider = Provider<GrocerySearchService>((ref) {
  final service = GrocerySearchService();
  
  // Add Kroger provider if configured
  if (GroceryApiConfig.isKrogerConfigured) {
    service.addProvider(KrogerSearchProvider(
      clientId: GroceryApiConfig.krogerClientId,
      clientSecret: GroceryApiConfig.krogerClientSecret,
    ));
  }
  
  return service;
});

/// Provider for the local comparison engine.
/// Now uses multi-store price aggregation without needing a search service.
final localComparisonEngineProvider = Provider<LocalComparisonEngine>((ref) {
  return LocalComparisonEngine();
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

/// Notifier for managing grocery lists (local-only).
class GroceryListsNotifier extends StateNotifier<GroceryListsState> {
  final LocalDataSource _localDataSource;
  final String _userId;
  final _uuid = const Uuid();

  GroceryListsNotifier(this._localDataSource, this._userId)
      : super(const GroceryListsState());

  /// Load all grocery lists from local storage.
  Future<void> loadLists() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final lists = await _localDataSource.getGroceryLists();
      // Filter by user ID if needed
      final userLists = lists.where((l) => l.userId == _userId).toList();
      state = state.copyWith(lists: userLists, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new grocery list locally.
  Future<GroceryList?> createList(String name) async {
    try {
      final now = DateTime.now();
      final list = GroceryList(
        id: _uuid.v4(),
        name: name,
        userId: _userId,
        items: const [],
        createdAt: now,
        updatedAt: now,
      );
      await _localDataSource.saveGroceryList(list);
      state = state.copyWith(lists: [...state.lists, list]);
      return list;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Delete a grocery list locally.
  Future<bool> deleteList(String listId) async {
    try {
      await _localDataSource.deleteGroceryList(listId);
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
  final localDataSource = ref.watch(localDataSourceProvider);
  return GroceryListsNotifier(localDataSource, AppConstants.defaultUserId);
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

/// Notifier for a single grocery list (local-only).
class GroceryListNotifier extends StateNotifier<GroceryListState> {
  final LocalDataSource _localDataSource;
  final String _listId;
  final _uuid = const Uuid();

  GroceryListNotifier(this._localDataSource, this._listId)
      : super(const GroceryListState());

  /// Load the grocery list from local storage.
  Future<void> loadList() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _localDataSource.getGroceryList(_listId);
      state = state.copyWith(list: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add an item to the list.
  Future<bool> addItem(GroceryListItem item) async {
    try {
      final currentList = state.list;
      if (currentList == null) return false;

      final newItem = item.copyWith(
        id: item.id.isEmpty ? _uuid.v4() : item.id,
        position: currentList.items.length,
      );

      final updatedList = currentList.copyWith(
        items: [...currentList.items, newItem],
        updatedAt: DateTime.now(),
      );

      await _localDataSource.saveGroceryList(updatedList);
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
      final currentList = state.list;
      if (currentList == null) return false;

      final updatedList = currentList.copyWith(
        items: currentList.items.where((i) => i.id != itemId).toList(),
        updatedAt: DateTime.now(),
      );

      await _localDataSource.saveGroceryList(updatedList);
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
      final currentList = state.list;
      if (currentList == null) return false;

      final updatedList = currentList.copyWith(
        items: currentList.items.map((i) {
          if (i.id == item.id) return item;
          return i;
        }).toList(),
        updatedAt: DateTime.now(),
      );

      await _localDataSource.saveGroceryList(updatedList);
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
      final currentList = state.list;
      if (currentList == null) return false;

      final updatedList = currentList.copyWith(
        name: name,
        updatedAt: DateTime.now(),
      );

      await _localDataSource.saveGroceryList(updatedList);
      state = state.copyWith(list: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Toggle the checked state of an item.
  Future<bool> toggleItem(String itemId) async {
    try {
      final currentList = state.list;
      if (currentList == null) return false;

      final updatedList = currentList.copyWith(
        items: currentList.items.map((i) {
          if (i.id == itemId) {
            return i.copyWith(isChecked: !i.isChecked);
          }
          return i;
        }).toList(),
        updatedAt: DateTime.now(),
      );

      await _localDataSource.saveGroceryList(updatedList);
      state = state.copyWith(list: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Reorder items in the list.
  Future<bool> reorderItems(int oldIndex, int newIndex) async {
    try {
      final currentList = state.list;
      if (currentList == null) return false;

      final items = List<GroceryListItem>.from(currentList.items);
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);

      // Update positions
      final updatedItems = items.asMap().entries.map((entry) {
        return entry.value.copyWith(position: entry.key);
      }).toList();

      final updatedList = currentList.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      await _localDataSource.saveGroceryList(updatedList);
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
  final localDataSource = ref.watch(localDataSourceProvider);
  return GroceryListNotifier(localDataSource, listId);
});

// Comparison

/// State for price comparison.
class ComparisonState {
  final ComparisonResult? result;
  final bool isLoading;
  final String? error;
  final String? progressMessage;

  const ComparisonState({
    this.result,
    this.isLoading = false,
    this.error,
    this.progressMessage,
  });

  ComparisonState copyWith({
    ComparisonResult? result,
    bool? isLoading,
    String? error,
    String? progressMessage,
  }) {
    return ComparisonState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      progressMessage: progressMessage,
    );
  }
}

/// Notifier for price comparison (uses live search).
class ComparisonNotifier extends StateNotifier<ComparisonState> {
  final LocalComparisonEngine _engine;
  final LocalDataSource _localDataSource;

  ComparisonNotifier(this._engine, this._localDataSource) 
      : super(const ComparisonState());

  /// Compare prices for a list using live search.
  Future<void> comparePrices({
    required String listId,
    required String zipCode,
    int radiusMiles = 10,
  }) async {
    state = state.copyWith(isLoading: true, error: null, progressMessage: 'Loading list...');
    
    try {
      // Get the grocery list
      final groceryList = await _localDataSource.getGroceryList(listId);
      if (groceryList == null) {
        state = state.copyWith(
          isLoading: false, 
          error: 'Grocery list not found',
        );
        return;
      }

      if (groceryList.items.isEmpty) {
        state = state.copyWith(
          isLoading: false, 
          error: 'Add items to your list before comparing prices',
        );
        return;
      }

      // Run comparison with progress updates
      final result = await _engine.comparePrices(
        groceryList: groceryList,
        zipCode: zipCode,
        radiusMiles: radiusMiles,
        onProgress: (itemName, current, total) {
          state = state.copyWith(
            progressMessage: 'Searching stores for "$itemName" ($current/$total)...\n'
                '(Walmart, Target, Kroger, Costco, Aldi)',
          );
        },
      );

      state = state.copyWith(
        result: result, 
        isLoading: false,
        progressMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false, 
        error: e.toString(),
        progressMessage: null,
      );
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
  final engine = ref.watch(localComparisonEngineProvider);
  final localDataSource = ref.watch(localDataSourceProvider);
  return ComparisonNotifier(engine, localDataSource);
});

// Settings

/// Provider for the current ZIP code.
final zipCodeProvider = StateProvider<String>((ref) {
  return AppConstants.defaultZipCode;
});

/// Provider to check if API is configured.
/// Since the price aggregator now uses web scraping from multiple stores
/// (Walmart, Target, Kroger, Costco, Aldi), it works without API keys.
/// Kroger API is optional for enhanced results.
final isApiConfiguredProvider = Provider<bool>((ref) {
  // Always true now since we use web scraping
  // Kroger API is just an optional enhancement
  return true;
});

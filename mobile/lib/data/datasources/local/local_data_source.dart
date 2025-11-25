import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/grocery_list.dart';

/// Local data source using Hive for offline storage.
class LocalDataSource {
  /// Box name for grocery lists.
  static const String _groceryListsBoxName = 'grocery_lists';

  /// Box name for settings.
  static const String _settingsBoxName = 'settings';

  /// Grocery lists box.
  Box<String>? _groceryListsBox;

  /// Settings box.
  Box<String>? _settingsBox;

  /// Initialize the local data source.
  Future<void> init() async {
    _groceryListsBox = await Hive.openBox<String>(_groceryListsBoxName);
    _settingsBox = await Hive.openBox<String>(_settingsBoxName);
  }

  /// Ensure boxes are initialized.
  Future<void> _ensureInitialized() async {
    if (_groceryListsBox == null || _settingsBox == null) {
      await init();
    }
  }

  // Grocery Lists

  /// Save a grocery list locally.
  Future<void> saveGroceryList(GroceryList list) async {
    await _ensureInitialized();
    await _groceryListsBox!.put(list.id, jsonEncode(list.toJson()));
  }

  /// Get all locally stored grocery lists.
  Future<List<GroceryList>> getGroceryLists() async {
    await _ensureInitialized();
    final lists = <GroceryList>[];

    for (final key in _groceryListsBox!.keys) {
      final jsonString = _groceryListsBox!.get(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          lists.add(GroceryList.fromJson(json));
        } catch (e) {
          // Skip malformed entries
        }
      }
    }

    return lists;
  }

  /// Get a specific grocery list.
  Future<GroceryList?> getGroceryList(String listId) async {
    await _ensureInitialized();
    final jsonString = _groceryListsBox!.get(listId);
    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return GroceryList.fromJson(json);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Delete a grocery list.
  Future<void> deleteGroceryList(String listId) async {
    await _ensureInitialized();
    await _groceryListsBox!.delete(listId);
  }

  /// Clear all grocery lists.
  Future<void> clearGroceryLists() async {
    await _ensureInitialized();
    await _groceryListsBox!.clear();
  }

  // Settings

  /// Save a setting.
  Future<void> saveSetting(String key, String value) async {
    await _ensureInitialized();
    await _settingsBox!.put(key, value);
  }

  /// Get a setting.
  Future<String?> getSetting(String key) async {
    await _ensureInitialized();
    return _settingsBox!.get(key);
  }

  /// Delete a setting.
  Future<void> deleteSetting(String key) async {
    await _ensureInitialized();
    await _settingsBox!.delete(key);
  }

  /// Get the saved ZIP code.
  Future<String?> getSavedZipCode() async {
    return getSetting('zip_code');
  }

  /// Save the ZIP code.
  Future<void> saveZipCode(String zipCode) async {
    await saveSetting('zip_code', zipCode);
  }

  /// Get the saved user ID.
  Future<String?> getSavedUserId() async {
    return getSetting('user_id');
  }

  /// Save the user ID.
  Future<void> saveUserId(String userId) async {
    await saveSetting('user_id', userId);
  }
}

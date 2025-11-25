import 'package:flutter_test/flutter_test.dart';

import 'package:grocery_compare/data/models/grocery_list.dart';
import 'package:grocery_compare/data/models/product.dart';
import 'package:grocery_compare/data/models/comparison.dart';
import 'package:grocery_compare/data/models/store.dart';

void main() {
  group('GroceryListItem', () {
    test('creates from JSON correctly', () {
      final json = {
        'id': '1',
        'name': 'Milk',
        'quantity': 2.0,
        'unit': 'gallon',
        'notes': 'Get organic',
        'product_id': 123,
        'position': 0,
        'is_checked': false,
      };

      final item = GroceryListItem.fromJson(json);

      expect(item.id, '1');
      expect(item.name, 'Milk');
      expect(item.quantity, 2.0);
      expect(item.unit, 'gallon');
      expect(item.notes, 'Get organic');
      expect(item.productId, 123);
      expect(item.position, 0);
      expect(item.isChecked, false);
    });

    test('converts to JSON correctly', () {
      const item = GroceryListItem(
        id: '1',
        name: 'Milk',
        quantity: 2.0,
        unit: 'gallon',
      );

      final json = item.toJson();

      expect(json['id'], '1');
      expect(json['name'], 'Milk');
      expect(json['quantity'], 2.0);
      expect(json['unit'], 'gallon');
    });

    test('copyWith creates a new instance with updated values', () {
      const item = GroceryListItem(
        id: '1',
        name: 'Milk',
        quantity: 1.0,
      );

      final updated = item.copyWith(quantity: 2.0, isChecked: true);

      expect(updated.id, '1');
      expect(updated.name, 'Milk');
      expect(updated.quantity, 2.0);
      expect(updated.isChecked, true);
    });
  });

  group('GroceryList', () {
    test('creates from JSON correctly', () {
      final json = {
        'id': '1',
        'name': 'Weekly Groceries',
        'user_id': 'user123',
        'items': [
          {
            'id': '1',
            'name': 'Milk',
            'quantity': 1.0,
            'position': 0,
          },
        ],
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final list = GroceryList.fromJson(json);

      expect(list.id, '1');
      expect(list.name, 'Weekly Groceries');
      expect(list.userId, 'user123');
      expect(list.items.length, 1);
      expect(list.itemCount, 1);
    });

    test('itemCount returns correct value', () {
      final list = GroceryList(
        id: '1',
        name: 'Test',
        userId: 'user123',
        items: const [
          GroceryListItem(id: '1', name: 'Item 1'),
          GroceryListItem(id: '2', name: 'Item 2'),
          GroceryListItem(id: '3', name: 'Item 3'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(list.itemCount, 3);
    });
  });

  group('Product', () {
    test('displayName includes brand when present', () {
      const product = Product(
        id: 1,
        name: 'Whole Milk',
        brand: 'Organic Valley',
      );

      expect(product.displayName, 'Organic Valley Whole Milk');
    });

    test('displayName returns name only when brand is null', () {
      const product = Product(
        id: 1,
        name: 'Bananas',
      );

      expect(product.displayName, 'Bananas');
    });

    test('sizeDescription formats correctly', () {
      const product = Product(
        id: 1,
        name: 'Milk',
        unitSize: 1.0,
        unitType: 'gallon',
      );

      expect(product.sizeDescription, '1 gallon');
    });
  });

  group('StorePrice', () {
    test('savings calculates correctly when on sale', () {
      const price = StorePrice(
        storeId: 1,
        storeName: 'Test Store',
        storeChain: 'Test Chain',
        regularPrice: 5.99,
        currentPrice: 4.99,
        isOnSale: true,
      );

      expect(price.savings, 1.0);
    });

    test('savings returns 0 when not on sale', () {
      const price = StorePrice(
        storeId: 1,
        storeName: 'Test Store',
        storeChain: 'Test Chain',
        regularPrice: 5.99,
        currentPrice: 5.99,
        isOnSale: false,
      );

      expect(price.savings, 0);
    });
  });

  group('StoreTotalComparison', () {
    test('creates from JSON correctly', () {
      final json = {
        'store_id': 1,
        'store_name': 'Kroger',
        'store_chain': 'Kroger',
        'store_address': '123 Main St',
        'total_price': 45.99,
        'items_found': 10,
        'items_on_sale': 3,
        'is_cheapest': true,
      };

      final storeTotal = StoreTotalComparison.fromJson(json);

      expect(storeTotal.storeId, 1);
      expect(storeTotal.storeName, 'Kroger');
      expect(storeTotal.totalPrice, 45.99);
      expect(storeTotal.itemsFound, 10);
      expect(storeTotal.itemsOnSale, 3);
      expect(storeTotal.isCheapest, true);
    });
  });
}

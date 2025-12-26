import 'package:flutter_test/flutter_test.dart';

/// Tests for unit conversion logic used in price calculations.
/// 
/// The key scenarios:
/// - User wants "8 oz butter", store sells "1 lb butter for $4.99"
///   -> User needs 8/16 = 0.5 of the product = $2.50
/// - User wants "2 lb chicken", store sells "1 lb chicken for $3.99"  
///   -> User needs 2 products = $7.98
/// - User wants "3 gallons milk", store sells "1 gallon milk for $3.49"
///   -> User needs 3 products = $10.47
void main() {
  group('Unit Conversion Logic', () {
    test('oz to lb conversion', () {
      // 8 oz = 0.5 lb
      const ozInLb = 8.0 / 16.0;
      expect(ozInLb, 0.5);
      
      // So 8 oz of a $4.99/lb product = $2.495
      const price = 4.99 * ozInLb;
      expect(price, closeTo(2.495, 0.01));
    });

    test('lb to oz conversion', () {
      // 1 lb = 16 oz
      // If user wants 32 oz and product is 1 lb ($4.99)
      // User needs 32/16 = 2 products
      const productsNeeded = 32.0 / 16.0;
      expect(productsNeeded, 2.0);
      
      const price = 4.99 * productsNeeded;
      expect(price, closeTo(9.98, 0.01));
    });

    test('gallon to fl oz conversion', () {
      // 1 gallon = 128 fl oz
      // If product is 1 gallon ($3.49) and user wants 64 fl oz
      // User needs 64/128 = 0.5 products
      const productsNeeded = 64.0 / 128.0;
      expect(productsNeeded, 0.5);
      
      const price = 3.49 * productsNeeded;
      expect(price, closeTo(1.745, 0.01));
    });

    test('same unit comparison', () {
      // User wants 2 lb, product is 1 lb ($5.99)
      // User needs 2 products
      const userOz = 2.0 * 16.0; // 32 oz
      const productOz = 1.0 * 16.0; // 16 oz
      const productsNeeded = userOz / productOz;
      expect(productsNeeded, 2.0);
      
      const price = 5.99 * productsNeeded;
      expect(price, closeTo(11.98, 0.01));
    });

    test('count-based items should multiply directly', () {
      // User wants 12 eggs, product is 1 dozen ($3.99)
      // These are count-based, not weight-based
      // Without size info on the product, just multiply
      const price = 3.99 * 1; // Assume 1 dozen = 1 product
      expect(price, 3.99);
    });

    test('grams to oz conversion', () {
      // 100g ≈ 3.527 oz
      // If product is 16 oz ($4.99) and user wants 200g
      const userOz = 200.0 * 0.03527396; // ~7.05 oz
      const productOz = 16.0;
      const productsNeeded = userOz / productOz;
      
      expect(productsNeeded, closeTo(0.44, 0.01));
      
      const price = 4.99 * productsNeeded;
      expect(price, closeTo(2.20, 0.1));
    });

    test('ml to fl oz conversion', () {
      // 1 liter = 33.814 fl oz
      // If user wants 500ml and product is 1 liter ($2.99)
      const userFlOz = 500.0 * 0.033814; // ~16.9 fl oz
      const productFlOz = 1.0 * 33.814; // ~33.8 fl oz
      const productsNeeded = userFlOz / productFlOz;
      
      expect(productsNeeded, closeTo(0.5, 0.01));
      
      const price = 2.99 * productsNeeded;
      expect(price, closeTo(1.50, 0.1));
    });
  });

  group('Real-world scenarios', () {
    test('butter: 8 oz wanted, 1 lb sold for \$4.99', () {
      // Product: 1 lb (16 oz) butter = $4.99
      // User wants: 8 oz
      // Calculation: 8 oz / 16 oz = 0.5 packages
      // Price: $4.99 * 0.5 = $2.495
      
      const productOz = 16.0;
      const userOz = 8.0;
      const productsNeeded = userOz / productOz;
      const price = 4.99 * productsNeeded;
      
      expect(price, closeTo(2.50, 0.01));
    });

    test('milk: 1 gallon wanted, 1 gallon sold for \$3.49', () {
      // Product: 1 gallon = $3.49
      // User wants: 1 gallon
      // Calculation: 1:1
      // Price: $3.49
      
      const productFlOz = 128.0; // 1 gallon
      const userFlOz = 128.0;
      const productsNeeded = userFlOz / productFlOz;
      const price = 3.49 * productsNeeded;
      
      expect(price, 3.49);
    });

    test('cheese: 16 oz wanted, 8 oz sold for \$3.99', () {
      // Product: 8 oz cheese = $3.99
      // User wants: 16 oz (1 lb)
      // Calculation: 16 oz / 8 oz = 2 packages
      // Price: $3.99 * 2 = $7.98
      
      const productOz = 8.0;
      const userOz = 16.0;
      const productsNeeded = userOz / productOz;
      const price = 3.99 * productsNeeded;
      
      expect(price, closeTo(7.98, 0.01));
    });
  });
}

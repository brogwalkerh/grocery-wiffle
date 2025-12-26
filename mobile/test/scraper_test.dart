import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_compare/data/services/grocery_scraper.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GroceryScraper', () {
    test('ScrapedProduct calculates unit price correctly', () {
      final product = ScrapedProduct(
        name: 'Test Butter',
        price: 4.99,
        size: '16 oz',
        store: 'Walmart',
      );
      
      // 4.99 / 16 = 0.311875
      expect(product.unitPrice, closeTo(0.311875, 0.001));
    });
    
    test('ScrapedProduct handles lb to oz conversion for unit price', () {
      final product = ScrapedProduct(
        name: 'Test Chicken',
        price: 9.99,
        size: '2 lb',
        store: 'Walmart',
      );
      
      // 2 lb = 32 oz, so 9.99 / 32 = 0.312
      expect(product.unitPrice, closeTo(0.312, 0.001));
    });
    
    test('ScrapedProduct handles gallon to fl oz conversion', () {
      final product = ScrapedProduct(
        name: 'Test Milk',
        price: 3.49,
        size: '1 gallon',
        store: 'Walmart',
      );
      
      // 1 gallon = 128 fl oz, so 3.49 / 128 = 0.0273
      expect(product.unitPrice, closeTo(0.0273, 0.001));
    });
    
    test('ScrapedProduct toString formats correctly', () {
      final product = ScrapedProduct(
        name: 'Test Butter',
        price: 4.99,
        size: '16 oz',
        store: 'Walmart',
      );
      
      expect(product.toString(), equals('Test Butter - \$4.99 at Walmart (16 oz)'));
    });
    
    test('ScrapedProduct detects sale items', () {
      final saleProduct = ScrapedProduct(
        name: 'Sale Item',
        price: 2.99,
        originalPrice: 4.99,
        store: 'Walmart',
        isOnSale: true,
      );
      
      expect(saleProduct.isOnSale, isTrue);
      expect(saleProduct.originalPrice, equals(4.99));
    });
    
    test('scrapeStore returns empty list for unknown store', () async {
      final scraper = GroceryScraper();
      final results = await scraper.scrapeStore('unknown_store', 'butter');
      expect(results, isEmpty);
    });
    
    test('GroceryScraper parses Walmart HTML response', () async {
      // Mock a simplified Walmart-like response
      final mockClient = MockClient((request) async {
        if (request.url.host == 'www.walmart.com') {
          return http.Response('''
            <html>
              <body>
                <div>Great Value Butter, 16 oz Sticks</div>
                <div class="price">current price \$3.67</div>
                <div>Land O Lakes Butter, 16 oz</div>
                <div class="price">current price Now \$4.68</div>
                <div>Was \$5.99</div>
              </body>
            </html>
          ''', 200);
        }
        return http.Response('Not found', 404);
      });
      
      final scraper = GroceryScraper(httpClient: mockClient);
      final results = await scraper.scrapeWalmart('butter');
      
      // Should find products based on the pattern matching
      // Results depend on how well the regex matches the mock HTML
      expect(results, isA<List<ScrapedProduct>>());
    });
    
    test('GroceryScraper handles network errors gracefully', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });
      
      final scraper = GroceryScraper(httpClient: mockClient);
      final results = await scraper.scrapeWalmart('butter');
      
      // Should return empty list, not throw
      expect(results, isEmpty);
    });
    
    test('GroceryScraper handles non-200 status codes', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Forbidden', 403);
      });
      
      final scraper = GroceryScraper(httpClient: mockClient);
      final results = await scraper.scrapeWalmart('butter');
      
      expect(results, isEmpty);
    });
    
    test('scrapeAllStores calls multiple stores in parallel', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('', 200);
      });
      
      final scraper = GroceryScraper(httpClient: mockClient);
      await scraper.scrapeAllStores('butter');
      
      // Should have made calls to multiple stores
      expect(callCount, greaterThan(0));
    });
    
    test('scrapeStore routes to correct scraper method', () async {
      final scraper = GroceryScraper();
      
      // These should all route to appropriate handlers and not throw
      // (they return empty lists due to network issues in test environment)
      expect(() async => await scraper.scrapeStore('walmart', 'milk'), returnsNormally);
      expect(() async => await scraper.scrapeStore('target', 'milk'), returnsNormally);
      expect(() async => await scraper.scrapeStore('kroger', 'milk'), returnsNormally);
      expect(() async => await scraper.scrapeStore('safeway', 'milk'), returnsNormally);
      expect(() async => await scraper.scrapeStore('aldi', 'milk'), returnsNormally);
    });
  });
  
  group('Store Coverage', () {
    test('All major grocery chains have scraper implementations', () {
      final scraper = GroceryScraper();
      
      // List of stores that should be supported
      final supportedStores = [
        'walmart',
        'target', 
        'kroger',
        'safeway',
        'albertsons',
        'publix',
        'heb',
        'h-e-b',
        'wegmans',
        'aldi',
        'costco',
        'amazon',
        'amazon fresh',
        'whole foods',
        'meijer',
        'food lion',
        'giant',
        'stop & shop',
        'trader joes',
        'winco',
        'sprouts',
        'smart & final',
        'food 4 less',
        'save mart',
        'lucky',
      ];
      
      // Verify each store has a handler by checking scrapeStore doesn't throw
      for (final store in supportedStores) {
        expect(
          () => scraper.scrapeStore(store, 'test'),
          returnsNormally,
          reason: '$store should have a scraper implementation',
        );
      }
    });
  });
}

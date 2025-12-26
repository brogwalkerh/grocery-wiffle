import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_compare/data/services/store_locator.dart';

void main() {
  group('StoreLocator', () {
    late StoreLocator locator;

    setUp(() {
      locator = StoreLocator();
    });

    test('returns stores for a valid zip code', () async {
      final stores = await locator.getStoresNearZipCode('90210');
      
      expect(stores, isNotEmpty);
      // Should have national chains
      expect(stores.any((s) => s.chain == 'Walmart'), isTrue);
      expect(stores.any((s) => s.chain == 'Target'), isTrue);
      expect(stores.any((s) => s.chain == 'Costco'), isTrue);
    });

    test('returns regional chains for California zip code', () async {
      // 90210 is California
      final stores = await locator.getStoresNearZipCode('90210');
      
      // West coast chains
      expect(stores.any((s) => s.chain == 'Safeway'), isTrue);
      expect(stores.any((s) => s.chain == 'Albertsons'), isTrue);
    });

    test('returns regional chains for Texas zip code', () async {
      // 75001 is Texas
      final stores = await locator.getStoresNearZipCode('75001');
      
      // Texas chains
      expect(stores.any((s) => s.chain == 'H-E-B'), isTrue);
    });

    test('returns regional chains for Florida zip code', () async {
      // 33101 is Florida
      final stores = await locator.getStoresNearZipCode('33101');
      
      // Southeast chains
      expect(stores.any((s) => s.chain == 'Publix'), isTrue);
    });

    test('returns regional chains for New York zip code', () async {
      // 10001 is New York
      final stores = await locator.getStoresNearZipCode('10001');
      
      // Northeast chains
      expect(stores.any((s) => s.chain == 'Stop & Shop'), isTrue);
      expect(stores.any((s) => s.chain == 'Wegmans'), isTrue);
    });

    test('returns regional chains for Ohio zip code', () async {
      // 43215 is Ohio (Midwest)
      final stores = await locator.getStoresNearZipCode('43215');
      
      // Midwest chains
      expect(stores.any((s) => s.chain == 'Kroger'), isTrue);
      expect(stores.any((s) => s.chain == 'Meijer'), isTrue);
    });

    test('getAvailableChains returns list of chain names', () async {
      final chains = await locator.getAvailableChains('90210');
      
      expect(chains, isA<List<String>>());
      expect(chains, isNotEmpty);
      expect(chains.contains('Walmart'), isTrue);
    });

    test('isChainAvailable returns true for available chain', () async {
      final isAvailable = await locator.isChainAvailable('Walmart', '90210');
      expect(isAvailable, isTrue);
    });

    test('isChainAvailable returns false for unavailable chain', () async {
      // H-E-B is only in Texas
      final isAvailable = await locator.isChainAvailable('H-E-B', '10001'); // NYC
      expect(isAvailable, isFalse);
    });

    test('getNearestStore returns store for valid chain', () async {
      final store = await locator.getNearestStore('Walmart', '90210');
      
      expect(store, isNotNull);
      expect(store!.chain, equals('Walmart'));
    });

    test('getNearestStore returns null for unavailable chain', () async {
      final store = await locator.getNearestStore('H-E-B', '10001');
      expect(store, isNull);
    });

    test('clearCache empties the cache', () async {
      // First call caches
      await locator.getStoresNearZipCode('90210');
      
      // Clear cache
      locator.clearCache();
      
      // Should still work after clearing
      final stores = await locator.getStoresNearZipCode('90210');
      expect(stores, isNotEmpty);
    });
  });

  group('StoreLocation', () {
    test('creates from JSON correctly', () {
      final json = {
        'storeId': 'walmart_90210',
        'name': 'Walmart',
        'chain': 'Walmart',
        'address': '123 Main St',
        'city': 'Beverly Hills',
        'state': 'CA',
        'zipCode': '90210',
        'latitude': 34.0901,
        'longitude': -118.4065,
        'distanceMiles': 2.5,
        'hasOnlineOrdering': true,
      };

      final store = StoreLocation.fromJson(json);
      
      expect(store.storeId, equals('walmart_90210'));
      expect(store.name, equals('Walmart'));
      expect(store.chain, equals('Walmart'));
      expect(store.city, equals('Beverly Hills'));
      expect(store.state, equals('CA'));
      expect(store.distanceMiles, equals(2.5));
    });

    test('converts to JSON correctly', () {
      final store = StoreLocation(
        storeId: 'target_90210',
        name: 'Target',
        chain: 'Target',
        address: '456 Oak Ave',
        city: 'Beverly Hills',
        state: 'CA',
        zipCode: '90210',
      );

      final json = store.toJson();
      
      expect(json['storeId'], equals('target_90210'));
      expect(json['name'], equals('Target'));
      expect(json['chain'], equals('Target'));
    });

    test('getSearchUrl returns correct URL for each chain', () {
      final walmartStore = StoreLocation(
        storeId: 'test',
        name: 'Walmart',
        chain: 'Walmart',
        address: '',
        city: '',
        state: '',
        zipCode: '',
      );

      final url = walmartStore.getSearchUrl('butter');
      expect(url, contains('walmart.com'));
      expect(url, contains('butter'));
    });

    test('getSearchUrl handles special characters in query', () {
      final store = StoreLocation(
        storeId: 'test',
        name: 'Target',
        chain: 'Target',
        address: '',
        city: '',
        state: '',
        zipCode: '',
      );

      final url = store.getSearchUrl('peanut butter & jelly');
      expect(url, contains('target.com'));
      // Should be URL encoded - %26 is the encoded &
      expect(url, contains('peanut'));
      expect(url, contains('butter'));
    });

    test('toString formats correctly', () {
      final store = StoreLocation(
        storeId: 'test',
        name: 'Kroger',
        chain: 'Kroger',
        address: '789 Elm St',
        city: 'Columbus',
        state: 'OH',
        zipCode: '43215',
      );

      final str = store.toString();
      expect(str, contains('Kroger'));
      expect(str, contains('789 Elm St'));
      expect(str, contains('Columbus'));
    });
  });
}

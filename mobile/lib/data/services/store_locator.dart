import 'package:http/http.dart' as http;

/// Represents a grocery store location
class StoreLocation {
  final String storeId;
  final String name;
  final String chain;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;
  final double? distanceMiles;
  final String? phone;
  final Map<String, String>? hours;
  final bool hasOnlineOrdering;
  final String? websiteUrl;

  StoreLocation({
    required this.storeId,
    required this.name,
    required this.chain,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    this.latitude,
    this.longitude,
    this.distanceMiles,
    this.phone,
    this.hours,
    this.hasOnlineOrdering = true,
    this.websiteUrl,
  });

  /// Get the search URL for this store
  String getSearchUrl(String query) {
    final encodedQuery = Uri.encodeComponent(query);
    switch (chain.toLowerCase()) {
      case 'walmart':
        return 'https://www.walmart.com/search?q=$encodedQuery';
      case 'target':
        return 'https://www.target.com/s?searchTerm=$encodedQuery';
      case 'kroger':
        return 'https://www.kroger.com/search?query=$encodedQuery';
      case 'safeway':
      case 'albertsons':
        return 'https://www.safeway.com/shop/search-results.html?q=$encodedQuery';
      case 'publix':
        return 'https://www.publix.com/search?q=$encodedQuery';
      case 'h-e-b':
      case 'heb':
        return 'https://www.heb.com/search?q=$encodedQuery';
      case 'wegmans':
        return 'https://www.wegmans.com/search?q=$encodedQuery';
      case 'aldi':
        return 'https://www.aldi.us/products/search/?q=$encodedQuery';
      case 'costco':
        return 'https://www.costco.com/CatalogSearch?dept=All&keyword=$encodedQuery';
      case 'amazon fresh':
      case 'whole foods':
        return 'https://www.amazon.com/s?k=$encodedQuery&i=amazonfresh';
      case 'meijer':
        return 'https://www.meijer.com/search.html?text=$encodedQuery';
      case 'food lion':
        return 'https://www.foodlion.com/search?q=$encodedQuery';
      case 'giant':
        return 'https://giantfood.com/shop/search-results.html?q=$encodedQuery';
      case 'stop & shop':
        return 'https://stopandshop.com/shop/search-results.html?q=$encodedQuery';
      case 'trader joe\'s':
      case 'trader joes':
        return 'https://www.traderjoes.com/home/search?q=$encodedQuery&section=products';
      case 'winco':
        return 'https://www.wincofoods.com/search?query=$encodedQuery';
      case 'sprouts':
        return 'https://shop.sprouts.com/search?search_term=$encodedQuery';
      case 'smart & final':
        return 'https://www.smartandfinal.com/search?q=$encodedQuery';
      case 'food 4 less':
        return 'https://www.food4less.com/search?query=$encodedQuery';
      case 'save mart':
      case 'lucky':
        return 'https://www.savemart.com/shop/search-results.html?q=$encodedQuery';
      case "sam's club":
      case 'sams club':
        return 'https://www.samsclub.com/s/$encodedQuery';
      case 'bj\'s':
      case 'bjs':
        return 'https://www.bjs.com/search/$encodedQuery';
      case 'shoprite':
        return 'https://www.shoprite.com/shop/search-results.html?q=$encodedQuery';
      case 'harris teeter':
        return 'https://www.harristeeter.com/search?query=$encodedQuery';
      case 'fred meyer':
        return 'https://www.fredmeyer.com/search?query=$encodedQuery';
      case 'ralphs':
        return 'https://www.ralphs.com/search?query=$encodedQuery';
      case 'vons':
        return 'https://www.vons.com/shop/search-results.html?q=$encodedQuery';
      case 'acme':
        return 'https://www.acmemarkets.com/shop/search-results.html?q=$encodedQuery';
      case 'jewel-osco':
        return 'https://www.jewelosco.com/shop/search-results.html?q=$encodedQuery';
      case 'hy-vee':
        return 'https://www.hy-vee.com/aisles-online/search?search=$encodedQuery';
      case 'piggly wiggly':
        return 'https://www.pigglywiggly.com/search?q=$encodedQuery';
      case 'winn-dixie':
        return 'https://www.winndixie.com/search?q=$encodedQuery';
      case 'ingles':
        return 'https://www.ingles-markets.com/search?q=$encodedQuery';
      case 'price chopper':
        return 'https://www.pricechopper.com/search?q=$encodedQuery';
      case 'market basket':
        return 'https://www.shopmarketbasket.com/search?q=$encodedQuery';
      default:
        return 'https://www.google.com/search?q=$encodedQuery+$chain+grocery';
    }
  }

  @override
  String toString() => '$name ($chain) - $address, $city, $state $zipCode';
  
  Map<String, dynamic> toJson() => {
    'storeId': storeId,
    'name': name,
    'chain': chain,
    'address': address,
    'city': city,
    'state': state,
    'zipCode': zipCode,
    'latitude': latitude,
    'longitude': longitude,
    'distanceMiles': distanceMiles,
    'phone': phone,
    'hours': hours,
    'hasOnlineOrdering': hasOnlineOrdering,
    'websiteUrl': websiteUrl,
  };

  factory StoreLocation.fromJson(Map<String, dynamic> json) => StoreLocation(
    storeId: json['storeId'] ?? '',
    name: json['name'] ?? '',
    chain: json['chain'] ?? '',
    address: json['address'] ?? '',
    city: json['city'] ?? '',
    state: json['state'] ?? '',
    zipCode: json['zipCode'] ?? '',
    latitude: json['latitude']?.toDouble(),
    longitude: json['longitude']?.toDouble(),
    distanceMiles: json['distanceMiles']?.toDouble(),
    phone: json['phone'],
    hours: json['hours'] != null ? Map<String, String>.from(json['hours']) : null,
    hasOnlineOrdering: json['hasOnlineOrdering'] ?? true,
    websiteUrl: json['websiteUrl'],
  );
}

/// Service to discover grocery stores near a location
class StoreLocator {
  // ignore: unused_field
  final http.Client _httpClient;
  
  // Cache of stores by zip code
  final Map<String, List<StoreLocation>> _storeCache = {};
  
  // Known store chains and their typical regional coverage
  static const Map<String, List<String>> _regionalChains = {
    // National chains (available almost everywhere)
    'national': [
      'Walmart',
      'Target',
      'Costco',
      'Aldi',
      "Sam's Club",
      'Amazon Fresh',
    ],
    // Southeast
    'southeast': [
      'Publix',
      'Food Lion',
      'Winn-Dixie',
      'Piggly Wiggly',
      'Ingles',
      'Harris Teeter',
    ],
    // Northeast
    'northeast': [
      'Stop & Shop',
      'Giant',
      'ShopRite',
      'Wegmans',
      'Market Basket',
      'Price Chopper',
      'Acme',
      "BJ's",
    ],
    // Midwest
    'midwest': [
      'Kroger',
      'Meijer',
      'Hy-Vee',
      'Jewel-Osco',
      'Schnucks',
    ],
    // Texas
    'texas': [
      'H-E-B',
      'Kroger',
      'Randalls',
      'Fiesta Mart',
    ],
    // West Coast
    'westcoast': [
      'Safeway',
      'Albertsons',
      'Vons',
      'Ralphs',
      'WinCo',
      'Sprouts',
      'Smart & Final',
      'Food 4 Less',
      'Save Mart',
      'Lucky',
      'Grocery Outlet',
      'Fred Meyer',
    ],
    // Specialty (various regions)
    'specialty': [
      "Trader Joe's",
      'Whole Foods',
      'Sprouts',
    ],
  };

  // State to region mapping
  static const Map<String, String> _stateRegions = {
    // Southeast
    'FL': 'southeast', 'GA': 'southeast', 'SC': 'southeast', 'NC': 'southeast',
    'VA': 'southeast', 'AL': 'southeast', 'MS': 'southeast', 'TN': 'southeast',
    'KY': 'southeast', 'WV': 'southeast', 'LA': 'southeast',
    // Northeast
    'NY': 'northeast', 'NJ': 'northeast', 'PA': 'northeast', 'CT': 'northeast',
    'MA': 'northeast', 'RI': 'northeast', 'NH': 'northeast', 'VT': 'northeast',
    'ME': 'northeast', 'DE': 'northeast', 'MD': 'northeast', 'DC': 'northeast',
    // Midwest
    'OH': 'midwest', 'MI': 'midwest', 'IN': 'midwest', 'IL': 'midwest',
    'WI': 'midwest', 'MN': 'midwest', 'IA': 'midwest', 'MO': 'midwest',
    'ND': 'midwest', 'SD': 'midwest', 'NE': 'midwest', 'KS': 'midwest',
    // Texas
    'TX': 'texas',
    // West Coast
    'CA': 'westcoast', 'OR': 'westcoast', 'WA': 'westcoast', 'NV': 'westcoast',
    'AZ': 'westcoast', 'NM': 'westcoast', 'UT': 'westcoast', 'CO': 'westcoast',
    'ID': 'westcoast', 'MT': 'westcoast', 'WY': 'westcoast',
    // Alaska/Hawaii
    'AK': 'westcoast', 'HI': 'westcoast',
  };

  StoreLocator({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Get the state abbreviation from a zip code
  String? _getStateFromZip(String zipCode) {
    final zip = int.tryParse(zipCode.substring(0, 3));
    if (zip == null) return null;

    // ZIP code prefix to state mapping (simplified)
    if (zip >= 100 && zip <= 149) return 'NY';
    if (zip >= 150 && zip <= 196) return 'PA';
    if (zip >= 197 && zip <= 199) return 'DE';
    if (zip >= 200 && zip <= 205) return 'DC';
    if (zip >= 206 && zip <= 219) return 'MD';
    if (zip >= 220 && zip <= 246) return 'VA';
    if (zip >= 247 && zip <= 268) return 'WV';
    if (zip >= 270 && zip <= 289) return 'NC';
    if (zip >= 290 && zip <= 299) return 'SC';
    if (zip >= 300 && zip <= 319) return 'GA';
    if (zip >= 320 && zip <= 349) return 'FL';
    if (zip >= 350 && zip <= 369) return 'AL';
    if (zip >= 370 && zip <= 385) return 'TN';
    if (zip >= 386 && zip <= 397) return 'MS';
    if (zip >= 400 && zip <= 427) return 'KY';
    if (zip >= 430 && zip <= 458) return 'OH';
    if (zip >= 460 && zip <= 479) return 'IN';
    if (zip >= 480 && zip <= 499) return 'MI';
    if (zip >= 500 && zip <= 528) return 'IA';
    if (zip >= 530 && zip <= 549) return 'WI';
    if (zip >= 550 && zip <= 567) return 'MN';
    if (zip >= 570 && zip <= 577) return 'SD';
    if (zip >= 580 && zip <= 588) return 'ND';
    if (zip >= 590 && zip <= 599) return 'MT';
    if (zip >= 600 && zip <= 629) return 'IL';
    if (zip >= 630 && zip <= 658) return 'MO';
    if (zip >= 660 && zip <= 679) return 'KS';
    if (zip >= 680 && zip <= 693) return 'NE';
    if (zip >= 700 && zip <= 714) return 'LA';
    if (zip >= 716 && zip <= 729) return 'AR';
    if (zip >= 730 && zip <= 749) return 'OK';
    if (zip >= 750 && zip <= 799) return 'TX';
    if (zip >= 800 && zip <= 816) return 'CO';
    if (zip >= 820 && zip <= 831) return 'WY';
    if (zip >= 832 && zip <= 838) return 'ID';
    if (zip >= 840 && zip <= 847) return 'UT';
    if (zip >= 850 && zip <= 865) return 'AZ';
    if (zip >= 870 && zip <= 884) return 'NM';
    if (zip >= 889 && zip <= 898) return 'NV';
    if (zip >= 900 && zip <= 961) return 'CA';
    if (zip >= 967 && zip <= 968) return 'HI';
    if (zip >= 970 && zip <= 979) return 'OR';
    if (zip >= 980 && zip <= 994) return 'WA';
    if (zip >= 995 && zip <= 999) return 'AK';
    if (zip >= 10 && zip <= 69) return 'MA';
    if (zip >= 70 && zip <= 89) return 'RI';
    if (zip >= 1 && zip <= 9) return 'CT';
    
    return null;
  }

  /// Get stores available in a specific zip code/location
  Future<List<StoreLocation>> getStoresNearZipCode(String zipCode) async {
    // Check cache first
    if (_storeCache.containsKey(zipCode)) {
      return _storeCache[zipCode]!;
    }

    final stores = <StoreLocation>[];
    final state = _getStateFromZip(zipCode);
    final region = state != null ? _stateRegions[state] : null;

    // Add national chains (always available)
    for (final chain in _regionalChains['national']!) {
      stores.add(_createStoreLocation(chain, zipCode, state ?? 'US'));
    }

    // Add regional chains if we know the region
    if (region != null && _regionalChains.containsKey(region)) {
      for (final chain in _regionalChains[region]!) {
        stores.add(_createStoreLocation(chain, zipCode, state ?? 'US'));
      }
    }

    // Add specialty chains (usually available in metro areas)
    for (final chain in _regionalChains['specialty']!) {
      stores.add(_createStoreLocation(chain, zipCode, state ?? 'US'));
    }

    // Try to fetch real store locations from APIs (async enhancement)
    _fetchRealStoreLocations(zipCode, stores);

    // Cache and return
    _storeCache[zipCode] = stores;
    return stores;
  }

  /// Create a placeholder store location
  StoreLocation _createStoreLocation(String chain, String zipCode, String state) {
    return StoreLocation(
      storeId: '${chain.toLowerCase().replaceAll(' ', '_')}_$zipCode',
      name: chain,
      chain: chain,
      address: 'Near $zipCode',
      city: '',
      state: state,
      zipCode: zipCode,
      hasOnlineOrdering: true,
    );
  }

  /// Fetch real store locations from store locator APIs (async)
  Future<void> _fetchRealStoreLocations(String zipCode, List<StoreLocation> stores) async {
    // This could be enhanced to call actual store locator APIs
    // For now, we're using the regional data
    // 
    // Future enhancements:
    // - Call Walmart Store Finder API
    // - Call Target Store Finder API
    // - Use Google Places API
    // - Use Yelp API for grocery stores
  }

  /// Get list of available chain names for a zip code
  Future<List<String>> getAvailableChains(String zipCode) async {
    final stores = await getStoresNearZipCode(zipCode);
    return stores.map((s) => s.chain).toSet().toList();
  }

  /// Check if a specific chain is available in a zip code
  Future<bool> isChainAvailable(String chain, String zipCode) async {
    final stores = await getStoresNearZipCode(zipCode);
    return stores.any((s) => s.chain.toLowerCase() == chain.toLowerCase());
  }

  /// Get the nearest store of a specific chain
  Future<StoreLocation?> getNearestStore(String chain, String zipCode) async {
    final stores = await getStoresNearZipCode(zipCode);
    final matching = stores.where((s) => s.chain.toLowerCase() == chain.toLowerCase());
    if (matching.isEmpty) return null;
    
    // If we have distance info, return closest
    final withDistance = matching.where((s) => s.distanceMiles != null);
    if (withDistance.isNotEmpty) {
      return withDistance.reduce((a, b) => a.distanceMiles! < b.distanceMiles! ? a : b);
    }
    
    return matching.first;
  }

  /// Clear the cache
  void clearCache() {
    _storeCache.clear();
  }
}

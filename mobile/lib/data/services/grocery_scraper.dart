import 'package:http/http.dart' as http;
import 'dart:async';

/// A comprehensive grocery price scraper that extracts real prices from store websites.
/// Each store has different HTML structures, so we use tailored parsing strategies.
/// 
/// Performance features:
/// - Timeouts to prevent hanging
/// - Parallel requests with fast failure
/// - Graceful fallback to estimates when scraping fails
class GroceryScraper {
  final http.Client _httpClient;
  
  /// Timeout for individual store requests
  static const Duration _requestTimeout = Duration(seconds: 3);
  
  /// Timeout for all stores combined
  static const Duration _allStoresTimeout = Duration(seconds: 8);
  
  // Common user agents to rotate through
  static const List<String> _userAgents = [
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
  ];
  
  int _userAgentIndex = 0;

  GroceryScraper({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Get rotating user agent to avoid detection
  String get _currentUserAgent {
    final ua = _userAgents[_userAgentIndex % _userAgents.length];
    _userAgentIndex++;
    return ua;
  }

  /// Standard headers for scraping requests
  Map<String, String> get _headers => {
    'User-Agent': _currentUserAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Cache-Control': 'max-age=0',
  };

  /// Make an HTTP request with timeout
  Future<http.Response?> _getWithTimeout(Uri url) async {
    try {
      return await _httpClient.get(url, headers: _headers).timeout(_requestTimeout);
    } on TimeoutException {
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Scrape prices from a specific store with timeout
  Future<List<ScrapedProduct>> scrapeStore(String storeName, String query) async {
    try {
      return await _scrapeStoreInternal(storeName, query).timeout(_requestTimeout);
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }
  }
  
  Future<List<ScrapedProduct>> _scrapeStoreInternal(String storeName, String query) async {
    switch (storeName.toLowerCase()) {
      case 'walmart':
        return scrapeWalmart(query);
      case 'target':
        return scrapeTarget(query);
      case 'kroger':
        return scrapeKroger(query);
      case 'safeway':
      case 'albertsons':
        return scrapeSafeway(query);
      case 'publix':
        return scrapePublix(query);
      case 'heb':
      case 'h-e-b':
        return scrapeHEB(query);
      case 'wegmans':
        return scrapeWegmans(query);
      case 'aldi':
        return scrapeAldi(query);
      case 'costco':
        return scrapeCostco(query);
      case 'amazon':
      case 'amazon fresh':
      case 'whole foods':
        return scrapeAmazonFresh(query);
      case 'meijer':
        return scrapeMeijer(query);
      case 'food lion':
        return scrapeFoodLion(query);
      case 'giant':
        return scrapeGiant(query);
      case 'stop & shop':
      case 'stop and shop':
        return scrapeStopAndShop(query);
      case 'trader joes':
      case 'trader joe\'s':
        return scrapeTraderJoes(query);
      case 'winco':
        return scrapeWinco(query);
      case 'sprouts':
        return scrapeSprouts(query);
      case 'smart & final':
        return scrapeSmartAndFinal(query);
      case 'food 4 less':
        return scrapeFood4Less(query);
      case 'save mart':
      case 'lucky':
        return scrapeSaveMart(query);
      default:
        return [];
    }
  }

  /// Scrape all supported stores in parallel with timeout
  Future<Map<String, List<ScrapedProduct>>> scrapeAllStores(String query) async {
    final stores = [
      'walmart', 'target', 'kroger', 'safeway', 'publix', 'heb', 
      'wegmans', 'aldi', 'costco', 'amazon', 'meijer', 'food lion',
      'giant', 'stop & shop', 'trader joes', 'winco', 'sprouts',
    ];
    
    try {
      final results = await Future.wait(
        stores.map((store) async {
          try {
            final products = await scrapeStore(store, query);
            return MapEntry(store, products);
          } catch (e) {
            return MapEntry(store, <ScrapedProduct>[]);
          }
        }),
      ).timeout(_allStoresTimeout);
      
      return Map.fromEntries(results);
    } on TimeoutException {
      return {};
    }
  }

  // ============================================================
  // WALMART SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeWalmart(String query) async {
    try {
      final url = Uri.parse('https://www.walmart.com/search?q=${Uri.encodeComponent(query)}');
      final response = await _getWithTimeout(url);
      
      if (response == null || response.statusCode != 200) return [];
      
      return _parseWalmartHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseWalmartHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    // Walmart HTML contains "current price $X.XX" patterns
    final pricePattern = RegExp(r'current price\s*(?:Now\s*)?\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'([A-Z][^,\[\]]{5,60}),?\s*(\d+\.?\d*\s*(?:oz|lb|ct|pack|gallon|fl oz|Sticks?|Tub))', caseSensitive: false);
    final wasPattern = RegExp(r'Was \$(\d+\.?\d*)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    final wasMatches = wasPattern.allMatches(html).toList();
    
    final seenProducts = <String>{};
    
    for (int i = 0; i < priceMatches.length && results.length < 10; i++) {
      final priceMatch = priceMatches[i];
      final price = double.tryParse(priceMatch.group(1) ?? '');
      
      if (price == null || price > 100 || price < 0.10) continue;
      
      String? productName;
      String? size;
      
      for (final prodMatch in productMatches) {
        if (prodMatch.start < priceMatch.start) {
          final name = prodMatch.group(1)?.trim();
          final matchedSize = prodMatch.group(2)?.trim();
          if (name != null && 
              name.toLowerCase().contains(query.toLowerCase()) &&
              !seenProducts.contains(name)) {
            productName = name;
            size = matchedSize;
          }
        }
      }
      
      double? originalPrice;
      for (final wasMatch in wasMatches) {
        if (wasMatch.start > priceMatch.start && wasMatch.start - priceMatch.start < 200) {
          originalPrice = double.tryParse(wasMatch.group(1) ?? '');
          break;
        }
      }
      
      if (productName != null && !seenProducts.contains(productName)) {
        seenProducts.add(productName);
        results.add(ScrapedProduct(
          name: productName,
          price: price,
          originalPrice: originalPrice,
          size: size,
          store: 'Walmart',
          isOnSale: originalPrice != null && originalPrice > price,
        ));
      }
    }
    
    return results;
  }

  // ============================================================
  // TARGET SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeTarget(String query) async {
    try {
      // Target uses Redsky API which sometimes works
      final url = Uri.parse(
        'https://redsky.target.com/redsky_aggregations/v1/web/plp_search_v2'
        '?key=9f36aeafbe60771e321a7cc95a78140772ab3e96'
        '&channel=WEB&count=10'
        '&keyword=${Uri.encodeComponent(query)}'
        '&offset=0&pricing_store_id=1'
      );

      final response = await _httpClient.get(url, headers: {
        ..._headers,
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        return _parseTargetJson(response.body);
      }
      
      // Fallback to HTML scraping
      return _scrapeTargetHtml(query);
    } catch (e) {
      return _scrapeTargetHtml(query);
    }
  }

  List<ScrapedProduct> _parseTargetJson(String json) {
    // Try to parse Target's JSON response
    try {
      final results = <ScrapedProduct>[];
      
      // Look for price patterns in the JSON
      final pricePattern = RegExp(r'"current_retail":(\d+\.?\d*)');
      final namePattern = RegExp(r'"title":"([^"]+)"');
      
      final priceMatches = pricePattern.allMatches(json).toList();
      final nameMatches = namePattern.allMatches(json).toList();
      
      for (int i = 0; i < priceMatches.length && i < nameMatches.length && results.length < 10; i++) {
        final price = double.tryParse(priceMatches[i].group(1) ?? '');
        final name = nameMatches[i].group(1);
        
        if (price != null && name != null && price < 100) {
          results.add(ScrapedProduct(
            name: name,
            price: price,
            store: 'Target',
          ));
        }
      }
      
      return results;
    } catch (e) {
      return [];
    }
  }

  Future<List<ScrapedProduct>> _scrapeTargetHtml(String query) async {
    try {
      final url = Uri.parse('https://www.target.com/s?searchTerm=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseTargetHtmlResponse(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseTargetHtmlResponse(String html, String query) {
    final results = <ScrapedProduct>[];
    
    // Target HTML patterns
    final pricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'data-test="product-title"[^>]*>([^<]+)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    for (int i = 0; i < productMatches.length && i < priceMatches.length && results.length < 10; i++) {
      final name = productMatches[i].group(1)?.trim();
      final price = double.tryParse(priceMatches[i].group(1) ?? '');
      
      if (name != null && price != null && price < 100 && price > 0.10) {
        results.add(ScrapedProduct(
          name: name,
          price: price,
          store: 'Target',
        ));
      }
    }
    
    return results;
  }

  // ============================================================
  // KROGER SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeKroger(String query) async {
    try {
      final url = Uri.parse('https://www.kroger.com/search?query=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseKrogerHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseKrogerHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    // Kroger uses data attributes and specific class patterns
    final pricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'aria-label="([^"]*' + query + r'[^"]*)"', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    final seenNames = <String>{};
    
    for (final prodMatch in productMatches) {
      if (results.length >= 10) break;
      
      final name = prodMatch.group(1)?.trim();
      if (name == null || seenNames.contains(name)) continue;
      
      // Find nearest price after product name
      for (final priceMatch in priceMatches) {
        if (priceMatch.start > prodMatch.start && priceMatch.start - prodMatch.start < 500) {
          final price = double.tryParse(priceMatch.group(1) ?? '');
          if (price != null && price < 100 && price > 0.10) {
            seenNames.add(name);
            results.add(ScrapedProduct(
              name: name,
              price: price,
              store: 'Kroger',
            ));
            break;
          }
        }
      }
    }
    
    return results;
  }

  // ============================================================
  // SAFEWAY / ALBERTSONS SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeSafeway(String query) async {
    try {
      final url = Uri.parse('https://www.safeway.com/shop/search-results.html?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseSafewayHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseSafewayHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    // Safeway patterns
    final pricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'product-title[^>]*>([^<]+)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    for (int i = 0; i < productMatches.length && i < priceMatches.length && results.length < 10; i++) {
      final name = productMatches[i].group(1)?.trim();
      final price = double.tryParse(priceMatches[i].group(1) ?? '');
      
      if (name != null && price != null && price < 100 && price > 0.10) {
        results.add(ScrapedProduct(
          name: name,
          price: price,
          store: 'Safeway',
        ));
      }
    }
    
    return results;
  }

  // ============================================================
  // PUBLIX SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapePublix(String query) async {
    try {
      final url = Uri.parse('https://www.publix.com/search?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parsePublixHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parsePublixHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    final pricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'product-name[^>]*>([^<]+)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    for (int i = 0; i < productMatches.length && i < priceMatches.length && results.length < 10; i++) {
      final name = productMatches[i].group(1)?.trim();
      final price = double.tryParse(priceMatches[i].group(1) ?? '');
      
      if (name != null && price != null && price < 100 && price > 0.10) {
        results.add(ScrapedProduct(
          name: name,
          price: price,
          store: 'Publix',
        ));
      }
    }
    
    return results;
  }

  // ============================================================
  // H-E-B SCRAPER (Texas)
  // ============================================================
  Future<List<ScrapedProduct>> scrapeHEB(String query) async {
    try {
      final url = Uri.parse('https://www.heb.com/search?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseHEBHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseHEBHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    final pricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'product-title[^>]*>([^<]+)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    for (int i = 0; i < productMatches.length && i < priceMatches.length && results.length < 10; i++) {
      final name = productMatches[i].group(1)?.trim();
      final price = double.tryParse(priceMatches[i].group(1) ?? '');
      
      if (name != null && price != null && price < 100 && price > 0.10) {
        results.add(ScrapedProduct(
          name: name,
          price: price,
          store: 'H-E-B',
        ));
      }
    }
    
    return results;
  }

  // ============================================================
  // WEGMANS SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeWegmans(String query) async {
    try {
      final url = Uri.parse('https://www.wegmans.com/search?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseWegmansHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseWegmansHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    final pricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'product-title[^>]*>([^<]+)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    for (int i = 0; i < productMatches.length && i < priceMatches.length && results.length < 10; i++) {
      final name = productMatches[i].group(1)?.trim();
      final price = double.tryParse(priceMatches[i].group(1) ?? '');
      
      if (name != null && price != null && price < 100 && price > 0.10) {
        results.add(ScrapedProduct(
          name: name,
          price: price,
          store: 'Wegmans',
        ));
      }
    }
    
    return results;
  }

  // ============================================================
  // ALDI SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeAldi(String query) async {
    try {
      // Aldi uses a different URL structure
      final url = Uri.parse('https://www.aldi.us/products/search/?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseAldiHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseAldiHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    // Aldi specific patterns
    final pricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'product-name[^>]*>([^<]+)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    for (int i = 0; i < productMatches.length && i < priceMatches.length && results.length < 10; i++) {
      final name = productMatches[i].group(1)?.trim();
      final price = double.tryParse(priceMatches[i].group(1) ?? '');
      
      if (name != null && price != null && price < 100 && price > 0.10) {
        results.add(ScrapedProduct(
          name: name,
          price: price,
          store: 'Aldi',
        ));
      }
    }
    
    return results;
  }

  // ============================================================
  // COSTCO SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeCostco(String query) async {
    try {
      final url = Uri.parse('https://www.costco.com/CatalogSearch?dept=All&keyword=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseCostcoHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseCostcoHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    // Costco patterns
    final pricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'product-title[^>]*>([^<]+)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    for (int i = 0; i < productMatches.length && i < priceMatches.length && results.length < 10; i++) {
      final name = productMatches[i].group(1)?.trim();
      final price = double.tryParse(priceMatches[i].group(1) ?? '');
      
      if (name != null && price != null && price < 500 && price > 0.10) {
        results.add(ScrapedProduct(
          name: name,
          price: price,
          store: 'Costco',
        ));
      }
    }
    
    return results;
  }

  // ============================================================
  // AMAZON FRESH / WHOLE FOODS SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeAmazonFresh(String query) async {
    try {
      // Amazon Fresh search
      final url = Uri.parse(
        'https://www.amazon.com/s?k=${Uri.encodeComponent(query)}&i=amazonfresh'
      );
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseAmazonHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseAmazonHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    // Amazon price patterns - they use span with class "a-price-whole" and "a-price-fraction"
    final pricePattern = RegExp(r'a-price-whole[^>]*>(\d+)</span>[^<]*<span[^>]*a-price-fraction[^>]*>(\d+)', caseSensitive: false);
    final simplePricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'a-text-normal[^>]*>([^<]+)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    // Try structured price pattern first
    if (priceMatches.isNotEmpty && productMatches.isNotEmpty) {
      for (int i = 0; i < productMatches.length && i < priceMatches.length && results.length < 10; i++) {
        final name = productMatches[i].group(1)?.trim();
        final whole = priceMatches[i].group(1);
        final fraction = priceMatches[i].group(2);
        final price = double.tryParse('$whole.$fraction');
        
        if (name != null && price != null && price < 100 && price > 0.10) {
          results.add(ScrapedProduct(
            name: name,
            price: price,
            store: 'Amazon Fresh',
          ));
        }
      }
    } else {
      // Fallback to simple price pattern
      final simplePriceMatches = simplePricePattern.allMatches(html).toList();
      for (int i = 0; i < productMatches.length && i < simplePriceMatches.length && results.length < 10; i++) {
        final name = productMatches[i].group(1)?.trim();
        final price = double.tryParse(simplePriceMatches[i].group(1) ?? '');
        
        if (name != null && price != null && price < 100 && price > 0.10) {
          results.add(ScrapedProduct(
            name: name,
            price: price,
            store: 'Amazon Fresh',
          ));
        }
      }
    }
    
    return results;
  }

  /// Generic scraper for any URL - attempts to extract prices
  Future<List<ScrapedProduct>> scrapeGenericUrl(String url, String storeName, String query) async {
    try {
      final response = await _httpClient.get(Uri.parse(url), headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseGenericHtml(response.body, storeName, query);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // MEIJER SCRAPER (Midwest)
  // ============================================================
  Future<List<ScrapedProduct>> scrapeMeijer(String query) async {
    try {
      final url = Uri.parse('https://www.meijer.com/search.html?text=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseGenericHtml(response.body, 'Meijer', query);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // FOOD LION SCRAPER (Southeast)
  // ============================================================
  Future<List<ScrapedProduct>> scrapeFoodLion(String query) async {
    try {
      final url = Uri.parse('https://www.foodlion.com/search?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseGenericHtml(response.body, 'Food Lion', query);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // GIANT FOOD SCRAPER (Mid-Atlantic)
  // ============================================================
  Future<List<ScrapedProduct>> scrapeGiant(String query) async {
    try {
      final url = Uri.parse('https://giantfood.com/shop/search-results.html?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseGenericHtml(response.body, 'Giant', query);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // STOP & SHOP SCRAPER (Northeast)
  // ============================================================
  Future<List<ScrapedProduct>> scrapeStopAndShop(String query) async {
    try {
      final url = Uri.parse('https://stopandshop.com/shop/search-results.html?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseGenericHtml(response.body, 'Stop & Shop', query);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // TRADER JOE'S SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeTraderJoes(String query) async {
    try {
      // Trader Joe's doesn't have great online search, but let's try
      final url = Uri.parse('https://www.traderjoes.com/home/search?q=${Uri.encodeComponent(query)}&section=products');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseTraderJoesHtml(response.body, query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseTraderJoesHtml(String html, String query) {
    final results = <ScrapedProduct>[];
    
    // Trader Joe's specific patterns
    final pricePattern = RegExp(r'\$(\d+\.?\d*)', caseSensitive: false);
    final productPattern = RegExp(r'ProductCard_card__title[^>]*>([^<]+)', caseSensitive: false);
    
    final priceMatches = pricePattern.allMatches(html).toList();
    final productMatches = productPattern.allMatches(html).toList();
    
    for (int i = 0; i < productMatches.length && i < priceMatches.length && results.length < 10; i++) {
      final name = productMatches[i].group(1)?.trim();
      final price = double.tryParse(priceMatches[i].group(1) ?? '');
      
      if (name != null && price != null && price < 100 && price > 0.10) {
        results.add(ScrapedProduct(
          name: name,
          price: price,
          store: 'Trader Joe\'s',
        ));
      }
    }
    
    // Fallback to generic
    if (results.isEmpty) {
      return _parseGenericHtml(html, 'Trader Joe\'s', query);
    }
    
    return results;
  }

  // ============================================================
  // WINCO SCRAPER (Western US)
  // ============================================================
  Future<List<ScrapedProduct>> scrapeWinco(String query) async {
    try {
      final url = Uri.parse('https://www.wincofoods.com/search?query=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseGenericHtml(response.body, 'WinCo', query);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // SPROUTS FARMERS MARKET SCRAPER
  // ============================================================
  Future<List<ScrapedProduct>> scrapeSprouts(String query) async {
    try {
      final url = Uri.parse('https://shop.sprouts.com/search?search_term=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseGenericHtml(response.body, 'Sprouts', query);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // SMART & FINAL SCRAPER (Western US)
  // ============================================================
  Future<List<ScrapedProduct>> scrapeSmartAndFinal(String query) async {
    try {
      final url = Uri.parse('https://www.smartandfinal.com/search?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseGenericHtml(response.body, 'Smart & Final', query);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // FOOD 4 LESS SCRAPER (Kroger brand)
  // ============================================================
  Future<List<ScrapedProduct>> scrapeFood4Less(String query) async {
    try {
      final url = Uri.parse('https://www.food4less.com/search?query=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      // Use Kroger parsing since they're the same company
      return _parseKrogerHtml(response.body, query).map((p) => ScrapedProduct(
        name: p.name,
        price: p.price,
        originalPrice: p.originalPrice,
        size: p.size,
        store: 'Food 4 Less',
        isOnSale: p.isOnSale,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // SAVE MART / LUCKY SCRAPER (California)
  // ============================================================
  Future<List<ScrapedProduct>> scrapeSaveMart(String query) async {
    try {
      final url = Uri.parse('https://www.savemart.com/shop/search-results.html?q=${Uri.encodeComponent(query)}');
      final response = await _httpClient.get(url, headers: _headers);
      
      if (response.statusCode != 200) return [];
      
      return _parseGenericHtml(response.body, 'Save Mart', query);
    } catch (e) {
      return [];
    }
  }

  List<ScrapedProduct> _parseGenericHtml(String html, String storeName, String query) {
    final results = <ScrapedProduct>[];
    
    // Generic patterns that work across many sites
    final pricePatterns = [
      RegExp(r'price[^>]*>\s*\$(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'\$(\d+\.?\d*)\s*(?:each|ea|\/ea|per)', caseSensitive: false),
      RegExp(r'current[- ]?price[^>]*>\s*\$(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'sale[- ]?price[^>]*>\s*\$(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'\$(\d+\.\d{2})', caseSensitive: false), // Basic $X.XX pattern
    ];
    
    final productPatterns = [
      RegExp(r'product[- ]?name[^>]*>([^<]+)', caseSensitive: false),
      RegExp(r'product[- ]?title[^>]*>([^<]+)', caseSensitive: false),
      RegExp(r'item[- ]?name[^>]*>([^<]+)', caseSensitive: false),
      RegExp(r'aria-label="([^"]*' + query + r'[^"]*)"', caseSensitive: false),
    ];
    
    final seenNames = <String>{};
    
    // Try each product pattern
    for (final prodPattern in productPatterns) {
      final productMatches = prodPattern.allMatches(html).toList();
      
      for (final prodMatch in productMatches) {
        if (results.length >= 10) break;
        
        final name = prodMatch.group(1)?.trim();
        if (name == null || name.isEmpty || seenNames.contains(name)) continue;
        if (!name.toLowerCase().contains(query.toLowerCase())) continue;
        
        // Find nearest price after product
        for (final pricePattern in pricePatterns) {
          final priceMatches = pricePattern.allMatches(html).toList();
          
          for (final priceMatch in priceMatches) {
            if (priceMatch.start > prodMatch.start && priceMatch.start - prodMatch.start < 1000) {
              final price = double.tryParse(priceMatch.group(1) ?? '');
              if (price != null && price < 100 && price > 0.10) {
                seenNames.add(name);
                results.add(ScrapedProduct(
                  name: name,
                  price: price,
                  store: storeName,
                ));
                break;
              }
            }
          }
          if (seenNames.contains(name)) break;
        }
      }
    }
    
    return results;
  }
}

/// Represents a product scraped from a store website
class ScrapedProduct {
  final String name;
  final double price;
  final double? originalPrice;
  final String? size;
  final String store;
  final bool isOnSale;
  final String? imageUrl;
  final String? productUrl;

  ScrapedProduct({
    required this.name,
    required this.price,
    this.originalPrice,
    this.size,
    required this.store,
    this.isOnSale = false,
    this.imageUrl,
    this.productUrl,
  });

  /// Calculate unit price if size is available
  double? get unitPrice {
    if (size == null) return null;
    
    // Parse size to get numeric value and unit
    final match = RegExp(r'(\d+\.?\d*)\s*(oz|lb|ct|pack|gallon|fl oz|g|kg|ml|l)', caseSensitive: false)
        .firstMatch(size!);
    
    if (match == null) return null;
    
    final amount = double.tryParse(match.group(1) ?? '');
    final unit = match.group(2)?.toLowerCase();
    
    if (amount == null || amount == 0) return null;
    
    // Convert to standard unit (oz for weight, fl oz for volume)
    double standardAmount = amount;
    switch (unit) {
      case 'lb':
        standardAmount = amount * 16; // Convert to oz
        break;
      case 'gallon':
        standardAmount = amount * 128; // Convert to fl oz
        break;
      case 'kg':
        standardAmount = amount * 35.274; // Convert to oz
        break;
      case 'g':
        standardAmount = amount * 0.035274; // Convert to oz
        break;
      case 'l':
        standardAmount = amount * 33.814; // Convert to fl oz
        break;
      case 'ml':
        standardAmount = amount * 0.033814; // Convert to fl oz
        break;
    }
    
    return price / standardAmount;
  }

  @override
  String toString() => '$name - \$${price.toStringAsFixed(2)} at $store${size != null ? ' ($size)' : ''}';
}

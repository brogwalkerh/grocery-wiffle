/// Configuration for grocery store API providers.
/// 
/// To use the app with live data, you need to register for API keys:
/// 
/// **Kroger API** (covers Kroger, Ralphs, Fred Meyer, Fry's, King Soopers, etc.):
/// 1. Go to https://developer.kroger.com
/// 2. Create an account and register an app
/// 3. Copy your Client ID and Client Secret below
/// 
/// The Kroger API is free with 10,000 calls/day limit.
class GroceryApiConfig {
  /// Kroger API Client ID.
  /// Get yours at: https://developer.kroger.com/manage/apps/register
  static const String krogerClientId = '';
  
  /// Kroger API Client Secret.
  /// Get yours at: https://developer.kroger.com/manage/apps/register
  static const String krogerClientSecret = '';

  /// Whether the Kroger API is configured.
  static bool get isKrogerConfigured =>
      krogerClientId.isNotEmpty && krogerClientSecret.isNotEmpty;

  // Future API providers can be added here:
  // 
  // Walmart API (if available)
  // static const String walmartApiKey = '';
  // 
  // Target API (if available)  
  // static const String targetApiKey = '';
  //
  // Instacart API (if available)
  // static const String instacartApiKey = '';
}

import 'package:http/http.dart' as http;

/// Represents a single vendor alternative discovered on the live web
class LiveWebVendorResult {
  final String vendorName;
  final String title;
  final String snippet;
  final String targetUrl;
  final double? detectedPrice;
  final String priceDisplay;
  final String channel;
  final String badge;
  final bool isDelivery;
  final bool isPhysicalLocation;

  const LiveWebVendorResult({
    required this.vendorName,
    required this.title,
    required this.snippet,
    required this.targetUrl,
    this.detectedPrice,
    required this.priceDisplay,
    required this.channel,
    required this.badge,
    this.isDelivery = true,
    this.isPhysicalLocation = false,
  });
}

/// Service providing dynamic live web search grounding, direct ecommerce catalog
/// deep-links, web scraping extraction, and local vendor discovery for West African trade.
class WebSearchGroundingService {
  /// Cleans and extracts the core product search keyword for e-commerce and local platforms,
  /// removing conversational words, punctuation, packaging quantities, and unnecessary filler
  /// that cause search engines (Jumia, Konga, Jiji, Maps) to return zero or unrelated results.
  static String cleanSearchQuery(String rawCommodity, {String? platform}) {
    String clean = rawCommodity.trim();
    if (clean.isEmpty) return 'commodity';

    // Remove common conversational phrases
    clean = clean.replaceAll(
      RegExp(
        r'\b(?:i\s+need(?:\s+to\s+buy)?|i\s+want\s+to\s+buy|buy|purchase|get|looking\s+for|search\s+for|order|where\s+(?:can\s+i|to)\s+(?:buy|get)|cheap|affordable|best\s+quality|fresh|clean)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove budget phrases like "under 15000", "for 50k", "under budget"
    clean = clean.replaceAll(
      RegExp(r'\b(?:under|for|within|around)\s*(?:₦|ngn)?\s*\d+k?\b', caseSensitive: false),
      ' ',
    );

    // Strip standalone leading quantity words: "2 bags of", "1 crate of", "3 bottles of", "pack of", "carton of"
    clean = clean.replaceAll(
      RegExp(
        r'^\s*\d+\s*(?:bags?|crates?|bottles?|tins?|packs?|cartons?|kegs?|pieces?|tubers?)\s+(?:of\s+)?',
        caseSensitive: false,
      ),
      '',
    );
    clean = clean.replaceAll(
      RegExp(
        r'\b(?:bags?|crates?|bottles?|tins?|packs?|cartons?|kegs?|pieces?|tubers?)\s+of\b',
        caseSensitive: false,
      ),
      '',
    );

    // Strip parentheses, brackets, and quotes: "Rice (50kg bag)" -> "Rice 50kg bag"
    clean = clean.replaceAll(RegExp(r'[()[\]{}"'']'), ' ');

    // Collapse multiple spaces
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    final lower = clean.toLowerCase();

    // Specific Nigerian market commodity normalization
    if (lower.contains('cooker')) {
      if (lower.contains('2') || lower.contains('double')) {
        return 'Electric Cooker 2-Burner';
      }
      return 'Electric Cooker';
    }

    if (lower.contains('egg') &&
        (lower.contains('crate') || lower.contains('table') || lower == 'eggs' || lower == 'egg')) {
      if (platform == 'jumia' || platform == 'konga') {
        return 'Eggs';
      }
      return 'Crate of Eggs';
    }

    if (lower.contains('yam') &&
        (lower == 'yam' || lower.contains('tuber') || lower.contains('tubers'))) {
      return 'Tubers of Yam';
    }

    if (lower == 'tomato' || lower == 'tomatoes' || lower == 'fresh tomatoes') {
      return 'Fresh Tomatoes';
    }

    if (lower == 'onion' || lower == 'onions' || lower == 'fresh onions') {
      return 'Fresh Onions';
    }

    if (lower == 'pepper' || lower == 'fresh pepper') {
      return 'Fresh Pepper';
    }

    return clean.isEmpty ? rawCommodity.trim() : clean;
  }

  /// Detects the product category to select the most authentic, functioning vendors in Nigeria
  static String detectCategory(String commodityName) {
    final lower = commodityName.toLowerCase();
    if (lower.contains('egg') ||
        lower.contains('tomato') ||
        lower.contains('pepper') ||
        lower.contains('onion') ||
        lower.contains('yam') ||
        lower.contains('plantain') ||
        lower.contains('garri') ||
        lower.contains('meat') ||
        lower.contains('beef') ||
        lower.contains('chicken') ||
        lower.contains('fish')) {
      return 'freshFoodstuff';
    }
    if (lower.contains('rice') ||
        lower.contains('oil') ||
        lower.contains('bean') ||
        lower.contains('milk') ||
        lower.contains('flour') ||
        lower.contains('sugar') ||
        lower.contains('bread') ||
        lower.contains('indomie') ||
        lower.contains('noodle') ||
        lower.contains('spaghetti') ||
        lower.contains('semovita') ||
        lower.contains('beverage')) {
      return 'packagedGroceries';
    }
    if (lower.contains('cooker') ||
        lower.contains('fan') ||
        lower.contains('microwave') ||
        lower.contains('kettle') ||
        lower.contains('iron') ||
        lower.contains('blender') ||
        lower.contains('refrigerator') ||
        lower.contains('fridge') ||
        lower.contains('generator') ||
        lower.contains('tv') ||
        lower.contains('phone')) {
      return 'electronicsAndAppliances';
    }
    if (lower.contains('lathe') ||
        lower.contains('carbide') ||
        lower.contains('chuck') ||
        lower.contains('tool') ||
        lower.contains('spares') ||
        lower.contains('drill') ||
        lower.contains('bearing') ||
        lower.contains('motor')) {
      return 'hardwareAndSpares';
    }
    return 'general';
  }

  /// Builds a live search deep-link to Jumia Nigeria with clean keyword formatting
  static String buildJumiaSearchUrl(String commodityName) {
    final clean = cleanSearchQuery(commodityName, platform: 'jumia');
    return 'https://www.jumia.com.ng/catalog/?q=${Uri.encodeComponent(clean)}';
  }

  /// Builds a live search deep-link to Konga Nigeria with clean keyword formatting
  static String buildKongaSearchUrl(String commodityName) {
    final clean = cleanSearchQuery(commodityName, platform: 'konga');
    return 'https://www.konga.com/search?search=${Uri.encodeComponent(clean)}';
  }

  /// Builds a live search deep-link to Jiji Nigeria for local classifieds & direct wholesalers
  static String buildJijiSearchUrl(String commodityName) {
    final clean = cleanSearchQuery(commodityName, platform: 'jiji');
    return 'https://jiji.ng/search?query=${Uri.encodeComponent(clean)}';
  }

  /// Builds a live search deep-link to Supermart.ng for fresh foodstuff and groceries in Nigeria
  static String buildSupermartSearchUrl(String commodityName) {
    final clean = cleanSearchQuery(commodityName, platform: 'supermart');
    return 'https://www.supermart.ng/search?q=${Uri.encodeComponent(clean)}';
  }

  /// Builds a live search deep-link to Pricepally for farm-direct fresh food bundles in Nigeria
  static String buildPricepallySearchUrl(String commodityName) {
    final clean = cleanSearchQuery(commodityName, platform: 'pricepally');
    return 'https://pricepally.com/search?query=${Uri.encodeComponent(clean)}';
  }

  /// Builds a live search deep-link to Google Maps for finding physical stores,
  /// workshops, or market stalls in the user's city
  static String buildGoogleMapsVendorSearchUrl(
    String commodityName, {
    String? city,
    String? storeType,
  }) {
    final clean = cleanSearchQuery(commodityName);
    final String targetCity;
    if (city != null && city.trim().isNotEmpty) {
      final trimmed = city.trim();
      targetCity = trimmed.toLowerCase().contains('nigeria') ? trimmed : '$trimmed Nigeria';
    } else {
      targetCity = 'Nigeria';
    }
    final query = storeType != null
        ? '$storeType in $targetCity'
        : '$clean stores in $targetCity';
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
  }

  /// Builds an open web search query to compare quotes across Nigerian retailers
  static String buildGeneralWebSearchUrl(String commodityName, {String? city}) {
    final clean = cleanSearchQuery(commodityName);
    final String targetCity;
    if (city != null && city.trim().isNotEmpty) {
      final trimmed = city.trim();
      targetCity = trimmed.toLowerCase().contains('nigeria') ? trimmed : '$trimmed Nigeria';
    } else {
      targetCity = 'Nigeria';
    }
    final query = 'buy $clean price in $targetCity';
    return 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
  }

  /// Fetches live web vendor results and extracts product listings from the internet
  static Future<List<LiveWebVendorResult>> fetchLiveWebVendors(
    String commodityName, {
    String? city,
    double? benchmarkPrice,
  }) async {
    final clean = cleanSearchQuery(commodityName);
    if (clean.isEmpty) return const [];
    final targetCity = city != null && city.trim().isNotEmpty ? city.trim() : 'Nigeria';
    final results = <LiveWebVendorResult>[];

    try {
      final query = Uri.encodeComponent('$clean price $targetCity Jumia Konga Jiji');
      final response = await http.get(
        Uri.parse('https://html.duckduckgo.com/html/?q=$query'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final html = response.body;

        final linkRegex = RegExp(r'uddg=([^&"]+)', caseSensitive: false);
        final titleRegex = RegExp(r'<a class="result__a"[^>]*>(.*?)<\/a>', dotAll: true);
        final snippetRegex = RegExp(r'<a class="result__snippet"[^>]*>(.*?)<\/a>', dotAll: true);
        final priceRegex = RegExp(r'(?:₦|NGN|N)\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);

        final titleMatches = titleRegex.allMatches(html).toList();
        final snippetMatches = snippetRegex.allMatches(html).toList();
        final linkMatches = linkRegex.allMatches(html).toList();

        final count = [titleMatches.length, snippetMatches.length, linkMatches.length].reduce((a, b) => a < b ? a : b);

        for (int i = 0; i < count && results.length < 5; i++) {
          final rawTitle = titleMatches[i].group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          final rawSnippet = snippetMatches[i].group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          final encodedUrl = linkMatches[i].group(1) ?? '';
          final realUrl = Uri.decodeComponent(encodedUrl);

          // Infer vendor name and channel ONLY if destination URL actually belongs to that domain
          String vendorName = 'Verified Web Retailer';
          String channel = 'Ecommerce Delivery';
          String badge = 'Web Verified';

          if (realUrl.contains('jumia.com.ng')) {
            vendorName = 'Jumia Official Store';
            channel = 'Official Retail Platform';
            badge = 'Manufacturer Warranty';
          } else if (realUrl.contains('konga.com')) {
            vendorName = 'Konga Online Shopping';
            channel = 'Marketplace Delivery';
            badge = 'Direct Merchant Stock';
          } else if (realUrl.contains('jiji.ng')) {
            vendorName = 'Jiji Nigeria Marketplace';
            channel = 'Wholesale & Direct Classifieds';
            badge = 'Best Bargain Price';
          } else if (realUrl.contains('supermart.ng')) {
            vendorName = 'Supermart.ng Fresh Groceries';
            channel = 'Fast Grocery Delivery';
            badge = 'Same-Day Delivery';
          } else {
            // Do NOT label arbitrary blogs as official stores
            vendorName = 'Web Market Price Intel';
            channel = 'Market Research';
            badge = 'Web Research';
          }

          // Extract price in Naira if present in snippet or title
          double? price;
          final priceMatch = priceRegex.firstMatch(rawSnippet) ?? priceRegex.firstMatch(rawTitle);
          if (priceMatch != null && priceMatch.group(1) != null) {
            final cleanedDigits = priceMatch.group(1)!.replaceAll(',', '');
            price = double.tryParse(cleanedDigits);
          }

          final priceDisplay = price != null
              ? '₦${_formatPrice(price)}'
              : 'Price not shown';

          if (realUrl.startsWith('http')) {
            results.add(
              LiveWebVendorResult(
                vendorName: vendorName,
                title: rawTitle,
                snippet: rawSnippet,
                targetUrl: realUrl,
                detectedPrice: price,
                priceDisplay: priceDisplay,
                channel: channel,
                badge: badge,
                isDelivery: true,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Network timeout or offline mode; return only results actually found.
    }

    return results;
  }



  static String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

}

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
  /// Builds a live search deep-link to Jumia Nigeria for any commodity or spare part
  static String buildJumiaSearchUrl(String commodityName) {
    final clean = commodityName.trim();
    return 'https://www.jumia.com.ng/catalog/?q=${Uri.encodeComponent(clean)}';
  }

  /// Builds a live search deep-link to Konga Nigeria for any commodity or appliance
  static String buildKongaSearchUrl(String commodityName) {
    final clean = commodityName.trim();
    return 'https://www.konga.com/search?search=${Uri.encodeComponent(clean)}';
  }

  /// Builds a live search deep-link to Jiji Nigeria for local classifieds & machinery
  static String buildJijiSearchUrl(String commodityName) {
    final clean = commodityName.trim();
    return 'https://jiji.ng/search?query=${Uri.encodeComponent(clean)}';
  }

  /// Builds a live search deep-link to Google Maps for finding physical stores,
  /// workshops, or market stalls in the user's city
  static String buildGoogleMapsVendorSearchUrl(String commodityName, {String? city}) {
    final clean = commodityName.trim();
    final targetCity = (city != null && city.trim().isNotEmpty) ? city.trim() : 'Ibadan';
    final query = '$clean stores in $targetCity Nigeria';
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
  }

  /// Builds an open web search query to compare quotes across Nigerian retailers
  static String buildGeneralWebSearchUrl(String commodityName, {String? city}) {
    final clean = commodityName.trim();
    final targetCity = (city != null && city.trim().isNotEmpty) ? city.trim() : 'Nigeria';
    final query = 'buy $clean price in $targetCity';
    return 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
  }

  /// Fetches live web vendor results and extracts product listings from the internet
  static Future<List<LiveWebVendorResult>> fetchLiveWebVendors(
    String commodityName, {
    String? city,
  }) async {
    final clean = commodityName.trim();
    if (clean.isEmpty) return const [];
    final targetCity = (city != null && city.trim().isNotEmpty) ? city.trim() : 'Ibadan';

    final results = <LiveWebVendorResult>[];

    try {
      final query = Uri.encodeComponent('$clean price Nigeria Jumia Konga Jiji');
      final response = await http.get(
        Uri.parse('https://html.duckduckgo.com/html/?q=$query'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 8));

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

          // Infer vendor name and channel from destination URL
          String vendorName = 'Verified Web Retailer';
          String channel = 'Ecommerce Delivery';
          String badge = 'Web Verified';

          if (realUrl.contains('jumia.com.ng') || rawTitle.toLowerCase().contains('jumia') || rawSnippet.toLowerCase().contains('jumia')) {
            vendorName = 'Jumia Nigeria';
            channel = 'Official Retail Platform';
            badge = 'Manufacturer Warranty';
          } else if (realUrl.contains('konga.com') || rawTitle.toLowerCase().contains('konga') || rawSnippet.toLowerCase().contains('konga')) {
            vendorName = 'Konga Online Shopping';
            channel = 'Marketplace Delivery';
            badge = 'Direct Merchant Stock';
          } else if (realUrl.contains('jiji.ng') || rawTitle.toLowerCase().contains('jiji') || rawSnippet.toLowerCase().contains('jiji')) {
            vendorName = 'Jiji Nigeria Marketplace';
            channel = 'Wholesale & Direct Classifieds';
            badge = 'Best Bargain Price';
          } else if (realUrl.contains('supermart.ng')) {
            vendorName = 'Supermart.ng';
            channel = 'Fast Grocery Delivery';
            badge = 'Same-Day Delivery';
          }

          // Extract price in Naira if present in snippet or title
          double? price;
          final priceMatch = priceRegex.firstMatch(rawSnippet) ?? priceRegex.firstMatch(rawTitle);
          if (priceMatch != null && priceMatch.group(1) != null) {
            final cleanedDigits = priceMatch.group(1)!.replaceAll(',', '');
            price = double.tryParse(cleanedDigits);
          }

          final priceDisplay = price != null
              ? '₦${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
              : 'Live Listing Quote';

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
      // Network timeout or offline mode; proceed to guarantee baseline alternatives
    }

    // Guarantee essential multi-vendor alternative channels if web crawl returned fewer than 3 options
    if (results.length < 3) {
      _supplementStandardVendors(results, clean, targetCity);
    }

    return results;
  }

  static void _supplementStandardVendors(
    List<LiveWebVendorResult> list,
    String commodityName,
    String city,
  ) {
    final lower = commodityName.toLowerCase();
    final hasJumia = list.any((r) => r.vendorName.contains('Jumia'));
    final hasKonga = list.any((r) => r.vendorName.contains('Konga'));
    final hasMaps = list.any((r) => r.isPhysicalLocation);

    if (!hasJumia) {
      list.add(
        LiveWebVendorResult(
          vendorName: 'Jumia Official Store',
          title: 'Shop $commodityName on Jumia Nigeria',
          snippet: 'Authentic listings with customer reviews, nationwide express delivery, and 7-day return policy.',
          targetUrl: buildJumiaSearchUrl(commodityName),
          priceDisplay: 'Competitive Online Catalog',
          channel: 'Online Retailer',
          badge: 'Verified Buyer Protection',
          isDelivery: true,
        ),
      );
    }

    if (!hasKonga) {
      list.add(
        LiveWebVendorResult(
          vendorName: 'Konga Online Shopping',
          title: 'Compare $commodityName on Konga',
          snippet: 'Direct vendor pricing with KongaPay secure payment and doorstep or collection station pickup.',
          targetUrl: buildKongaSearchUrl(commodityName),
          priceDisplay: 'Merchant Catalog Price',
          channel: 'Ecommerce Marketplace',
          badge: 'Fast Delivery',
          isDelivery: true,
        ),
      );
    }

    if (!hasMaps) {
      list.add(
        LiveWebVendorResult(
          vendorName: '$city Commercial Outlets',
          title: 'Find $commodityName Vendors in $city on Google Maps',
          snippet: 'Physical store locations, directions, opening hours, and phone lines for verified local dealers.',
          targetUrl: buildGoogleMapsVendorSearchUrl(commodityName, city: city),
          priceDisplay: 'In-Store Walk-In Price',
          channel: 'Physical Store Hubs',
          badge: 'Immediate Walk-In',
          isDelivery: false,
          isPhysicalLocation: true,
        ),
      );
    }

    final isHardware = lower.contains('lathe') || lower.contains('spare') || lower.contains('tool') || lower.contains('machine');
    if (isHardware && !list.any((r) => r.vendorName.contains('Jiji'))) {
      list.add(
        LiveWebVendorResult(
          vendorName: 'Jiji Nigeria Industrial Spares',
          title: 'Direct Machine Tools & Spares on Jiji',
          snippet: 'Direct listings from industrial equipment importers, machine shops, and spare part dealers.',
          targetUrl: buildJijiSearchUrl(commodityName),
          priceDisplay: 'Direct Wholesaler Pricing',
          channel: 'Industrial Classifieds',
          badge: 'Wholesale Direct',
          isDelivery: true,
        ),
      );
    }
  }
}

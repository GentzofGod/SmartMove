import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/services/web_search_grounding_service.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/models/commodity_item.dart';
import 'package:smartmove/core/services/location_service.dart';
import 'package:smartmove/core/data/demo_seed_data.dart';

void main() {
  group('Live Web Search Grounding & Deep-Links', () {
    test('buildJumiaSearchUrl generates encoded catalog search deep-links', () {
      final url = WebSearchGroundingService.buildJumiaSearchUrl('Electric Cooker 2-Burner');
      expect(url, equals('https://www.jumia.com.ng/catalog/?q=Electric%20Cooker%202-Burner'));
    });

    test('buildKongaSearchUrl generates encoded search deep-links', () {
      final url = WebSearchGroundingService.buildKongaSearchUrl('Lathe Machine Chuck');
      expect(url, equals('https://www.konga.com/search?search=Lathe%20Machine%20Chuck'));
    });

    test('buildJijiSearchUrl generates encoded marketplace search deep-links', () {
      final url = WebSearchGroundingService.buildJijiSearchUrl('Industrial Soluble Cutting Oil');
      expect(url, equals('https://jiji.ng/search?query=Industrial%20Soluble%20Cutting%20Oil'));
    });

    test('buildGoogleMapsVendorSearchUrl generates targeted local shop locator URLs', () {
      final url = WebSearchGroundingService.buildGoogleMapsVendorSearchUrl(
        'Electric Cooker',
        city: 'Ibadan',
      );
      expect(url, contains('google.com/maps/search/'));
      expect(url, contains('Electric%20Cooker%20stores%20in%20Ibadan%20Nigeria'));
    });

    test('fetchLiveWebVendors returns multi-vendor alternatives with valid links', () async {
      final vendors = await WebSearchGroundingService.fetchLiveWebVendors('Electric Cooker', city: 'Ibadan');
      expect(vendors, isNotEmpty);
      expect(vendors.length, greaterThanOrEqualTo(3));

      // Must have online and physical alternatives
      final hasOnline = vendors.any((v) => v.targetUrl.contains('jumia') || v.targetUrl.contains('konga') || v.targetUrl.contains('jiji'));
      final hasMaps = vendors.any((v) => v.isPhysicalLocation || v.targetUrl.contains('maps'));
      expect(hasOnline, isTrue);
      expect(hasMaps, isTrue);

      for (final v in vendors) {
        expect(v.vendorName, isNotEmpty);
        expect(v.targetUrl.startsWith('http'), isTrue);
        expect(v.badge, isNotEmpty);
        expect(v.priceDisplay, isNotEmpty);
      }
    });
  });

  group('Meta AI Live Multi-Vendor Comparison', () {
    test('conductLiveAiVendorComparison synthesizes price spread and actionable advice', () async {
      const aiService = MetaAiService();
      final comparison = await aiService.conductLiveAiVendorComparison('Electric Cooker', city: 'Ibadan');

      expect(comparison.commodityName, equals('Electric Cooker'));
      expect(comparison.vendors, isNotEmpty);
      expect(comparison.priceSpreadDisplay, isNotEmpty);
      expect(comparison.aiRecommendation, contains('Meta AI'));
      expect(comparison.summary, contains('vendor alternatives'));
    });

    test('queryAiPriceResearch grounds in live multi-vendor comparison', () async {
      const aiService = MetaAiService();
      final plan = await aiService.queryAiPriceResearch('Electric Cooker', city: 'Ibadan');

      expect(plan, isNotNull);
      expect(plan!.commodityName, equals('Electric Cooker'));
      expect(plan.liveVendors, isNotEmpty);
      expect(plan.customRecommendation, isNotNull);
    });
  });

  group('Decision Engine Dynamic Deep-Links', () {
    test('Electric cooker plan uses dynamic Jumia search link and Maps locator instead of static homepage', () {
      final cookerItem = ShoppingItem(
        id: 'item-cooker-1',
        productName: 'Electric Cooker 2-Burner',
        quantity: 1,
        unit: 'unit',
        estimatedUnitPrice: 45000,
        brandOrGrade: 'Haier Thermocool OEM',
      );

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 60000,
        baseTransportFare: 500,
        maxTimeHours: 3.0,
        items: [cookerItem],
        userLocation: const GeoPoint(
          latitude: 7.3775,
          longitude: 3.9470,
          city: 'Ibadan',
          label: 'Ibadan Central',
        ),
      );

      expect(plans, isNotEmpty);

      // Verify no plan contains static raw homepage 'https://www.jumia.com.ng'
      for (final plan in plans) {
        for (final source in plan.acquisitionSources) {
          if (source.webUrl != null) {
            expect(
              source.webUrl,
              isNot(equals('https://www.jumia.com.ng')),
              reason: 'Source ${source.outletName} should have item-specific deep-link',
            );
            expect(
              source.webUrl!.contains('Electric%20Cooker') || source.webUrl!.contains('Electric+Cooker') || source.webUrl!.contains('maps'),
              isTrue,
              reason: 'Source webUrl should contain commodity query or map search',
            );
          }
        }
      }
    });
  });

  group('Seed Data Hygiene', () {
    test('demo observations contain 0 Web Grounding Spider entries', () {
      final observations = DemoSeedData.getBenchmarkFoodstuffObservations();
      final spiderEntries = observations.where((o) => o.submitterName == 'Web Grounding Spider').toList();
      expect(spiderEntries, isEmpty);

      final benchmarks = observations.where((o) => o.submitterName == 'Historical Market Benchmark').toList();
      expect(benchmarks.length, equals(5));
    });
  });
}

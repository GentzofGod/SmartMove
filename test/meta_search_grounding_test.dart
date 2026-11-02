import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/models/commodity_item.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/core/models/ai_proposal.dart';
import 'package:smartmove/core/services/location_service.dart';

void main() {
  group('Meta Search Grounding Models & Responses API Parsing (dev.meta.ai/docs/search-grounding)', () {
    test('MetaUrlCitation extracts exact passage slice using character offsets', () {
      const fullText =
          'You can buy the Double Burner Electric Cooker on Jumia Nigeria for ₦18,500 with manufacturer warranty.';
      final citationJson = {
        'url': 'https://www.jumia.com.ng/electric-cooker',
        'title': 'Jumia Official Electric Cooker Listing',
        'start_index': 67,
        'end_index': 74,
      };

      final citation = MetaUrlCitation.fromJson(citationJson, fullText: fullText);
      expect(citation.url, equals('https://www.jumia.com.ng/electric-cooker'));
      expect(citation.title, equals('Jumia Official Electric Cooker Listing'));
      expect(citation.startIndex, equals(67));
      expect(citation.endIndex, equals(74));
      expect(citation.citedPassage, equals('₦18,500'));

      final json = citation.toJson();
      expect(json['url'], equals('https://www.jumia.com.ng/electric-cooker'));
      expect(json['cited_passage'], equals('₦18,500'));
    });

    test('MetaUrlCitation handles empty or out-of-bounds offsets safely', () {
      final citation = MetaUrlCitation.fromJson(
        {
          'url': 'https://konga.com/item',
          'title': 'Konga Item',
          'start_index': 200,
          'end_index': 300,
        },
        fullText: 'Short text',
      );
      expect(citation.citedPassage, isEmpty);
      expect(citation.url, equals('https://konga.com/item'));
    });

    test('MetaSearchGroundingResult parses Responses API output with web_search_call and url_citations', () {
      final mockResponsesPayload = {
        'output': [
          {
            'type': 'web_search_call',
            'web_search_call': {
              'query': 'electric cooker 2-burner price in Nigeria',
              'results': [
                {
                  'title': 'Electric Cooker 2 Burner Hot Plate - Konga',
                  'url': 'https://www.konga.com/product/electric-cooker-2-burner',
                  'snippet': 'Buy 2-burner electric stove on Konga Nigeria at ₦21,500. Fast delivery.',
                },
              ],
            },
          },
          {
            'type': 'message',
            'content': [
              {
                'type': 'text',
                'text':
                    'The current market price for a 2-burner electric cooker is ₦21,500 on Konga Online Shopping.',
                'annotations': [
                  {
                    'type': 'url_citation',
                    'url': 'https://www.konga.com/product/electric-cooker-2-burner',
                    'title': 'Konga Online Shopping',
                    'start_index': 59,
                    'end_index': 66,
                  },
                ],
              },
            ],
          },
        ],
      };

      final result = MetaAiService.parseResponsesApiGroundingForTesting(mockResponsesPayload);

      expect(result.isSearchTriggered, isTrue);
      expect(result.searchQueries, contains('electric cooker 2-burner price in Nigeria'));
      expect(result.citations.length, equals(1));
      expect(result.citations.first.citedPassage, equals('₦21,500'));
      expect(result.discoveredVendors, isNotEmpty);

      final vendor = result.discoveredVendors.first;
      expect(vendor.detectedPrice, equals(21500.0));
      expect(vendor.badge, equals('Meta Search Grounded'));
      expect(vendor.targetUrl, contains('konga.com'));
    });

    test('MetaSearchGroundingResult parses structured JSON shopping items in output text', () {
      final mockStructuredPayload = {
        'output': [
          {
            'type': 'message',
            'content': [
              {
                'type': 'text',
                'text': '''
```json
{
  "budget": 45000,
  "shopping_items": [
    {
      "name": "Lathe Machine Tool Bit 1/2 inch",
      "quantity": 2,
      "unit": "pieces",
      "estimated_unit_price": 6500,
      "brand_or_grade": "High Speed Steel M2",
      "web_reference_url": "https://www.jumia.com.ng/lathe-tool-bit",
      "matched_vendor": "Jumia Industrial Tools"
    }
  ]
}
```
''',
                'annotations': [
                  {
                    'type': 'url_citation',
                    'url': 'https://www.jumia.com.ng/lathe-tool-bit',
                    'title': 'Jumia Industrial Tools',
                    'start_index': 10,
                    'end_index': 40,
                  },
                ],
              },
            ],
          },
        ],
      };

      final result = MetaAiService.parseResponsesApiGroundingForTesting(mockStructuredPayload);
      expect(result.groundedItems.length, equals(1));
      final item = result.groundedItems.first;
      expect(item.productName, equals('Lathe Machine Tool Bit 1/2 inch'));
      expect(item.estimatedUnitPrice, equals(6500.0));
      expect(item.matchedVendorName, equals('Jumia Industrial Tools'));
      expect(item.webReferenceUrl, equals('https://www.jumia.com.ng/lathe-tool-bit'));
      expect(result.estimatedBudget, equals(45000.0));
    });
  });

  group('Uncataloged Products Grounding & Decision Engine Integration', () {
    test('Uncataloged products are enriched with search grounding quotes while in-app sellers take priority', () async {
      const aiService = MetaAiService();

      // In-app observations only contains local food sellers (garri)
      final inAppObs = [
        PriceObservation(
          id: 'obs-local-1',
          productId: 'p-garri-1',
          productName: 'Garri Ijebu',
          price: 1200,
          unit: 'paint rubber',
          sellerName: 'Alhaja Kudirat Stalls',
          marketLocation: 'Bodija Market',
          channel: 'Direct Market',
          isVerified: true,
          inStock: true,
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Alhaja Kudirat',
          submitterRole: 'Trader',
          timestamp: DateTime.now(),
        ),
      ];

      // Base proposal contains 1 local food item and 1 uncataloged hardware item
      final baseProposal = AiPlanProposal(
        rawInput: '2 paint garri ijebu and 60W electric soldering iron in Ibadan',
        shoppingItems: [
          ShoppingItem(
            id: 'item-1',
            productName: 'Garri Ijebu',
            quantity: 2,
            unit: 'paint rubber',
            estimatedUnitPrice: 1400,
          ),
          ShoppingItem(
            id: 'item-2',
            productName: 'Electric Soldering Iron 60W',
            quantity: 1,
            unit: 'piece',
            estimatedUnitPrice: 4500,
          ),
        ],
        budget: 15000,
        executionStatus: 'Initial Parsing',
      );

      final harmonized = await aiService.harmonizeAndStructureWithWebGrounding(
        rawPrompt: '2 paint garri ijebu and 60W electric soldering iron in Ibadan',
        baseProposal: baseProposal,
        city: 'Ibadan',
        inAppObservations: inAppObs,
      );

      expect(harmonized.shoppingItems.length, equals(2));

      // Garri: in-app verified seller should be discovered and placed first
      final garriItem = harmonized.shoppingItems.firstWhere((i) => i.productName.contains('Garri'));
      expect(garriItem.availableSourceQuotes, isNotEmpty);
      expect(garriItem.availableSourceQuotes.first.vendorName, contains('In-App Verified'));

      // Soldering Iron: uncataloged in in-app observations -> grounded in online vendor search
      final ironItem = harmonized.shoppingItems.firstWhere((i) => i.productName.contains('Soldering Iron'));
      expect(ironItem.webReferenceUrl, isNotNull);
      expect(ironItem.webReferenceUrl!.startsWith('http'), isTrue);
      expect(ironItem.referenceLinks, isNotEmpty);
      expect(ironItem.matchedVendorName, isNotNull);
    });

    test('Decision Engine Plan B accurately assigns grounded online vendor and citation URL', () {
      final uncatalogedItem = ShoppingItem(
        id: 'si-grounded-1',
        productName: 'Digital Multimeter DT9205A',
        quantity: 1,
        unit: 'piece',
        estimatedUnitPrice: 8500,
        matchedVendorName: 'Konga Electronics Hub',
        webReferenceUrl: 'https://www.konga.com/product/digital-multimeter-dt9205a',
        referenceLinks: [
          'https://www.konga.com/product/digital-multimeter-dt9205a',
          'https://www.jumia.com.ng/catalog/?q=Digital+Multimeter',
        ],
      );

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 20000,
        baseTransportFare: 500,
        maxTimeHours: 2.0,
        items: [uncatalogedItem],
        userLocation: const GeoPoint(
          latitude: 6.5244,
          longitude: 3.3792,
          city: 'Lagos',
          label: 'Lagos Island',
        ),
      );

      final planB = plans.firstWhere((p) => p.id == 'plan-b');
      expect(planB.acquisitionSources, isNotEmpty);
      final source = planB.acquisitionSources.first;

      // Must adopt grounded vendor name and authentic citation URL
      expect(source.outletName, equals('Konga Electronics Hub'));
      expect(source.webUrl, equals('https://www.konga.com/product/digital-multimeter-dt9205a'));
      expect(source.isPlatformRegisteredTrader, isFalse);
    });

    test('conductLiveAiVendorComparison prioritizes local verified sellers and mentions search grounding when uncataloged', () async {
      const aiService = MetaAiService();

      // Case 1: Commodity has in-app seller
      final localObservations = [
        PriceObservation(
          id: 'obs-1',
          productId: 'p-garri-white',
          productName: 'White Garri',
          price: 1100,
          unit: 'paint rubber',
          sellerName: 'Mama Nkechi Provisions',
          marketLocation: 'Mile 12 Market',
          channel: 'Direct Market',
          isVerified: true,
          inStock: true,
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Mama Nkechi',
          submitterRole: 'Trader',
          timestamp: DateTime.now(),
        ),
      ];

      final comparisonWithSeller = await aiService.conductLiveAiVendorComparison(
        'White Garri',
        city: 'Lagos',
        inAppObservations: localObservations,
      );

      expect(comparisonWithSeller.vendors.first.vendorName, contains('SmartMove Catalog'));
      expect(comparisonWithSeller.aiRecommendation, contains('Found 1 matching app catalog quote'));

      // Case 2: Commodity is not listed in local seller catalog
      final comparisonUncataloged = await aiService.conductLiveAiVendorComparison(
        'Lathe Spindle Chuck Adapter 100mm',
        city: 'Ibadan',
        inAppObservations: const [],
      );

      expect(comparisonUncataloged.aiRecommendation, isNotEmpty);
    });
  });
}

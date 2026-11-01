import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/core/models/item_acquisition_source.dart';
import 'package:smartmove/core/presentation/widgets/seller_location_map_sheet.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/community/presentation/community_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Interactive Open-Source Map & Seller Location Tests (Item 1 & 2)', () {
    testWidgets('1. SellerLocationMapSheet renders OpenStreetMap FlutterMap, stall info, directions and chat actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final obs = PriceObservation(
        id: 'obs-test-1',
        productId: 'prod-rice',
        productName: 'Royal Stallion Rice',
        sellerName: 'Iya Basira Store',
        marketLocation: 'Bodija Market',
        price: 32000,
        unit: '25kg',
        timestamp: DateTime.now(),
        sourceType: ObservationSource.traderConfirmed,
        submitterName: 'Iya Basira',
        submitterRole: 'Trader',
        isVerified: true,
        notes: 'Section B, Stall 14',
        channel: 'Local Market',
        category: 'Groceries',
        inStock: true,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SellerLocationMapSheet.fromObservation(obs),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Directly pump SellerLocationMapSheet
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SellerLocationMapSheet.fromObservation(obs),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify OpenStreetMap FlutterMap is rendered
      expect(find.byType(FlutterMap), findsOneWidget);

      // Verify seller stall info
      expect(find.text('Iya Basira Store'), findsWidgets);
      expect(find.text('Section B, Stall 14'), findsOneWidget);
      expect(find.text('Royal Stallion Rice'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Chat & Buy'), findsOneWidget);
    });

    test('2. ItemAcquisitionSource.fromObservation cleanly converts observation for Trader Negotiation', () {
      final obs = PriceObservation(
        id: 'obs-test-2',
        productId: 'prod-beans',
        productName: 'Oloyin Honey Beans',
        sellerName: 'Alhaji Sikiru Grains',
        marketLocation: 'Oje Market',
        price: 4500,
        unit: 'paint rubber',
        timestamp: DateTime.now(),
        sourceType: ObservationSource.traderConfirmed,
        submitterName: 'Alhaji Sikiru',
        submitterRole: 'Trader',
        isVerified: true,
        channel: 'Local Market',
        category: 'Groceries',
      );

      final source = ItemAcquisitionSource.fromObservation(obs, quantity: 2.0);

      expect(source.outletName, equals('Alhaji Sikiru Grains'));
      expect(source.commodityName, equals('Oloyin Honey Beans'));
      expect(source.unitPrice, equals(4500));
      expect(source.totalCost, equals(9000));
      expect(source.channel, equals(AcquisitionChannel.physicalMarketHub));
      expect(source.isPlatformRegisteredTrader, isTrue);
    });
  });

  group('Meta AI Priority for In-App Sellers Database Tests (Item 3)', () {
    test('3. conductLiveAiVendorComparison combs in-app sellers database first before online stores', () async {
      const aiService = MetaAiService();

      final inAppVerifiedObs = [
        PriceObservation(
          id: 'obs-verified-seller',
          productId: 'prod-rice',
          productName: 'Foreign Parboiled Rice 50kg',
          sellerName: 'Bodija Mama Nkechi Enterprise',
          marketLocation: 'Bodija Market',
          price: 74000,
          unit: '50kg',
          timestamp: DateTime.now(),
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Mama Nkechi',
          submitterRole: 'Trader',
          isVerified: true,
          channel: 'Local Market',
          category: 'Groceries',
        ),
      ];

      final comparison = await aiService.conductLiveAiVendorComparison(
        'Parboiled Rice',
        city: 'Ibadan',
        inAppObservations: inAppVerifiedObs,
      );

      // In-app verified seller MUST BE at index 0 (first in list)
      expect(comparison.vendors.isNotEmpty, isTrue);
      final firstVendor = comparison.vendors.first;
      expect(firstVendor.vendorName, contains('Bodija Mama Nkechi Enterprise'));
      expect(firstVendor.badge, equals('SmartMove Verified Seller'));
      expect(firstVendor.targetUrl, startsWith('smartmove://'));

      // AI recommendation highlights verified in-app seller priority
      expect(comparison.aiRecommendation, contains('active in-app seller quote(s)'));
      expect(comparison.aiRecommendation, contains('Online stores (Jumia, Konga) are ranked below as secondary alternatives'));
    });

    test('4. parseToProposal grounds shopping items with in-app verified sellers at the very front', () async {
      const aiService = MetaAiService();

      final inAppObs = [
        PriceObservation(
          id: 'obs-veg-oil',
          productId: 'prod-oil',
          productName: 'Kings Vegetable Oil 5L',
          sellerName: 'Dugbe Commercial Traders',
          marketLocation: 'Dugbe Mall / Commercial Area',
          price: 11500,
          unit: '5L',
          timestamp: DateTime.now(),
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Dugbe Traders',
          submitterRole: 'Trader',
          isVerified: true,
          channel: 'SMB Store',
          category: 'Groceries',
        ),
      ];

      final proposal = await aiService.parseToProposal(
        'I need 5L vegetable oil',
        inAppObservations: inAppObs,
      );

      expect(proposal.shoppingItems.isNotEmpty, isTrue);
      final item = proposal.shoppingItems.first;

      // In-app verified seller should be attached as the primary quote
      expect(item.availableSourceQuotes.isNotEmpty, isTrue);
      expect(item.availableSourceQuotes.first.badge, equals('SmartMove Verified Seller'));
      expect(item.availableSourceQuotes.first.vendorName, contains('Dugbe Commercial Traders'));
    });
  });

  group('Community Screen Tab Separation & Categorization Tests (Item 4)', () {
    testWidgets('5. CommunityScreen separates verified sellers and community reports into 2 tabs with single-line category filter', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add one verified seller listing and one community observation
      container.read(communityProvider.notifier).addObservation(
            productName: 'Organic Honey 1L',
            sellerName: 'Beehive Apex',
            marketLocation: 'Oje Market',
            price: 5000,
            unit: 'bottle',
            submitterName: 'Beehive Apex',
            submitterRole: 'Trader',
            category: 'Groceries',
          );

      container.read(communityProvider.notifier).addObservation(
            productName: 'Digital Multimeter',
            sellerName: 'Electronics Alley',
            marketLocation: 'Dugbe Alawo',
            price: 18000,
            unit: 'unit',
            submitterName: 'Segun Shopper',
            submitterRole: 'Customer',
            category: 'Electronics',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CommunityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify two-tab segmented headers are present
      expect(find.byKey(const ValueKey('tab_verified_sellers')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_community_reports')), findsOneWidget);
      expect(find.textContaining('Verified Sellers'), findsWidgets);
      expect(find.textContaining('Community Reports'), findsWidgets);

      // 2. Verify single-line category filter chips are present
      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Groceries'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Electronics'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Pharmacy'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Others'), findsOneWidget);

      // 3. Double-line filter chips are GONE (no 'Local Market' or 'SMB Store' filter chips in feed bar)
      expect(find.widgetWithText(ChoiceChip, 'SMB Store'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Online Retailer'), findsNothing);

      // 4. In Verified Sellers tab, Organic Honey is listed with action buttons
      expect(find.text('Organic Honey 1L'), findsOneWidget);
      expect(find.text('Locate on Map'), findsOneWidget);
      expect(find.text('Chat & Buy'), findsOneWidget);

      // 5. Switch to Community Reports tab
      await tester.tap(find.byKey(const ValueKey('tab_community_reports')));
      await tester.pumpAndSettle();

      expect(find.text('Digital Multimeter'), findsOneWidget);
      expect(find.text('Organic Honey 1L'), findsNothing);

      // 6. Test category filtering: Tap Groceries while in Community tab
      await tester.tap(find.widgetWithText(ChoiceChip, 'Groceries'));
      await tester.pumpAndSettle();

      // Digital Multimeter (Electronics) is filtered out
      expect(find.text('Digital Multimeter'), findsNothing);
      expect(find.text('No Listings in this Section'), findsOneWidget);

      // Tap Electronics: Digital Multimeter reappears
      await tester.tap(find.widgetWithText(ChoiceChip, 'Electronics'));
      await tester.pumpAndSettle();
      expect(find.text('Digital Multimeter'), findsOneWidget);
    });
  });
}

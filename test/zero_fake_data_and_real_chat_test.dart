import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/models/item_acquisition_source.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/services/location_service.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/core/presentation/widgets/seller_location_map_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Zero Fake Data & Accurate Location Tests', () {
    test('1. Abeokuta user does not get sent 66km away to Bodija Market, Ibadan', () {
      // Abeokuta coordinates: 7.1557, 3.3451
      const abeokutaLoc = GeoPoint(
        latitude: 7.1557,
        longitude: 3.3451,
        label: 'Kuto Market, Abeokuta',
        city: 'Ogun',
        town: 'Abeokuta',
        isDeviceLocation: true,
      );

      // Verify findClosestHub selects Abeokuta, not Ibadan
      final closestHub = LocationService.findClosestHub(abeokutaLoc.latitude, abeokutaLoc.longitude);
      expect(closestHub.town, 'Abeokuta');
      expect(closestHub.label.contains('Abeokuta'), isTrue);
      expect(closestHub.label.contains('Bodija'), isFalse);

      // Distance from user to Kuto market in Abeokuta should be < 0.1km
      final distToKuto = LocationService.calculateDistanceKm(
        lat1: abeokutaLoc.latitude,
        lon1: abeokutaLoc.longitude,
        lat2: closestHub.latitude,
        lon2: closestHub.longitude,
      );
      expect(distToKuto, lessThan(0.5));

      // Distance to Bodija Market (7.4343, 3.9056) should be around ~66km, proving Bodija is NOT the local hub
      final distToBodija = LocationService.calculateDistanceKm(
        lat1: abeokutaLoc.latitude,
        lon1: abeokutaLoc.longitude,
        lat2: 7.4343,
        lon2: 3.9056,
      );
      expect(distToBodija, greaterThan(60.0));
    });

    test('2. DecisionEngine anchors market hubs to Abeokuta for Abeokuta users', () {
      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 25000,
        baseTransportFare: 600,
        maxTimeHours: 2.0,
        userLocation: const GeoPoint(
          latitude: 7.1475,
          longitude: 3.3619,
          label: 'Abeokuta Central',
          city: 'Ogun',
          town: 'Abeokuta',
        ),
      );

      expect(plans, isNotEmpty);
      final planA = plans.first;
      for (final src in planA.acquisitionSources) {
        if (src.channel == AcquisitionChannel.physicalMarketHub) {
          // Outlet must be in Abeokuta, never Ibadan or Bodija
          expect(src.outletName.toLowerCase().contains('bodija'), isFalse);
          expect(src.marketHubOrLocation.toLowerCase().contains('bodija'), isFalse);
          expect(src.dynamicDistanceKm, lessThan(10.0));
        }
      }
    });

    test('3. SellerApplication fromJson defaults to Local Market, never Bodija Market', () {
      final app = SellerApplication.fromJson({
        'id': 'app-test-1',
        'userId': 'user-123',
        'businessName': 'Abeokuta Rice Enterprise',
      });

      expect(app.marketHub, 'Local Market');
      expect(app.marketHub.contains('Bodija'), isFalse);
    });
  });

  group('Real Persistent Buyer-Seller Chat Tests', () {
    test('4. TraderChatNotifier handles buyer message and real seller reply without auto-reply simulation', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(traderChatProvider.notifier);

      // Customer sends price inquiry
      await notifier.sendCustomerMessage(
        traderName: 'Kuto Grain Merchants',
        commodityName: 'Mama Gold Rice',
        quantity: 2,
        unit: 'kg',
        listedPrice: 3200,
        messageText: 'Hello, do you have 2kg in stock today?',
      );

      final chatMap = container.read(traderChatProvider);
      expect(chatMap.containsKey('Kuto Grain Merchants'), isTrue);

      final thread = chatMap['Kuto Grain Merchants']!;
      expect(thread.length, 1);
      expect(thread.first.isTrader, isFalse);
      expect(thread.first.text, 'Hello, do you have 2kg in stock today?');

      // Verified Seller replies from their Seller Portal
      await notifier.sendTraderReply(
        traderName: 'Kuto Grain Merchants',
        replyText: 'Yes, fresh stock arrived this morning at Stall 12.',
        commodityName: 'Mama Gold Rice',
      );

      final updatedThread = container.read(traderChatProvider)['Kuto Grain Merchants']!;
      expect(updatedThread.length, 2);
      expect(updatedThread.last.isTrader, isTrue);
      expect(updatedThread.last.text, 'Yes, fresh stock arrived this morning at Stall 12.');
    });

    test('5. TraderChatMessage serialization preserves all fields', () {
      final now = DateTime.now();
      final msg = TraderChatMessage(
        id: 'msg-01',
        senderName: 'Tunde',
        isTrader: false,
        text: 'Can I get 5kg?',
        timestamp: now,
        proposedPrice: 7500,
        conversationKey: 'Kuto Grain Merchants',
        commodityName: 'Rice',
      );

      final json = msg.toJson();
      final restored = TraderChatMessage.fromJson(json);

      expect(restored.id, 'msg-01');
      expect(restored.senderName, 'Tunde');
      expect(restored.isTrader, isFalse);
      expect(restored.proposedPrice, 7500);
      expect(restored.conversationKey, 'Kuto Grain Merchants');
      expect(restored.commodityName, 'Rice');
    });
  });

  group('Dynamic Commodity Category CRUD Tests', () {
    test('6. CategoriesNotifier supports dynamic add, update, and delete', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(categoriesProvider.notifier);
      final initialCategories = container.read(categoriesProvider);
      expect(initialCategories, isNotEmpty);

      // 1. Add category
      notifier.addCategory(
        name: 'Automotive & Machinery',
        description: 'Spare parts, mechanical tools, and lubricants',
      );

      var categories = container.read(categoriesProvider);
      expect(categories.any((c) => c.name == 'Automotive & Machinery'), isTrue);
      final added = categories.firstWhere((c) => c.name == 'Automotive & Machinery');

      // 2. Update category
      notifier.updateCategory(
        id: added.id,
        name: 'Industrial Machinery & Spares',
        description: 'Heavy equipment parts and tools',
      );

      categories = container.read(categoriesProvider);
      expect(categories.any((c) => c.name == 'Industrial Machinery & Spares'), isTrue);
      expect(categories.any((c) => c.name == 'Automotive & Machinery'), isFalse);

      // 3. Delete category
      notifier.deleteCategory(added.id);
      categories = container.read(categoriesProvider);
      expect(categories.any((c) => c.id == added.id), isFalse);
    });
  });

  group('SellerLocationMapSheet Widget Verification Tests', () {
    testWidgets('7. SellerLocationMapSheet displays uncalibrated GPS state without fake Bodija marker', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SellerLocationMapSheet(
                sellerName: 'Abeokuta Local Trader',
                marketLocation: 'Unknown Remote Stalls',
                productName: 'Egusi Melon',
                price: 1800,
                unit: '1kg',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show friendly uncalibrated banner rather than sending user 66km away to Bodija
      expect(find.text('Stall GPS Not Yet Calibrated'), findsOneWidget);
      expect(find.textContaining('Abeokuta Local Trader is listed at "Unknown Remote Stalls"'), findsOneWidget);
      expect(find.text('Chat & Buy'), findsOneWidget);
    });

    testWidgets('8. SellerLocationMapSheet resolves accurate coordinates for Kuto Market seller', (tester) async {
      final obs = PriceObservation(
        id: 'obs-kuto-1',
        productId: 'p-rice',
        productName: 'Rice (50kg)',
        sellerName: 'Kuto Grain Depot',
        submitterName: 'Kuto Grain Depot',
        marketLocation: 'Kuto Market, Abeokuta',
        price: 75000,
        unit: '50kg',
        timestamp: DateTime.now(),
        sourceType: ObservationSource.traderConfirmed,
        isVerified: true,
        channel: 'Local Market',
        latitude: 7.1420,
        longitude: 3.3550,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SellerLocationMapSheet.fromObservation(obs),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kuto Grain Depot'), findsWidgets);
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Chat & Buy'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/models/commodity_item.dart';
import 'package:smartmove/core/models/item_acquisition_source.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/services/location_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/decision_lab/presentation/widgets/trader_negotiation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trader Prioritization & Outlet Resolution Tests', () {
    test('Prioritizes approved registered traders for food staple shopping items', () {
      final items = [
        ShoppingItem(
          id: 'item-rice',
          productName: 'Rice (50kg bag)',
          estimatedUnitPrice: 78000,
          quantity: 1,
          unit: 'bag',
          priority: CommodityPriority.high,
        ),
        ShoppingItem(
          id: 'item-oil',
          productName: 'Vegetable Cooking Oil (5L)',
          estimatedUnitPrice: 12500,
          quantity: 2,
          unit: 'keg',
          priority: CommodityPriority.medium,
        ),
      ];

      final registeredTraders = [
        SellerApplication(
          id: 'app-bello',
          userId: 'usr-bello',
          applicantName: 'Mama Bello',
          applicantEmail: 'bello@bodija.ng',
          businessName: 'Mama Bello Grains & Oil Enterprise',
          marketHub: 'Bodija Market',
          sellerChannel: 'Local Market',
          stallLocation: 'Stall 14, Main Grain Line, Bodija Market Wholesale Hub',
          phone: '+234 802 345 6789',
          status: SellerApplicationStatus.approved,
          submittedAt: DateTime(2025, 1, 1),
        ),
      ];

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 150000,
        baseTransportFare: 1500,
        maxTimeHours: 3.0,
        items: items,
        registeredTraders: registeredTraders,
        userLocation: const GeoPoint(
          latitude: 7.4343,
          longitude: 3.9056,
          label: 'Bodija Market Area',
          city: 'Ibadan',
          town: 'Bodija',
        ),
      );

      expect(plans.isNotEmpty, true);
      final planA = plans.firstWhere((p) => p.name == 'Option A');
      expect(planA.acquisitionSources.isNotEmpty, true);

      // Verify that rice and oil were mapped to Mama Bello
      final riceSource = planA.acquisitionSources.firstWhere((s) => s.commodityName.contains('Rice'));
      expect(riceSource.isPlatformRegisteredTrader, true);
      expect(riceSource.outletName, contains('Mama Bello'));
      expect(riceSource.channel, AcquisitionChannel.registeredTrader);
      expect(riceSource.contactPhone, isNotNull);
      expect(riceSource.whatsappNumber, isNotNull);
    });

    test('Computes dynamic distances based on user coordinates', () {
      final items = [
        ShoppingItem(
          id: 'item-eggs',
          productName: 'Crate of Eggs',
          estimatedUnitPrice: 4200,
          quantity: 2,
          unit: 'crate',
          priority: CommodityPriority.high,
        ),
      ];

      // Bodija user location (very close to market hub)
      final plansBodija = DecisionEngine.calculateCandidatePlans(
        userBudget: 20000,
        baseTransportFare: 800,
        maxTimeHours: 2.0,
        items: items,
        userLocation: const GeoPoint(
          latitude: 7.4350,
          longitude: 3.9060,
          label: 'Bodija Community',
          city: 'Ibadan',
          town: 'Bodija',
        ),
      );

      final planABodija = plansBodija.first;
      final sourceBodija = planABodija.acquisitionSources.first;
      expect(sourceBodija.dynamicDistanceKm < 1.0, true);

      // Oluyole / Ring Road user location (~10-12 km away from Bodija hub)
      final plansOluyole = DecisionEngine.calculateCandidatePlans(
        userBudget: 20000,
        baseTransportFare: 800,
        maxTimeHours: 2.0,
        items: items,
        userLocation: const GeoPoint(
          latitude: 7.3500,
          longitude: 3.8500,
          label: 'Oluyole Industrial Estate',
          city: 'Ibadan',
          town: 'Oluyole',
        ),
      );

      final planAOluyole = plansOluyole.first;
      final sourceOluyole = planAOluyole.acquisitionSources.first;
      expect(sourceOluyole.dynamicDistanceKm > 9.0, true);
      expect(sourceOluyole.dynamicDistanceKm > sourceBodija.dynamicDistanceKm, true);
    });

    test('Maps stationery, supplies, and electronics to ecommerce platforms with secure web URLs', () {
      final items = [
        ShoppingItem(
          id: 'item-stationery',
          productName: 'Mathematical Set and Hardcover Notebooks',
          estimatedUnitPrice: 6500,
          quantity: 3,
          unit: 'pack',
          priority: CommodityPriority.medium,
        ),
      ];

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 30000,
        baseTransportFare: 1000,
        maxTimeHours: 2.5,
        items: items,
      );

      final planA = plans.first;
      final stationerySource = planA.acquisitionSources.first;
      expect(
        stationerySource.channel == AcquisitionChannel.ecommercePlatform ||
            stationerySource.channel == AcquisitionChannel.retailStore,
        true,
      );
      if (stationerySource.channel == AcquisitionChannel.ecommercePlatform) {
        expect(stationerySource.webUrl, isNotNull);
        expect(stationerySource.webUrl!.startsWith('https://'), true);
      }
    });
  });

  group('In-App Trader Chat & Negotiation Tests', () {
    test('TraderChatNotifier handles customer offers and generates realistic replies', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(traderChatProvider.notifier);

      // 1. Initial message with offer within 10% discount
      notifier.sendCustomerMessage(
        traderName: 'Mama Bello Grains & Oil Enterprise',
        commodityName: 'Rice (50kg bag)',
        quantity: 1,
        unit: 'bag',
        listedPrice: 78000,
        messageText: 'I would like to offer ₦74,000 for 1 bag of Rice. Can we agree on this price?',
        proposedPrice: 74000,
      );

      var history = container.read(traderChatProvider)['Mama Bello Grains & Oil Enterprise']!;
      expect(history.length, 2); // Initial greeting + customer message
      expect(history.last.isTrader, false);
      expect(history.last.proposedPrice, 74000);

      // Wait for simulated trader response delay
      await Future.delayed(const Duration(milliseconds: 700));

      history = container.read(traderChatProvider)['Mama Bello Grains & Oil Enterprise']!;
      expect(history.length, 3);
      expect(history.last.isTrader, true);
      expect(history.last.text.toLowerCase(), contains('deal agreed'));
    });

    test('TraderChatNotifier counter-offers when customer requests an excessive discount', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(traderChatProvider.notifier);

      // Customer offers ₦40,000 for a ₦78,000 item (almost 50% off!)
      notifier.sendCustomerMessage(
        traderName: 'Mama Bello Grains & Oil Enterprise',
        commodityName: 'Rice (50kg bag)',
        quantity: 1,
        unit: 'bag',
        listedPrice: 78000,
        messageText: 'Can I pay ₦40,000 for this bag?',
        proposedPrice: 40000,
      );

      await Future.delayed(const Duration(milliseconds: 700));

      final history = container.read(traderChatProvider)['Mama Bello Grains & Oil Enterprise']!;
      expect(history.last.isTrader, true);
      // Trader should decline below cost price and counter-offer
      expect(history.last.text.toLowerCase(), contains('below our cost price'));
    });
  });

  group('Trader Negotiation Sheet Widget Tests', () {
    testWidgets('Renders TraderNegotiationSheet without overflow on compact 360x640 display', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const source = ItemAcquisitionSource(
        id: 'source-rice-01',
        itemId: 'item-rice',
        commodityName: 'Rice (50kg bag)',
        quantity: 1,
        unit: 'bag',
        unitPrice: 78000,
        totalCost: 78000,
        outletName: 'Mama Bello Grains & Oil Enterprise',
        marketHubOrLocation: 'Bodija Market Wholesale Hub',
        channel: AcquisitionChannel.registeredTrader,
        isPlatformRegisteredTrader: true,
        contactPhone: '+234 802 345 6789',
        whatsappNumber: '2348023456789',
        dynamicDistanceKm: 1.4,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TraderNegotiationSheet(source: source),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check key UI components
      expect(find.text('Mama Bello Grains & Oil Enterprise'), findsOneWidget);
      expect(find.text('Verified Trader'), findsOneWidget);
      expect(find.textContaining('Rice (50kg bag)'), findsWidgets);
      expect(find.text('Make Offer'), findsOneWidget);
      expect(find.byTooltip('Call Trader'), findsOneWidget);
      expect(find.byTooltip('WhatsApp Inquiry'), findsOneWidget);

      // Check quick chips
      expect(find.text('Can you do a discount for bulk purchase?'), findsOneWidget);

      // Ensure no overflow
      expect(tester.takeException(), isNull);
    });
  });
}

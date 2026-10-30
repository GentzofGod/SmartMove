import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/models/product.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/discover/presentation/product_detail_sheet.dart';

class _MockCommunityNotifier extends CommunityNotifier {
  final List<PriceObservation> _observations;
  _MockCommunityNotifier(this._observations);

  @override
  List<PriceObservation> build() => _observations;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testProduct = Product(
    id: 'p-rice-50kg',
    name: 'Rice (50kg Bag)',
    category: 'Grains & Flours',
    standardUnit: '50kg',
    lowestPrice: 82000,
    bestSeller: 'Bodija Market Hub',
    distanceKm: 2.3,
    updateTime: '1h ago',
    brandOrGrade: 'Mama Gold Premium (Grade A)',
    baseUnit: 'kg',
    standardizedUnitPrice: 1640.0,
    sourceType: ObservationSource.traderConfirmed,
  );

  final testObservations = [
    PriceObservation(
      id: 'obs-bodija-01',
      productId: 'p-rice-50kg',
      productName: 'Rice (50kg Bag)',
      sellerName: 'Alhaji Danladi Grains',
      marketLocation: 'Bodija Market',
      price: 82000,
      unit: '50kg',
      timestamp: DateTime.now(),
      sourceType: ObservationSource.traderConfirmed,
      submitterName: 'Alhaji Danladi',
      submitterRole: 'Trader',
      isVerified: true,
      channel: 'Local Market',
      brandOrGrade: 'Mama Gold Grade A',
      standardizedUnitPrice: 1640.0,
      baseUnit: 'kg',
    ),
    PriceObservation(
      id: 'obs-supermarket-01',
      productId: 'p-rice-50kg',
      productName: 'Rice (50kg Bag)',
      sellerName: 'Justrite Superstore',
      marketLocation: 'Bodija Express Road',
      price: 89000,
      unit: '50kg',
      timestamp: DateTime.now(),
      sourceType: ObservationSource.communityReported,
      submitterName: 'Kemi Shopper',
      submitterRole: 'Customer',
      isVerified: true,
      channel: 'SMB Store',
      brandOrGrade: 'Standard Sealed Bag',
      standardizedUnitPrice: 1780.0,
      baseUnit: 'kg',
    ),
    PriceObservation(
      id: 'obs-jumia-01',
      productId: 'p-rice-50kg',
      productName: 'Rice (50kg Bag)',
      sellerName: 'Jumia Supermarket',
      marketLocation: 'Online Platform',
      price: 94000,
      unit: '50kg',
      timestamp: DateTime.now(),
      sourceType: ObservationSource.onlineGrounded,
      submitterName: 'Web Grounding Engine',
      submitterRole: 'System',
      isVerified: true,
      channel: 'Online Retailer',
      brandOrGrade: 'Factory Sealed Certified',
      standardizedUnitPrice: 1880.0,
      baseUnit: 'kg',
    ),
  ];

  group('Meta AI Multi-Criteria Options Analysis Unit Tests', () {
    const aiService = MetaAiService();

    test('1. Accurately calculates landed cost with delivery fees across channels', () {
      final result = aiService.analyzeAvailableOptions(
        product: testProduct,
        observations: testObservations,
        requestedQuantity: 1.0,
        priority: UserDecisionPriority.balancedValue,
      );

      expect(result.evaluatedOptions.length, equals(3));

      // Local market option: ₦82,000 subtotal + ₦0 delivery = ₦82,000 landed
      final local = result.evaluatedOptions.firstWhere((o) => o.channel == SellerChannel.localMarket);
      expect(local.productSubtotal, equals(82000.0));
      expect(local.deliveryFee, equals(0.0));
      expect(local.totalLandedCost, equals(82000.0));

      // SMB store option: ₦89,000 subtotal + ₦600 delivery = ₦89,600 landed
      final smb = result.evaluatedOptions.firstWhere((o) => o.channel == SellerChannel.smbStore);
      expect(smb.productSubtotal, equals(89000.0));
      expect(smb.deliveryFee, equals(600.0));
      expect(smb.totalLandedCost, equals(89600.0));

      // Online retailer option: ₦94,000 subtotal + ₦1,500 delivery = ₦95,500 landed
      final online = result.evaluatedOptions.firstWhere((o) => o.channel == SellerChannel.onlineRetailer);
      expect(online.productSubtotal, equals(94000.0));
      expect(online.deliveryFee, equals(1500.0));
      expect(online.totalLandedCost, equals(95500.0));
      expect(online.distanceKm, equals(0.0)); // 0 travel distance
    });

    test('2. Evaluates quality, reputation, and customer support attributes per channel', () {
      final result = aiService.analyzeAvailableOptions(
        product: testProduct,
        observations: testObservations,
        requestedQuantity: 1.0,
      );

      final online = result.evaluatedOptions.firstWhere((o) => o.channel == SellerChannel.onlineRetailer);
      expect(online.qualityScore, greaterThanOrEqualTo(4.5));
      expect(online.reputationScore, greaterThanOrEqualTo(4.5));
      expect(online.customerSupportPolicy, contains('7-Day doorstep'));

      final local = result.evaluatedOptions.firstWhere((o) => o.channel == SellerChannel.localMarket);
      expect(local.customerSupportPolicy, contains('exchange'));
      expect(local.aiPros, anyElement(contains('Lowest unit price')));
    });

    test('3. Re-ranks options when user selects Lowest Price priority', () {
      final result = aiService.analyzeAvailableOptions(
        product: testProduct,
        observations: testObservations,
        requestedQuantity: 1.0,
        priority: UserDecisionPriority.lowestPrice,
      );

      // Local market must rank #1 due to cheapest landed cost
      expect(result.recommendedOption, isNotNull);
      expect(result.recommendedOption!.channel, equals(SellerChannel.localMarket));
      expect(result.recommendedOption!.recommendationBadge, contains('Lowest Total Outlay'));
    });

    test('4. Re-ranks options when user selects Doorstep & Speed priority', () {
      final result = aiService.analyzeAvailableOptions(
        product: testProduct,
        observations: testObservations,
        requestedQuantity: 1.0,
        priority: UserDecisionPriority.convenienceDelivery,
      );

      // Online retailer or SMB store with zero transit should rank #1
      expect(result.recommendedOption, isNotNull);
      expect(result.recommendedOption!.channel, equals(SellerChannel.onlineRetailer));
      expect(result.recommendedOption!.recommendationBadge, contains('Top Convenience'));
    });

    test('5. Produces comprehensive Muse Spark executive narrative and comparison highlights', () {
      final result = aiService.analyzeAvailableOptions(
        product: testProduct,
        observations: testObservations,
        requestedQuantity: 2.0,
        priority: UserDecisionPriority.balancedValue,
      );

      expect(result.executiveSummary, contains('Meta Muse Spark Option Analysis'));
      expect(result.executiveSummary, contains('Landed cost'));
      expect(result.comparisonHighlights.length, greaterThanOrEqualTo(2));
    });
  });

  group('ProductDetailSheet Multi-Criteria UI Widget Tests', () {
    testWidgets('6. Expands options matrix and allows switching decision priority chips', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            communityProvider.overrideWith(() => _MockCommunityNotifier(testObservations)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProductDetailSheet(product: testProduct),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the Meta AI Multi-Criteria Header
      final headerFinder = find.text('Meta AI Multi-Criteria Options Matrix');
      expect(headerFinder, findsOneWidget);

      // Tap header to expand
      await tester.tap(headerFinder);
      await tester.pumpAndSettle();

      // Verify Priority chips are visible
      expect(find.text('Balanced Value'), findsOneWidget);
      expect(find.text('Lowest Outlay'), findsOneWidget);
      expect(find.text('Doorstep & Speed'), findsOneWidget);
      expect(find.text('Quality & Trust'), findsOneWidget);

      // Verify recommendation badge and Landed Outlay label
      expect(find.text('Landed Outlay'), findsOneWidget);
      expect(find.text('Meta Muse Spark Rationale'), findsOneWidget);

      // Tap 'Lowest Outlay' chip
      await tester.tap(find.text('Lowest Outlay'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Minimizes total cash expenditure'), findsOneWidget);

      // Drag to scroll the sheet down
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Tap comparison matrix toggle
      final toggleFinder = find.textContaining('Compare All');
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Drag a little further down to view options cards
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Verify comparison cards appear
      expect(find.textContaining('Total Landed'), findsWidgets);
    });
  });
}

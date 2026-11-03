import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/models/commodity_item.dart';
import 'package:smartmove/core/models/product.dart';
import 'package:smartmove/core/services/location_service.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/products/presentation/products_screen.dart';
import 'package:smartmove/features/decision_lab/presentation/decision_lab_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Basket Aggregation & Deduplication Tests', () {
    test('Adding same product twice increments quantity to 2 instead of duplicate item', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(decisionLabProvider.notifier);

      // Add product item first time
      final item1 = ShoppingItem(
        id: 'item-rice-1',
        productId: 'prod-rice-01',
        productName: 'Mama Gold Rice',
        quantity: 1,
        unit: '50kg bag',
        estimatedUnitPrice: 85000,
        priority: CommodityPriority.essential,
      );
      notifier.addShoppingItem(item1);

      var state = container.read(decisionLabProvider);
      expect(state.activeItems.length, 1);
      expect(state.activeItems.first.quantity, 1.0);
      expect(state.activeItems.first.productName, 'Mama Gold Rice');

      // Add same product second time with different generated item ID
      final item2 = ShoppingItem(
        id: 'item-rice-2',
        productId: 'prod-rice-01',
        productName: 'Mama Gold Rice',
        quantity: 1,
        unit: '50kg bag',
        estimatedUnitPrice: 85000,
        priority: CommodityPriority.essential,
      );
      notifier.addShoppingItem(item2);

      state = container.read(decisionLabProvider);
      // Must NOT create a second item in the list
      expect(state.activeItems.length, 1, reason: 'Duplicate item should not be created');
      // Quantity must be aggregated to 2
      expect(state.activeItems.first.quantity, 2.0, reason: 'Quantity should increment to 2');

      // Add third time with matched name (case-insensitive) but null productId
      final item3 = ShoppingItem(
        id: 'item-rice-3',
        productId: null,
        productName: 'mama gold rice',
        quantity: 1,
        unit: '50kg bag',
        estimatedUnitPrice: 85000,
        priority: CommodityPriority.essential,
      );
      notifier.addShoppingItem(item3);

      state = container.read(decisionLabProvider);
      expect(state.activeItems.length, 1);
      expect(state.activeItems.first.quantity, 3.0);
    });
  });

  group('2. Direct Basket Addition without Opening Product Detail Sheet', () {
    testWidgets('ProductsScreen provides direct Add to Basket button on card', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Populate test product
      container.read(productsProvider.notifier).addProduct(
            const Product(
              id: 'prod-yam-direct',
              name: 'Abakaliki Yam',
              category: 'Food',
              lowestPrice: 2500,
              standardUnit: 'tuber',
              bestSeller: 'Bodija Market',
              distanceKm: 0.0,
              updateTime: 'Recently',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProductsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify product card is displayed
      expect(find.text('Abakaliki Yam'), findsOneWidget);

      // Verify direct "Add to Basket" button is present directly on the card
      final directAddBtn = find.byKey(const ValueKey('btn_quick_add_prod-yam-direct'));
      expect(directAddBtn, findsOneWidget);

      // Tap direct Add to Basket button
      await tester.tap(directAddBtn);
      await tester.pumpAndSettle();

      // Verify item was added to the basket in decisionLabProvider without opening detail sheet
      final basketItems = container.read(decisionLabProvider).activeItems;
      expect(basketItems.length, 1);
      expect(basketItems.first.productName, 'Abakaliki Yam');
      expect(basketItems.first.quantity, 1.0);

      // Tap direct Add to Basket button a second time
      await tester.tap(directAddBtn);
      await tester.pumpAndSettle();

      // Verify quantity is incremented to 2 in the basket
      final updatedBasket = container.read(decisionLabProvider).activeItems;
      expect(updatedBasket.length, 1);
      expect(updatedBasket.first.quantity, 2.0);
    });
  });

  group('3. Dynamic Distance Resolution (Zero Hardcoded 1.5km Fallbacks)', () {
    test('LocationService dynamically resolves distance from user GPS and market coordinates', () {
      // User in Bodija area: lat 7.4350, lon 3.9100
      final userLocation = const GeoPoint(
        latitude: 7.4350,
        longitude: 3.9100,
        label: 'Bodija, Ibadan',
        city: 'Ibadan',
      );

      // Bodija Market coordinates in registry: 7.4340, 3.9080
      final distanceBodija = LocationService.resolveDistanceKm(
        userLocation: userLocation,
        destLocationName: 'Bodija Market',
      );
      expect(distanceBodija > 0.0 && distanceBodija < 1.0, isTrue);
      expect(distanceBodija, isNot(equals(1.5)));

      // Dugbe Market in Ibadan: ~6.2 km away
      final distanceDugbe = LocationService.resolveDistanceKm(
        userLocation: userLocation,
        destLocationName: 'Dugbe Market',
      );
      expect(distanceDugbe > 4.0 && distanceDugbe < 8.0, isTrue);
      expect(distanceDugbe, isNot(equals(1.5)));

      // Uncalibrated / unknown destination without GPS returns 0.0, NEVER 1.5
      final unknownDist = LocationService.resolveDistanceKm(
        userLocation: null,
        destLocationName: 'Unknown Market Place',
      );
      expect(unknownDist, 0.0);
    });

    test('Product and PriceObservation models default distance to 0.0 when uncalibrated', () {
      final product = Product.fromJson({
        'id': 'test-p1',
        'name': 'Palm Oil',
        'category': 'Food',
        'lowestPrice': 1500,
        'standardUnit': 'litre',
        'bestSeller': 'Local Trader',
      });
      expect(product.distanceKm, 0.0);
    });
  });

  group('4. Acquisition Process Complete Removal', () {
    testWidgets('DecisionLabScreen renders Verified Sellers & Outlets without acquisition process', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seed an item in the shopping list
      container.read(decisionLabProvider.notifier).addShoppingItem(
            ShoppingItem(
              id: 'item-1',
              productName: 'Cement (Dangote 50kg)',
              quantity: 10,
              unit: 'bag',
              estimatedUnitPrice: 7500,
              priority: CommodityPriority.essential,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DecisionLabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Acquisition Process" and "Proceed to Acquisition" must NEVER be shown
      expect(find.textContaining(RegExp('acquisition process', caseSensitive: false)), findsNothing);
      expect(find.textContaining(RegExp('Proceed to Acquisition', caseSensitive: false)), findsNothing);
      expect(find.textContaining(RegExp('Launch Acquisition', caseSensitive: false)), findsNothing);

      // Verified Sellers section is present
      expect(find.textContaining('Verified Sellers & Outlets'), findsOneWidget);
    });
  });

  group('5. AI Vision Multimodal Product Picture Recognition & Error Reporting', () {
    test('parsePaperNoteImage heuristic recognizes product photo names from image filename', () async {
      final aiService = MetaAiService();
      final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

      // When user uploads a photo named e.g. "toyota_camry_2015.jpg" or "generator_sumec_firman.png"
      final result = await aiService.parsePaperNoteImage(
        imageBytes: dummyBytes,
        imageName: 'toyota_camry_2015.jpg',
      );

      // Should identify candidate product name
      expect(result.detectedProductName, isNotNull);
      expect(result.detectedProductName, contains('Toyota Camry 2015'));
      expect(result.isProductPhoto, isTrue);
    });

    test('parsePaperNoteImage reports transparent error diagnostic when AI endpoint is not connected', () async {
      final aiService = MetaAiService();
      final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

      final result = await aiService.parsePaperNoteImage(
        imageBytes: dummyBytes,
        imageName: 'electric_cooker_hotplate.jpg',
      );

      // Must report error transparently rather than failing silently
      expect(result.hasError, isTrue);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage!.contains('currently unavailable'), isTrue);
      expect(result.detectedProductName, contains('Electric Cooker Hotplate'));
    });
  });
}

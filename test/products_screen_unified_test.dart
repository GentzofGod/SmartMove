import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/models/product.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/navigation/presentation/main_scaffold.dart';
import 'package:smartmove/features/products/presentation/products_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unified ProductsScreen & Zero-Duplication Catalog Tests', () {
    testWidgets('1. MainScaffold renders exactly 3 bottom navigation items: Home, Products, Price Lab', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MainScaffold(
              child: SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navBar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.items.length, equals(3));
      expect(navBar.items[0].label, equals('Home'));
      expect(navBar.items[1].label, equals('Products'));
      expect(navBar.items[2].label, equals('Price Lab'));
    });

    testWidgets('2. ProductsScreen deduplicates multiple observations for same commodity into 1 master card', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add a base product "White Garri"
      container.read(productsProvider.notifier).addProduct(
            const Product(
              id: 'prod-garri',
              name: 'White Garri',
              category: 'Food',
              lowestPrice: 1200,
              standardUnit: 'paint rubber',
              bestSeller: 'Bodija Market',
              distanceKm: 1.2,
              updateTime: 'Recently',
            ),
          );

      // Add 2 distinct seller observations for "White Garri"
      container.read(communityProvider.notifier).addObservation(
            productName: 'White Garri',
            sellerName: 'Alhaja Kudirat Stalls',
            marketLocation: 'Bodija Market',
            price: 1100,
            unit: 'paint rubber',
            submitterName: 'Alhaja Kudirat',
            submitterRole: 'Trader',
            category: 'Food',
          );

      container.read(communityProvider.notifier).addObservation(
            productName: 'White Garri',
            sellerName: 'Mama Nkechi Provisions',
            marketLocation: 'Mile 12 Market',
            price: 1350,
            unit: 'paint rubber',
            submitterName: 'Mama Nkechi',
            submitterRole: 'Trader',
            category: 'Food',
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

      // Exactly ONE master card for 'White Garri' should be rendered in the feed
      expect(find.text('White Garri'), findsOneWidget);

      // Computed price spread reflects min (1100) and max (1350)
      expect(find.textContaining('₦1100'), findsOneWidget);
      expect(find.textContaining('Verified Stall(s)'), findsOneWidget);

      // Category filter chips are present
      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Food'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Electronics'), findsOneWidget);

      // Meta AI research banner is present
      expect(find.text('Meta AI Commodity Price Research'), findsOneWidget);

      // Report Price Floating Action Button is present
      expect(find.byKey(const ValueKey('btn_add_product_observation')), findsOneWidget);
      expect(find.text('Report Price'), findsOneWidget);
    });

    testWidgets('3. Tapping + Report Price opens observation bottom sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 932));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'buyer-001',
              email: 'buyer@example.com',
              displayName: 'Ayodele Shopper',
              isGuest: false,
              role: 'Customer',
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

      // Tap the FAB
      await tester.tap(find.byKey(const ValueKey('btn_add_product_observation')));
      await tester.pumpAndSettle();

      // Verify observation submission modal sheet opens
      expect(find.text('Report Market Price Observation'), findsOneWidget);
      expect(find.text('Submit Observation'), findsOneWidget);
    });

    testWidgets('4. Source filtering filters between Verified Sellers and Community Quotes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 932));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Product with verified seller
      container.read(communityProvider.notifier).addObservation(
            productName: 'Organic Honey 1L',
            sellerName: 'Beehive Apex',
            marketLocation: 'Oje Market',
            price: 5000,
            unit: 'bottle',
            submitterName: 'Beehive Apex',
            submitterRole: 'Trader',
            category: 'Food',
          );

      // Product from community crowd report
      container.read(communityProvider.notifier).addObservation(
            productName: 'Digital Multimeter DT9205A',
            sellerName: 'Electronics Alley',
            marketLocation: 'Dugbe',
            price: 18000,
            unit: 'unit',
            submitterName: 'Tunde Shopper',
            submitterRole: 'Customer',
            category: 'Electronics',
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

      expect(find.text('Organic Honey 1L'), findsOneWidget);
      expect(find.text('Digital Multimeter DT9205A'), findsOneWidget);

      // Tap 'Verified Sellers' filter
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Verified Sellers'));
      await tester.tap(find.widgetWithText(FilterChip, 'Verified Sellers'));
      await tester.pumpAndSettle();

      // Only verified seller product is shown
      expect(find.text('Organic Honey 1L'), findsOneWidget);
      expect(find.text('Digital Multimeter DT9205A'), findsNothing);

      // Tap 'Community Quotes' filter
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Community Quotes'));
      await tester.tap(find.widgetWithText(FilterChip, 'Community Quotes'));
      await tester.pumpAndSettle();

      // Only crowd-sourced product is shown
      expect(find.text('Digital Multimeter DT9205A'), findsOneWidget);
      expect(find.text('Organic Honey 1L'), findsNothing);
    });
  });
}

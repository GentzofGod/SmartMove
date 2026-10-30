import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/data/demo_seed_data.dart';
import 'package:smartmove/core/models/product.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/home/presentation/home_screen.dart';
import 'package:smartmove/features/discover/presentation/discover_screen.dart';
import 'package:smartmove/features/community/presentation/community_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Foodstuffs Mock Data Removal & Empty States Tests', () {
    test('1. DemoSeedData getProducts and getCommunityObservations return empty lists', () {
      final products = DemoSeedData.getProducts();
      final observations = DemoSeedData.getCommunityObservations();

      expect(products, isEmpty);
      expect(observations, isEmpty);

      // Benchmarks remain accessible for deterministic algorithm tests
      final benchmarks = DemoSeedData.getBenchmarkFoodstuffs();
      final benchmarkObservations = DemoSeedData.getBenchmarkFoodstuffObservations();
      expect(benchmarks, isNotEmpty);
      expect(benchmarkObservations, isNotEmpty);
    });

    test('2. ProductsNotifier & CommunityNotifier initialize empty for live Supabase sync', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final products = container.read(productsProvider);
      final observations = container.read(communityProvider);

      expect(products, isEmpty);
      expect(observations, isEmpty);
    });

    testWidgets('3. HomeScreen shows polished empty state when no products exist', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state header and description should be present
      expect(find.text('No Live Commodity Quotes Yet'), findsOneWidget);
      expect(
        find.text('Prices will appear here as verified traders and shoppers upload real market data.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

      // Add a live product to the notifier
      container.read(productsProvider.notifier).addProduct(
            const Product(
              id: 'p-live-test-1',
              name: 'Live Market Garri',
              category: 'Grains & Flours',
              standardUnit: '1kg',
              lowestPrice: 1200,
              bestSeller: 'Bodija Central Hub',
              distanceKm: 0.9,
              updateTime: 'Just now',
            ),
          );
      await tester.pumpAndSettle();

      // Empty state disappears, product card appears
      expect(find.text('No Live Commodity Quotes Yet'), findsNothing);
      expect(find.text('Live Market Garri'), findsOneWidget);
      expect(find.text('₦1,200 • Bodija Central Hub'), findsOneWidget);
    });

    testWidgets('4. DiscoverScreen displays clean empty state when products catalog is empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiscoverScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Commodity Listings Yet'), findsOneWidget);
      expect(
        find.text('Active commodity prices will appear here once published by verified market traders and stores.'),
        findsOneWidget,
      );

      // Add a product to the catalog
      container.read(productsProvider.notifier).addProduct(
            const Product(
              id: 'p-live-test-2',
              name: 'Yam Tubers',
              category: 'Fresh Produce',
              standardUnit: 'Tuber',
              lowestPrice: 2500,
              bestSeller: 'Oja Oba Market',
              distanceKm: 1.8,
              updateTime: '5m ago',
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text('No Commodity Listings Yet'), findsNothing);
      expect(find.text('Yam Tubers'), findsOneWidget);
    });

    testWidgets('5. CommunityScreen displays clean empty state when observations are empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CommunityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Community Price Quotes Yet'), findsOneWidget);
      expect(
        find.text('No observations have been reported yet for this filter. Tap the + button to contribute verified market prices.'),
        findsOneWidget,
      );

      // Add a community observation
      container.read(communityProvider.notifier).addObservation(
            productName: 'Yam Tubers',
            sellerName: 'Oja Oba Stall 4',
            marketLocation: 'Oja Oba Market',
            price: 2500,
            unit: 'tuber',
            submitterName: 'Ayo',
            submitterRole: 'Customer',
          );
      await tester.pumpAndSettle();

      expect(find.text('No Community Price Quotes Yet'), findsNothing);
      expect(find.text('Yam Tubers'), findsWidgets);
      expect(find.textContaining('Oja Oba Stall 4'), findsWidgets);
    });

    test('6. DemoSeedData getInitialErrands and getInitialStops return empty lists', () {
      final errands = DemoSeedData.getInitialErrands();
      final stops = DemoSeedData.getInitialStops();

      expect(errands, isEmpty);
      expect(stops, isEmpty);

      // Benchmarks remain accessible for calculations
      final benchmarkErrands = DemoSeedData.getBenchmarkErrands();
      final benchmarkStops = DemoSeedData.getBenchmarkStops();
      expect(benchmarkErrands, isNotEmpty);
      expect(benchmarkStops, isNotEmpty);
    });

    testWidgets('7. HomeScreen does not show hardcoded 15000 budget, remaining, or mock commodity basket', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure hardcoded "I have ₦15,000..." is NOT on the screen
      expect(find.textContaining('I have ₦15,000. I need rice'), findsNothing);
      expect(find.text('1-Tap Plan'), findsNothing);

      // Ensure hardcoded "Budget: ₦15,000" and "Remaining" metrics are NOT shown when no basket is active
      expect(find.text('₦15,000'), findsNothing);
      expect(find.text('Remaining'), findsNothing);
      expect(find.text('Weekly Basket'), findsNothing);
      expect(find.text('Breakfast List'), findsNothing);

      // Ensure clean prompt box comes first in Meta AI Assistant card
      expect(find.text('Meta AI Assistant'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Voice Note'), findsOneWidget);
      expect(find.text('Scan Note'), findsOneWidget);
      expect(find.text('Custom Prompt'), findsOneWidget);
    });
  });
}

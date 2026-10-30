import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/models/product.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/discover/presentation/product_detail_sheet.dart';

class _MockCommunityNotifier extends CommunityNotifier {
  final List<PriceObservation> _observations;
  _MockCommunityNotifier(this._observations);

  @override
  List<PriceObservation> build() => _observations;
}

void main() {
  const testProduct = Product(
    id: 'p-rice',
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

  final multiChannelQuotes = [
    PriceObservation(
      id: 'obs-smb-1',
      productId: 'p-rice',
      productName: 'Rice (50kg Bag)',
      sellerName: 'Bodija SMB Grocer',
      marketLocation: 'Bodija SMB Grocer',
      price: 89000,
      unit: '50kg',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      sourceType: ObservationSource.communityReported,
      submitterName: 'Local Shopper',
      submitterRole: 'Customer',
      isVerified: true,
      channel: 'SMB Store',
      brandOrGrade: 'Packaged Shelf Standard',
      standardizedUnitPrice: 1780.0,
      baseUnit: 'kg',
      inStock: true,
    ),
    PriceObservation(
      id: 'obs-online-1',
      productId: 'p-rice',
      productName: 'Rice (50kg Bag)',
      sellerName: 'Jumia Food Mart',
      marketLocation: 'Online Retail Platform',
      price: 94000,
      unit: '50kg',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      sourceType: ObservationSource.onlineGrounded,
      submitterName: 'Web Grounding Engine',
      submitterRole: 'System',
      isVerified: true,
      channel: 'Online Retailer',
      brandOrGrade: 'Premium Express Delivery Grade',
      standardizedUnitPrice: 1880.0,
      baseUnit: 'kg',
      inStock: true,
    ),
  ];

  testWidgets('ProductDetailSheet renders multi-seller comparison and standardized unit prices', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityProvider.overrideWith(() => _MockCommunityNotifier(multiChannelQuotes)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProductDetailSheet(product: testProduct),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify product name and standard unit
    expect(find.text('Rice (50kg Bag)'), findsOneWidget);
    expect(find.textContaining('Standard Unit: 50kg'), findsOneWidget);

    // Verify best price banner
    expect(find.text('Best Price'), findsOneWidget);
    expect(find.text('₦82,000'), findsWidgets);

    // Verify multi-seller comparison section header
    expect(find.text('Multi-Seller Comparison'), findsOneWidget);

    // Verify channel badges exist (Local Market, SMB Store, Online Retailer)
    expect(find.text('Local Market'), findsWidgets);
    expect(find.text('SMB Store'), findsWidgets);
    expect(find.text('Online Retailer'), findsWidgets);

    // Verify Add to Comparison Basket button
    expect(find.textContaining('Add to Comparison Basket'), findsOneWidget);
  });

  testWidgets('Quantity adjustments recalculate estimated basket outlay', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProductDetailSheet(product: testProduct),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initial quantity is 1 -> ₦82,000
    expect(find.text('₦82,000'), findsWidgets);

    // Tap '+' to increase quantity to 2
    final addIcon = find.byIcon(Icons.add_circle_outline);
    expect(addIcon, findsOneWidget);
    await tester.tap(addIcon);
    await tester.pumpAndSettle();

    // Now quantity is 2 50kg -> Outlay is ₦164,000
    expect(find.text('2 50kg'), findsWidgets);
    expect(find.text('₦164,000'), findsWidgets);
  });

  testWidgets('Only genuine product listing is shown when community observations are empty (no synthetic fallbacks)', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProductDetailSheet(product: testProduct),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify exactly 1 genuine quote is displayed
    expect(find.text('1 quotes'), findsOneWidget);

    // Verify fake benchmark stores are NOT present
    expect(find.text('Foodco Supermarket'), findsNothing);
    expect(find.text('Jumia Food Mart'), findsNothing);

    // Verify price history is cleanly hidden when fewer than 3 historical points exist
    expect(
      find.text('Price history hidden: requires at least 3 confirmed observations across time.'),
      findsOneWidget,
    );
  });

  testWidgets('Price history trend is displayed when 3 or more verified observations exist across time', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final historicalQuotes = [
      PriceObservation(
        id: 'hist-1',
        productId: 'p-rice',
        productName: 'Rice (50kg Bag)',
        sellerName: 'Bodija Market Hub',
        marketLocation: 'Bodija Market Hub',
        price: 80000,
        unit: '50kg',
        timestamp: now.subtract(const Duration(days: 14)),
        sourceType: ObservationSource.independentlyVerified,
        submitterName: 'Admin Surveyor',
        submitterRole: 'Admin',
        isVerified: true,
      ),
      PriceObservation(
        id: 'hist-2',
        productId: 'p-rice',
        productName: 'Rice (50kg Bag)',
        sellerName: 'Bodija Market Hub',
        marketLocation: 'Bodija Market Hub',
        price: 81000,
        unit: '50kg',
        timestamp: now.subtract(const Duration(days: 7)),
        sourceType: ObservationSource.independentlyVerified,
        submitterName: 'Admin Surveyor',
        submitterRole: 'Admin',
        isVerified: true,
      ),
      PriceObservation(
        id: 'hist-3',
        productId: 'p-rice',
        productName: 'Rice (50kg Bag)',
        sellerName: 'Bodija Market Hub',
        marketLocation: 'Bodija Market Hub',
        price: 82000,
        unit: '50kg',
        timestamp: now.subtract(const Duration(days: 1)),
        sourceType: ObservationSource.independentlyVerified,
        submitterName: 'Admin Surveyor',
        submitterRole: 'Admin',
        isVerified: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityProvider.overrideWith(() => _MockCommunityNotifier(historicalQuotes)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProductDetailSheet(product: testProduct),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify price history trend is visible
    expect(find.text('Price History Trend'), findsOneWidget);
    expect(find.text('Based on verified reports'), findsOneWidget);
    expect(
      find.text('Price history hidden: requires at least 3 confirmed observations across time.'),
      findsNothing,
    );
  });
}

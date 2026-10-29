import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/models/product.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/features/discover/presentation/product_detail_sheet.dart';

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

  testWidgets('ProductDetailSheet renders multi-seller comparison and standardized unit prices', (tester) async {
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
}

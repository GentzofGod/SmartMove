import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/models/ai_proposal.dart';
import 'package:smartmove/core/models/commodity_item.dart';
import 'package:smartmove/core/services/web_search_grounding_service.dart';
import 'package:smartmove/features/home/presentation/widgets/ai_proposal_review_sheet.dart';

void main() {
  final sampleItem = ShoppingItem(
    id: 'item-1',
    productName: 'Electric Cooker 2-Burner',
    quantity: 1,
    unit: 'unit',
    estimatedUnitPrice: 42000,
    matchedVendorName: 'Jumia Official Store',
    availableSourceQuotes: const [
      LiveWebVendorResult(
        vendorName: 'Jiji Nigeria Marketplace',
        title: 'Cooker on Jiji',
        snippet: 'Direct vendor pricing',
        targetUrl: 'https://jiji.ng/search?query=Electric+Cooker',
        detectedPrice: 39000,
        priceDisplay: '₦39,000',
        channel: 'Wholesale & Direct Classifieds',
        badge: 'Best Bargain Price',
      ),
      LiveWebVendorResult(
        vendorName: 'Lagos Commercial Outlets',
        title: 'Local Stores',
        snippet: 'Walk-in market price',
        targetUrl: 'https://google.com/maps/search/cooker',
        detectedPrice: 41000,
        priceDisplay: '₦41,000',
        channel: 'Physical Store Hubs',
        badge: 'Immediate Walk-In',
      ),
      LiveWebVendorResult(
        vendorName: 'Jumia Official Store',
        title: 'Cooker on Jumia',
        snippet: 'Manufacturer warranty',
        targetUrl: 'https://jumia.com.ng/catalog/?q=Electric+Cooker',
        detectedPrice: 42000,
        priceDisplay: '₦42,000',
        channel: 'Online Retailer',
        badge: 'Manufacturer Warranty',
      ),
      LiveWebVendorResult(
        vendorName: 'Konga Online Shopping',
        title: 'Cooker on Konga',
        snippet: 'Marketplace delivery',
        targetUrl: 'https://konga.com/search?search=Electric+Cooker',
        detectedPrice: 44000,
        priceDisplay: '₦44,000',
        channel: 'Ecommerce Marketplace',
        badge: 'Fast Delivery',
      ),
    ],
  );

  final sampleProposal = AiPlanProposal(
    budget: 50000,
    shoppingItems: [sampleItem],
    rawInput: 'I need an electric cooker for ₦50,000',
    modelName: 'Meta Muse Spark 1.3',
    isFallback: false,
    executionStatus: 'Meta AI Grounded',
    liveWebVendors: sampleItem.availableSourceQuotes,
  );

  testWidgets('AiProposalReviewSheet renders clean, compact layout without overflow on 360x640 mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiProposalReviewSheet(
            proposal: sampleProposal,
            onConfirm: (_, _, _) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and compact badge
    expect(find.text('AI Sourcing Proposal'), findsOneWidget);
    expect(find.text('✓ Multi-Source Grounded'), findsOneWidget);

    // Verify item title and no overflow
    expect(find.text('Electric Cooker 2-Burner'), findsOneWidget);
    expect(find.text('₦42,000'), findsWidgets);
    expect(find.text('Prices Offered Across Sources:'), findsOneWidget);

    // Verify all source chips are rendered
    expect(find.text('Jiji: ₦39,000'), findsOneWidget);
    expect(find.text('Lagos: ₦41,000'), findsOneWidget);
    expect(find.text('Jumia: ₦42,000'), findsOneWidget);
    expect(find.text('Konga: ₦44,000'), findsOneWidget);
  });

  testWidgets('Tapping a source chip immediately updates the item unit price and total outlay', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    double? confirmedBudget;
    List<ShoppingItem>? confirmedItems;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiProposalReviewSheet(
            proposal: sampleProposal,
            onConfirm: (b, items, _) {
              confirmedBudget = b;
              confirmedItems = items;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initial total is ₦42,000
    expect(find.text('Total: '), findsOneWidget);
    expect(find.text('₦42,000'), findsWidgets);

    // Tap Jiji chip (₦39,000)
    final jijiChip = find.text('Jiji: ₦39,000');
    expect(jijiChip, findsOneWidget);
    await tester.tap(jijiChip);
    await tester.pumpAndSettle();

    // Now price and total are updated to ₦39,000
    expect(find.text('₦39,000'), findsWidgets);
    expect(find.text('Subtotal: ₦39,000'), findsOneWidget);

    // Tap confirm button
    final confirmBtn = find.text('Confirm & Calculate Options');
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(confirmedBudget, equals(50000));
    expect(confirmedItems, isNotNull);
    expect(confirmedItems!.first.estimatedUnitPrice, equals(39000));
    expect(confirmedItems!.first.matchedVendorName, equals('Jiji Nigeria Marketplace'));
  });

  testWidgets('Quantity stepper updates item quantity and subtotal smoothly', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiProposalReviewSheet(
            proposal: sampleProposal,
            onConfirm: (_, _, _) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initial quantity is 1 unit
    expect(find.text('1 unit'), findsOneWidget);
    expect(find.text('Subtotal: ₦42,000'), findsOneWidget);

    // Tap '+' icon button on stepper
    final addIcon = find.byKey(const Key('stepper-add-btn'));
    expect(addIcon, findsOneWidget);
    await tester.tap(addIcon);
    await tester.pumpAndSettle();

    // Now quantity is 2 unit, subtotal is ₦84,000
    expect(find.text('2 unit'), findsOneWidget);
    expect(find.text('Subtotal: ₦84,000'), findsOneWidget);
  });
}

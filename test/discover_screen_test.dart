import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/features/discover/presentation/discover_screen.dart';

void main() {
  testWidgets('DiscoverScreen defaults to All category and provides All filter chip', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DiscoverScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify 'All' category filter chip is visible
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);
    expect(find.text('Pharmacy'), findsOneWidget);

    // Verify Meta AI Commodity Price Research chip is rendered
    expect(find.text('Meta AI Commodity Price Research'), findsOneWidget);
  });

  testWidgets('Tapping Meta AI research chip with empty search opens research prompt dialog (no hardcoded rice)', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DiscoverScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Meta AI research chip
    await tester.tap(find.text('Meta AI Commodity Price Research'));
    await tester.pumpAndSettle();

    // Verify the commodity prompt dialog opens
    expect(find.text('Meta AI Price Research'), findsOneWidget);
    expect(
      find.text('Enter a commodity or product to research current prices across open markets, neighborhood stores, and online platforms.'),
      findsOneWidget,
    );
    expect(find.text('Research Prices'), findsOneWidget);

    // Enter a custom commodity name (e.g. Beans)
    await tester.enterText(find.byType(TextField).last, 'Beans');
    await tester.pumpAndSettle();

    // Tap Research Prices
    await tester.tap(find.text('Research Prices'));
    await tester.pumpAndSettle();

    // Verify Meta AI research sheet opens with researched commodity
    expect(find.textContaining('Meta AI Price Research: Beans'), findsOneWidget);
    expect(find.text('Estimated Benchmark Range:'), findsOneWidget);
  });

  testWidgets('Meta AI research chip dynamically adapts to search bar input', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DiscoverScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Enter search query in search bar
    await tester.enterText(find.byType(TextField).first, 'Palm Oil');
    await tester.pumpAndSettle();

    // Verify chip updates to reflect the active search query
    expect(find.text('Research "Palm Oil" with Meta AI'), findsOneWidget);

    // Tap the chip directly
    await tester.tap(find.text('Research "Palm Oil" with Meta AI'));
    await tester.pumpAndSettle();

    // Verify AI Price Research sheet opens directly for Palm Oil
    expect(find.textContaining('Meta AI Price Research: Palm Oil'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('Recent Market Observations displays product names clearly without squishing beside price', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(communityProvider.notifier).addObservation(
      productName: 'Mama Gold Long Grain Parboiled Rice 50kg Heavy Sack',
      sellerName: 'Alhaja Kudirat Foodstuffs',
      price: 88500,
      unit: '50kg bag',
      submitterName: 'Trader Kudirat',
      submitterRole: 'Trader',
      marketLocation: 'Bodija Market Hub, Ibadan',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the long product name widget exists and has maxLines: 2
    final nameFinder = find.text('Mama Gold Long Grain Parboiled Rice 50kg Heavy Sack');
    expect(nameFinder, findsOneWidget);

    final textWidget = tester.widget<Text>(nameFinder);
    expect(textWidget.maxLines, 2);
    expect(textWidget.overflow, TextOverflow.ellipsis);
    expect(textWidget.style?.fontWeight, FontWeight.w700);

    // Verify price is displayed on its own line below the product name
    expect(find.text('₦88,500'), findsOneWidget);
    expect(find.text('/ 50kg bag'), findsOneWidget);

    // Verify action buttons exist in card
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
  });
}

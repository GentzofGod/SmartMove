import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/core/presentation/widgets/seller_catalog_sheet.dart';
import 'package:smartmove/features/messages/presentation/chat_thread_screen.dart';
import 'package:smartmove/features/messages/presentation/message_box_screen.dart';
import 'package:smartmove/features/decision_lab/presentation/widgets/trader_negotiation_sheet.dart';
import 'package:smartmove/core/models/item_acquisition_source.dart';

class FakeAuthNotifier extends AuthNotifier {
  final UserSession initialSession;
  FakeAuthNotifier(this.initialSession);

  @override
  UserSession build() => initialSession;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testObservationCamry = PriceObservation(
    id: 'obs-camry-1',
    productId: 'prod-camry',
    productName: 'Toyota Camry 2012',
    category: 'Vehicles & Auto Spares',
    price: 9988600,
    unit: 'vehicle',
    marketLocation: 'Kuto Market, Abeokuta',
    sellerName: 'Adebayo Motors',
    isVerified: true,
    inStock: true,
    brandOrGrade: 'Tokunbo Clean',
    notes: 'V6 Engine, custom leather interior',
    timestamp: DateTime(2026, 11, 1),
    sourceType: ObservationSource.traderProvided,
    submitterName: 'Chief Adebayo',
  );

  final testObservationOil = PriceObservation(
    id: 'obs-oil-1',
    productId: 'prod-oil',
    productName: 'Mobil 1 Engine Oil',
    category: 'Vehicles & Auto Spares',
    price: 18500,
    unit: 'piece / unit',
    marketLocation: 'Kuto Market, Abeokuta',
    sellerName: 'Adebayo Motors',
    isVerified: true,
    inStock: true,
    brandOrGrade: '5W-30 Full Synthetic',
    notes: 'Original sealed 4L gallon',
    timestamp: DateTime(2026, 11, 2),
    sourceType: ObservationSource.traderProvided,
    submitterName: 'Chief Adebayo',
  );

  final testSellerApp = SellerApplication(
    id: 'app-adebayo-1',
    userId: 'usr-adebayo-1',
    applicantName: 'Chief Adebayo',
    applicantEmail: 'adebayo@motors.ng',
    businessName: 'Adebayo Motors',
    marketHub: 'Kuto Market, Abeokuta',
    sellerChannel: 'Physical Store / Shop',
    stallLocation: 'Stall B-12',
    phone: '08033334444',
    status: SellerApplicationStatus.approved,
    submittedAt: DateTime(2026, 10, 1),
    reviewedAt: DateTime(2026, 10, 2),
  );

  group('Product-Based Chat & Inquiry Specification Tests', () {
    testWidgets('1. ChatThreadScreen prominently displays Product Inquiry banner with price and unit', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(
              const UserSession(
                id: 'usr-buyer-1',
                email: 'buyer@test.com',
                displayName: 'Kolawole Buyer',
                isGuest: false,
                role: 'Customer',
              ),
            ),
          ),
          communityProvider.overrideWith(() => CommunityNotifier()),
        ],
      );
      addTearDown(container.dispose);

      // Customer sends message for Toyota Camry
      await container.read(traderChatProvider.notifier).sendCustomerMessage(
            traderName: 'Adebayo Motors',
            commodityName: 'Toyota Camry 2012',
            quantity: 1,
            unit: 'vehicle',
            listedPrice: 9988600,
            messageText: 'Is this vehicle still available for physical inspection?',
            outletLocation: 'Kuto Market, Abeokuta',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatThreadScreen(
              conversationKey: 'Adebayo Motors',
              initialCommodityName: 'Toyota Camry 2012',
              initialPrice: 9988600,
              initialUnit: 'vehicle',
              outletLocation: 'Kuto Market, Abeokuta',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify product-centric header & banner
      expect(find.text('Adebayo Motors'), findsOneWidget);
      expect(find.text('Negotiating: Toyota Camry 2012'), findsOneWidget);
      expect(find.text('Listed: ₦9988600 / vehicle'), findsOneWidget);
      expect(find.text('Is this vehicle still available for physical inspection?'), findsOneWidget);

      // Verify individual message bubble has explicit product inquiry tag
      expect(find.text('Inquiry: Toyota Camry 2012 • ₦9988600/vehicle'), findsOneWidget);
    });

    testWidgets('2. MessageBoxScreen highlights the Product Inquiry card on conversation cards', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(
              const UserSession(
                id: 'usr-buyer-1',
                email: 'buyer@test.com',
                displayName: 'Kolawole Buyer',
                isGuest: false,
                role: 'Customer',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(traderChatProvider.notifier).sendCustomerMessage(
            traderName: 'Adebayo Motors',
            commodityName: 'Toyota Camry 2012',
            quantity: 1,
            unit: 'vehicle',
            listedPrice: 9988600,
            messageText: 'Can you hold this car for pickup today?',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MessageBoxScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product and partner should both be clearly rendered
      expect(find.text('Adebayo Motors'), findsOneWidget);
      expect(find.text('Toyota Camry 2012'), findsOneWidget);
      expect(find.text('Can you hold this car for pickup today?'), findsOneWidget);
      expect(find.text('₦9988600/vehicle'), findsOneWidget);
    });
  });

  group('Seller Catalog Feature & Ubiquitous Accessibility Tests', () {
    testWidgets('3. SellerCatalogSheet lists all products for a seller and highlights current inquiry', (tester) async {
      final container = ProviderContainer(
        overrides: [
          communityProvider.overrideWith(() => CommunityNotifier()),
          sellerApplicationsProvider.overrideWith(() => SellerApplicationsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      // Inject listings and seller app
      container.read(communityProvider.notifier).state = [
        testObservationCamry,
        testObservationOil,
      ];
      container.read(sellerApplicationsProvider.notifier).state = [
        testSellerApp,
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SellerCatalogSheet(
                sellerName: 'Adebayo Motors',
                currentCommodityName: 'Toyota Camry 2012',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Storefront Header
      expect(find.text('Adebayo Motors'), findsOneWidget);
      expect(find.text('Verified Seller'), findsOneWidget);
      expect(find.text('2 Products in Seller Catalog'), findsOneWidget);

      // Verify Products are both listed
      expect(find.text('Toyota Camry 2012'), findsOneWidget);
      expect(find.text('Mobil 1 Engine Oil'), findsOneWidget);
      expect(find.text('Current Chat'), findsOneWidget); // Highlight for current inquiry item
      expect(find.text('In Stock'), findsNWidgets(2));
    });

    testWidgets('4. SellerCatalogSheet allows searching within the seller catalog', (tester) async {
      final container = ProviderContainer(
        overrides: [
          communityProvider.overrideWith(() => CommunityNotifier()),
          sellerApplicationsProvider.overrideWith(() => SellerApplicationsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      container.read(communityProvider.notifier).state = [
        testObservationCamry,
        testObservationOil,
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SellerCatalogSheet(
                sellerName: 'Adebayo Motors',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Toyota Camry 2012'), findsOneWidget);
      expect(find.text('Mobil 1 Engine Oil'), findsOneWidget);

      // Search for "oil"
      await tester.enterText(find.byType(TextField), 'oil');
      await tester.pumpAndSettle();

      expect(find.text('Mobil 1 Engine Oil'), findsOneWidget);
      expect(find.text('Toyota Camry 2012'), findsNothing);
    });

    testWidgets('5. TraderNegotiationSheet contains Check Seller Catalog chip', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(
              const UserSession(
                id: 'usr-buyer-1',
                email: 'buyer@test.com',
                displayName: 'Kolawole Buyer',
                isGuest: false,
                role: 'Customer',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final source = ItemAcquisitionSource(
        id: 'src-adebayo',
        itemId: 'item-camry',
        commodityName: 'Toyota Camry 2012',
        quantity: 1,
        unit: 'vehicle',
        unitPrice: 9988600,
        totalCost: 9988600,
        outletName: 'Adebayo Motors',
        channel: AcquisitionChannel.registeredTrader,
        marketHubOrLocation: 'Kuto Market, Abeokuta',
        dynamicDistanceKm: 1.5,
        isPlatformRegisteredTrader: true,
        inStock: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TraderNegotiationSheet(source: source),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Check Seller Catalog'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    });
  });
}

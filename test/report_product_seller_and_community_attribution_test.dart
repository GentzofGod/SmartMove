import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/presentation/widgets/report_modal_sheet.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/community/presentation/community_screen.dart';

class FakeAuthNotifier extends AuthNotifier {
  final UserSession initialSession;
  FakeAuthNotifier(this.initialSession);

  @override
  UserSession build() => initialSession;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Report Product and/or Seller (Requirement 1)', () {
    testWidgets('1. ReportModalSheet supports Product Issue & Seller Issue toggles and flags listing to SuperAdmin queue', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Create a test observation
      final obs = PriceObservation(
        id: 'obs-report-test-1',
        productId: 'prod-yam',
        productName: 'Benue Medium Yam Tubers',
        sellerName: 'Mama Funke Yam Depot',
        marketLocation: 'Bodija Market',
        price: 3500,
        unit: 'tuber',
        timestamp: DateTime.now(),
        sourceType: ObservationSource.traderConfirmed,
        submitterName: 'Mama Funke',
        submitterRole: 'Trader',
        isVerified: true,
        channel: 'Local Market',
      );

      // Add to community state
      container.read(communityProvider.notifier).state = [obs];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ReportModalSheet.show(context, obs),
                  child: const Text('Open Report Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Report Sheet'));
      await tester.pumpAndSettle();

      // Verify Report sheet is shown with target tabs
      expect(find.text('Report Listing or Seller'), findsOneWidget);
      expect(find.text('Product Issue'), findsOneWidget);
      expect(find.text('Seller Issue'), findsOneWidget);

      // Verify default Product Issue presets are shown
      expect(find.text('Inaccurate or Fake Price (Misleading / Predatory)'), findsOneWidget);
      expect(find.text('Permanently Out of Stock / Phantom Listing'), findsOneWidget);

      // Switch to Seller Issue
      await tester.tap(find.text('Seller Issue'));
      await tester.pumpAndSettle();

      // Verify Seller Issue presets are shown
      expect(find.text('Refused to Honor Advertised / Listed Price'), findsOneWidget);
      expect(find.text('Fake or Non-Existent Stall / Physical Address'), findsOneWidget);
      expect(find.text('Rude, Abusive, or Unprofessional Trader Conduct'), findsOneWidget);

      // Select "Refused to Honor Advertised / Listed Price"
      await tester.tap(find.text('Refused to Honor Advertised / Listed Price'));
      await tester.pumpAndSettle();

      // Enter details
      final detailsField = find.byType(TextField);
      expect(detailsField, findsOneWidget);
      await tester.enterText(detailsField, 'Demanded ₦5,000 instead of listed ₦3,500');
      await tester.pumpAndSettle();

      // Submit report
      await tester.ensureVisible(find.text('Submit Report'));
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      // Verify listing is now flagged as anomaly with composite reason in communityProvider
      final updatedObsList = container.read(communityProvider);
      final reportedObs = updatedObsList.firstWhere((o) => o.id == 'obs-report-test-1');

      expect(reportedObs.isFlaggedAnomaly, isTrue);
      expect(reportedObs.anomalyReason, contains('Seller Issue'));
      expect(reportedObs.anomalyReason, contains('Refused to Honor Advertised / Listed Price'));
      expect(reportedObs.anomalyReason, contains('Demanded ₦5,000 instead of listed ₦3,500'));
    });

    testWidgets('2. CommunityScreen card shows Report button and renders Flagged for Moderation alert when reported', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final obs = PriceObservation(
        id: 'obs-flagged-demo',
        productId: 'prod-garri',
        productName: 'Ijebu White Garri',
        sellerName: 'Bodija Grain Stalls',
        marketLocation: 'Bodija Market',
        price: 1200,
        unit: 'paint rubber',
        timestamp: DateTime.now(),
        sourceType: ObservationSource.communityReported,
        submitterName: 'Tunde Shopper',
        submitterRole: 'Customer',
        isVerified: false,
        isFlaggedAnomaly: true,
        anomalyReason: '[Product Issue] Inaccurate or Fake Price (Reported by Shopper)',
        channel: 'Local Market',
      );

      container.read(communityProvider.notifier).state = [obs];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CommunityScreen(initialTab: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Reported" status button is present
      expect(find.byKey(const ValueKey('btn_report_obs_obs-flagged-demo')), findsOneWidget);
      expect(find.text('Reported'), findsOneWidget);

      // Verify Flagged for Moderation banner is displayed with the reason
      expect(find.textContaining('Flagged for Moderation: [Product Issue] Inaccurate or Fake Price'), findsOneWidget);
    });
  });

  group('Products Posted by General Community Bear Poster Name (Requirement 2)', () {
    testWidgets('3. CommunityScreen cards prominently display poster name for community posts and verified seller name for seller posts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final verifiedSellerObs = PriceObservation(
        id: 'obs-seller-card',
        productId: 'prod-oil',
        productName: 'Pure Groundnut Oil 5L',
        sellerName: 'Alhaja Kudirat Foods',
        marketLocation: 'Bodija Market Stall 22',
        price: 13500,
        unit: '5L',
        timestamp: DateTime.now(),
        sourceType: ObservationSource.traderConfirmed,
        submitterName: 'Alhaja Kudirat',
        submitterRole: 'Trader',
        isVerified: true,
        channel: 'Local Market',
      );

      final communityObs = PriceObservation(
        id: 'obs-community-card',
        productId: 'prod-rice',
        productName: 'Mama Gold Rice 10kg',
        sellerName: 'Dugbe Local Stores',
        marketLocation: 'Dugbe Commercial Hub',
        price: 16000,
        unit: '10kg',
        timestamp: DateTime.now(),
        sourceType: ObservationSource.communityReported,
        submitterName: 'Fatima Abubakar',
        submitterRole: 'Customer',
        isVerified: false,
        channel: 'Local Market',
      );

      container.read(communityProvider.notifier).state = [verifiedSellerObs, communityObs];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CommunityScreen(initialTab: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On Verified Sellers tab, displays "Verified Seller: Alhaja Kudirat Foods"
      expect(find.text('Verified Seller: Alhaja Kudirat Foods'), findsOneWidget);

      // Switch to Community Reports tab
      await tester.tap(find.byKey(const ValueKey('tab_community_reports')));
      await tester.pumpAndSettle();

      // On Community Reports tab, displays "Posted by: Fatima Abubakar"
      expect(find.text('Posted by: Fatima Abubakar'), findsOneWidget);
    });
  });

  group('Verified Seller Posting Restriction in Community (Requirement 3)', () {
    testWidgets('4. Verified seller tapping + is blocked from community posting and redirected to Seller Portal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      // Setup session as verified seller
      const sellerSession = UserSession(
        id: 'seller-user-123',
        email: 'seller@smartmove.ng',
        displayName: 'Iya Basira',
        role: 'Trader',
        sellerApplicationStatus: SellerApplicationStatus.approved,
        businessName: 'Iya Basira Store',
      );

      final approvedApp = SellerApplication(
        id: 'app-1',
        userId: 'seller-user-123',
        applicantName: 'Iya Basira',
        applicantEmail: 'seller@smartmove.ng',
        businessName: 'Iya Basira Store',
        phone: '08012345678',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        stallLocation: 'Stall B-14',
        status: SellerApplicationStatus.approved,
        submittedAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(sellerSession)),
        ],
      );
      container.read(sellerApplicationsProvider.notifier).state = [approvedApp];
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

      // Verified seller taps FAB (+) to post in community
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verified Seller Portal Notice dialog MUST appear
      expect(find.text('Verified Seller Portal Notice'), findsOneWidget);
      expect(
        find.text('Verified sellers cannot post listings through general community channels.'),
        findsOneWidget,
      );
      expect(find.text('Go to Seller Portal'), findsOneWidget);

      // Community submission modal should NOT be shown
      expect(find.text('Report Price Observation'), findsNothing);
    });

    testWidgets('5. General community shopper can open price report modal and submits with poster attribution', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      // Setup session as regular shopper (Customer, NOT trader)
      const shopperSession = UserSession(
        id: 'shopper-user-456',
        email: 'chidi@example.com',
        displayName: 'Chidi Okonkwo',
        role: 'Customer',
        sellerApplicationStatus: SellerApplicationStatus.none,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(shopperSession)),
        ],
      );
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

      // Shopper taps FAB (+)
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // "Report Price Observation" sheet is shown
      expect(find.text('Report Price Observation'), findsOneWidget);
      expect(find.text('Your Name (Poster Name)'), findsOneWidget);

      // Prefilled with shopper display name
      expect(find.text('Chidi Okonkwo'), findsOneWidget);

      // Fill commodity and price
      await tester.enterText(find.widgetWithText(TextField, 'Commodity Name'), 'Fresh Tomatoes');
      await tester.enterText(find.widgetWithText(TextField, 'Price (₦)'), '1500');
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.text('Submit Observation'));
      await tester.tap(find.text('Submit Observation'));
      await tester.pumpAndSettle();

      // Verify observation was created in communityProvider with submitterName: 'Chidi Okonkwo'
      final obsList = container.read(communityProvider);
      expect(obsList.isNotEmpty, isTrue);
      final submittedObs = obsList.first;
      expect(submittedObs.productName, equals('Fresh Tomatoes'));
      expect(submittedObs.price, equals(1500.0));
      expect(submittedObs.submitterName, equals('Chidi Okonkwo'));
      expect(submittedObs.submitterRole, equals('Customer'));
      expect(submittedObs.isVerified, isFalse);
    });
  });
}

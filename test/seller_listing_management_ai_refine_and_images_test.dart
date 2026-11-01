import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/presentation/widgets/commodity_image_widget.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/seller/presentation/seller_portal_screen.dart';

void main() {
  group('1. Meta AI Seller Listing Auto-Fill & Refine Tests', () {
    const metaAi = MetaAiService();

    test('refineSellerListing parses raw commodity string into structured fields', () {
      final result = metaAi.refineSellerListing(
        rawInput: 'Mama Gold Parboiled Rice 50kg bag 85000 naira clean destoned stock in warehouse',
      );

      expect(result['productName'], contains('Rice'));
      expect(result['price'], 85000.0);
      expect(result['unit'], '50kg bag');
      expect(result['category'], 'Groceries');
      expect(result['brand'], 'Mama Gold');
      expect(result['notes'], isNotNull);
    });

    test('refineSellerListing detects Electronics category for appliances', () {
      final result = metaAi.refineSellerListing(
        rawInput: 'Binatone 1.5L electric blender with grinder 32000 naira warranty included',
      );

      expect(result['category'], 'Electronics');
      expect(result['unit'], 'piece');
      expect(result['price'], 32000.0);
      expect(result['brand'], 'Binatone');
    });

    test('refineSellerListing detects Pharmacy category for medicines', () {
      final result = metaAi.refineSellerListing(
        rawInput: 'Paracetamol 500mg blister pack 1500 naira original Emzor',
      );

      expect(result['category'], 'Pharmacy');
      expect(result['price'], 1500.0);
      expect(result['brand'], 'Emzor');
    });
  });

  group('2. Community Listing Stock Toggle, Modify & Delete State Tests', () {
    test('toggleListingStock flips inStock state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(communityProvider.notifier);
      notifier.addObservation(
        productName: 'Brown Beans',
        sellerName: 'Moria Store',
        price: 4500,
        unit: 'paint rubber',
        category: 'Groceries',
        submitterName: 'You',
        submitterRole: 'Trader',
        inStock: true,
      );

      final initial = container.read(communityProvider);
      expect(initial.isNotEmpty, true);

      final targetId = initial.first.id;
      expect(initial.first.inStock, true);

      notifier.toggleListingStock(targetId);

      final updated = container.read(communityProvider).firstWhere((o) => o.id == targetId);
      expect(updated.inStock, false);
    });

    test('updateListingDetails modifies all listing fields and recalculates normalized price', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(communityProvider.notifier);
      notifier.addObservation(
        productName: 'Standard Rice',
        sellerName: 'Moria Store',
        price: 80000,
        unit: '50kg bag',
        category: 'Groceries',
        submitterName: 'You',
        submitterRole: 'Trader',
        inStock: true,
      );

      final initial = container.read(communityProvider);
      final target = initial.first;

      notifier.updateListingDetails(
        id: target.id,
        productName: 'Royal Stallion Rice',
        price: 92000.0,
        unit: '50kg bag',
        category: 'Groceries',
        brandOrGrade: 'Royal Stallion',
        notes: 'Premium graded rice',
        inStock: false,
      );

      final updated = container.read(communityProvider).firstWhere((o) => o.id == target.id);
      expect(updated.productName, 'Royal Stallion Rice');
      expect(updated.price, 92000.0);
      expect(updated.unit, '50kg bag');
      expect(updated.category, 'Groceries');
      expect(updated.brandOrGrade, 'Royal Stallion');
      expect(updated.notes, 'Premium graded rice');
      expect(updated.inStock, false);
      expect(updated.standardizedUnitPrice, isNotNull);
      // 92000 / 50 = 1840 per kg
      expect(updated.standardizedUnitPrice, closeTo(1840, 5));
    });

    test('deleteListing removes price observation from community feed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(communityProvider.notifier);
      notifier.addObservation(
        productName: 'Temporary Item',
        sellerName: 'Moria Store',
        price: 2000,
        unit: '1kg',
        category: 'Groceries',
        submitterName: 'You',
        submitterRole: 'Trader',
      );

      final initial = container.read(communityProvider);
      final targetId = initial.first.id;

      notifier.deleteListing(targetId);

      final remaining = container.read(communityProvider);
      expect(remaining.any((o) => o.id == targetId), false);
    });
  });

  group('3. CommodityImageWidget Visual Image Component Tests', () {
    testWidgets('Renders curated image or fallback icon for commodities', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CommodityImageWidget(commodityName: 'White Garri', size: 50),
                CommodityImageWidget(commodityName: 'Brown Beans', size: 50),
                CommodityImageWidget(commodityName: 'Palm Oil', size: 50),
                CommodityImageWidget(commodityName: 'Yam Tuber', size: 50),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CommodityImageWidget), findsNWidgets(4));
    });

    test('Curated image URL resolver identifies Nigerian commodities', () {
      expect(CommodityImageWidget.resolveCuratedImageUrl('Brown Beans'), isNotNull);
      expect(CommodityImageWidget.resolveCuratedImageUrl('White Garri Ijebu'), isNotNull);
      expect(CommodityImageWidget.resolveCuratedImageUrl('Palm Oil Epo Pupa'), isNotNull);
      expect(CommodityImageWidget.resolveCuratedImageUrl('Mama Gold Rice'), isNotNull);
      expect(CommodityImageWidget.resolveCuratedImageUrl('Fresh Tomatoes'), isNotNull);
    });
  });

  group('4. SellerPortalScreen Listings UI Management Tests', () {
    testWidgets('Approved seller view displays listings with 1-tap stock switch, edit and delete buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      const applicantEmail = 'seller.moria@gmail.com';
      final applicantSession = UserSession(
        id: 'usr-moria',
        email: applicantEmail,
        displayName: 'Iya Moria',
        role: 'Customer',
        isGuest: false,
      );
      container.read(authProvider.notifier).setSession(applicantSession);

      container.read(sellerApplicationsProvider.notifier).submitApplication(
        user: applicantSession,
        businessName: 'Iya Moria Provisions',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        phone: '+2348022223333',
        stallLocation: 'Stall B4, Bodija Market',
      );
      final appId = container.read(sellerApplicationsProvider).first.id;
      container.read(sellerApplicationsProvider.notifier).approveApplication(appId);

      // Add a test listing for Iya Moria Provisions
      container.read(communityProvider.notifier).addObservation(
        productName: 'Iya Moria Brown Beans',
        sellerName: 'Iya Moria Provisions',
        price: 4500.0,
        unit: 'paint rubber',
        category: 'Groceries',
        submitterName: 'You (Verified Seller)',
        submitterRole: 'Trader',
        inStock: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SellerPortalScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify listing card renders product name, category badge, stock switch, and edit/delete icons
      expect(find.text('Iya Moria Brown Beans'), findsOneWidget);
      expect(find.text('Groceries'), findsWidgets);
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.byTooltip('Modify Listing'), findsOneWidget);
      expect(find.byTooltip('Delete Listing'), findsOneWidget);

      // Tap 1-tap stock toggle
      await tester.tap(find.text('In Stock'));
      await tester.pumpAndSettle();

      // Verify stock toggled to Out of Stock
      expect(find.text('Out of Stock'), findsOneWidget);

      // Tap Edit button to open edit dialog
      await tester.tap(find.byTooltip('Modify Listing'));
      await tester.pumpAndSettle();

      expect(find.text('Modify Price Listing'), findsOneWidget);
      expect(find.text('AI Refine'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });
}

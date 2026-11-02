import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/models/commodity_item.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/services/location_service.dart';
import 'package:smartmove/core/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SellerApplication Model & Schema Mapping Tests', () {
    test('1. Serializes to JSON and deserializes from camelCase properly', () {
      final now = DateTime.now();
      final app = SellerApplication(
        id: 'app-001',
        userId: 'usr-123',
        applicantName: 'Tunde Bakare',
        applicantEmail: 'tunde@bakare.ng',
        businessName: 'Bakare Farm Produce',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        stallLocation: 'Stall C12',
        phone: '+234 802 111 2233',
        status: SellerApplicationStatus.pending,
        submittedAt: now,
      );

      final json = app.toJson();
      expect(json['id'], equals('app-001'));
      expect(json['userId'], equals('usr-123'));
      expect(json['businessName'], equals('Bakare Farm Produce'));
      expect(json['status'], equals('pending'));

      final restored = SellerApplication.fromJson(json);
      expect(restored.applicantName, equals('Tunde Bakare'));
      expect(restored.stallLocation, equals('Stall C12'));
      expect(restored.status, equals(SellerApplicationStatus.pending));
    });

    test('2. Deserializes from Supabase snake_case SQL response correctly', () {
      final dbRow = {
        'id': 'a1111111-2222-3333-4444-555555555555',
        'user_id': 'u9999999-8888-7777-6666-555555555555',
        'applicant_name': 'Alhaja Kudirat',
        'applicant_email': 'kudirat@market.ng',
        'business_name': 'Kudirat Grains',
        'market_hub': 'Bodija Market',
        'seller_channel': 'Local Market',
        'stall_location': 'Line 4, Stall 22',
        'phone': '+234 803 456 7890',
        'status': 'approved',
        'submitted_at': '2026-10-29T10:00:00.000Z',
        'reviewed_at': '2026-10-30T08:00:00.000Z',
        'rejection_reason': null,
      };

      final app = SellerApplication.fromJson(dbRow);
      expect(app.id, equals('a1111111-2222-3333-4444-555555555555'));
      expect(app.userId, equals('u9999999-8888-7777-6666-555555555555'));
      expect(app.applicantName, equals('Alhaja Kudirat'));
      expect(app.businessName, equals('Kudirat Grains'));
      expect(app.stallLocation, equals('Line 4, Stall 22'));
      expect(app.status, equals(SellerApplicationStatus.approved));
      expect(app.reviewedAt, isNotNull);

      // Verify toDbMap outputs matching snake_case schema columns
      final dbMap = app.toDbMap();
      expect(dbMap['business_name'], equals('Kudirat Grains'));
      expect(dbMap['user_id'], equals('u9999999-8888-7777-6666-555555555555'));
      expect(dbMap['stall_location'], equals('Line 4, Stall 22'));
    });

    test('3. SellerApplicationStatus label descriptions match UI specifications', () {
      expect(SellerApplicationStatus.none.label, equals('Not Applied'));
      expect(SellerApplicationStatus.pending.label, equals('Pending Approval'));
      expect(SellerApplicationStatus.approved.label, equals('Approved & Active'));
      expect(SellerApplicationStatus.rejected.label, equals('Application Rejected'));
    });
  });

  group('SellerApplicationsNotifier & Approval Lifecycle Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('4. Submitting application transitions user session to pending review', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial user is customer
      final customer = const UserSession(
        id: 'usr-chinedu-001',
        email: 'chinedu@smartmove.app',
        displayName: 'Chinedu Okeke',
        role: 'Customer',
      );
      container.read(authProvider.notifier).setSession(customer);

      final initialSession = container.read(authProvider);
      expect(initialSession.isCustomer, isTrue);
      expect(initialSession.isPendingSeller, isFalse);
      expect(initialSession.canApplyForSeller, isTrue);

      // Submit application
      container.read(sellerApplicationsProvider.notifier).submitApplication(
            user: initialSession,
            businessName: 'Chinedu Agro Commodities',
            marketHub: 'Bodija Market',
            sellerChannel: 'Local Market',
            stallLocation: 'Stall 8B Main Grain Line',
            phone: '+234 809 123 4567',
          );

      // Verify application record added
      final apps = container.read(sellerApplicationsProvider);
      final submitted = apps.firstWhere((a) => a.userId == 'usr-chinedu-001');
      expect(submitted.businessName, equals('Chinedu Agro Commodities'));
      expect(submitted.status, equals(SellerApplicationStatus.pending));

      // Verify user session is now pending review
      final updatedUser = container.read(authProvider);
      expect(updatedUser.isPendingSeller, isTrue);
      expect(updatedUser.isCustomer, isTrue); // Not yet seller until approved!
      expect(updatedUser.canApplyForSeller, isFalse);
    });

    test('5. Admin approving application upgrades user to Trader role and unlocks seller portal', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final customer = const UserSession(
        id: 'usr-kemi-001',
        email: 'kemi@smartmove.app',
        displayName: 'Kemi Adebayo',
        role: 'Customer',
      );
      container.read(authProvider.notifier).setSession(customer);

      // Submit application
      container.read(sellerApplicationsProvider.notifier).submitApplication(
            user: customer,
            businessName: 'Kemi Organic Spices',
            marketHub: 'Bodija Market',
            sellerChannel: 'Local Market',
            stallLocation: 'Stall 44 Spices Section',
            phone: '+234 803 777 8899',
          );

      final apps = container.read(sellerApplicationsProvider);
      final submitted = apps.firstWhere((a) => a.userId == 'usr-kemi-001');

      // Admin approves application
      container.read(sellerApplicationsProvider.notifier).approveApplication(submitted.id);

      final updatedApps = container.read(sellerApplicationsProvider);
      final approvedApp = updatedApps.firstWhere((a) => a.id == submitted.id);
      expect(approvedApp.status, equals(SellerApplicationStatus.approved));
      expect(approvedApp.reviewedAt, isNotNull);

      // Current user should now be upgraded to Trader
      final promotedUser = container.read(authProvider);
      expect(promotedUser.isSeller, isTrue);
      expect(promotedUser.role, equals('Trader'));
      expect(promotedUser.isApprovedSeller, isTrue);
      expect(promotedUser.canSubmitVerifiedListing, isTrue);
    });

    test('6. Admin rejecting application marks status as rejected with reason', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final customer = const UserSession(
        id: 'usr-reject-001',
        email: 'reject@smartmove.app',
        displayName: 'Reject Candidate',
        role: 'Customer',
      );
      container.read(authProvider.notifier).setSession(customer);

      container.read(sellerApplicationsProvider.notifier).submitApplication(
            user: customer,
            businessName: 'Unverified Stalls Inc',
            marketHub: 'Bodija Market',
            sellerChannel: 'Local Market',
            phone: '+234 800 000 0000',
          );

      final apps = container.read(sellerApplicationsProvider);
      final submitted = apps.firstWhere((a) => a.userId == 'usr-reject-001');

      container.read(sellerApplicationsProvider.notifier).rejectApplication(
            submitted.id,
            reason: 'Physical stall could not be verified by market union executive.',
          );

      final updatedApps = container.read(sellerApplicationsProvider);
      final rejectedApp = updatedApps.firstWhere((a) => a.id == submitted.id);
      expect(rejectedApp.status, equals(SellerApplicationStatus.rejected));
      expect(rejectedApp.rejectionReason, contains('Physical stall could not be verified'));

      final currentUser = container.read(authProvider);
      expect(currentUser.isRejectedSeller, isTrue);
      expect(currentUser.isSeller, isFalse);
      expect(currentUser.canApplyForSeller, isTrue); // Allowed to reapply after rejection
    });

    test('7. Approved seller with role Customer is recognized as seller with portal access', () {
      const approvedSession = UserSession(
        id: 'usr-appr-99',
        email: 'approved@market.ng',
        displayName: 'Iya Moria',
        role: 'Customer', // Role still Customer in session
        businessName: 'Iya Moria Foodstuffs',
        marketHub: 'Bodija Market',
        sellerApplicationStatus: SellerApplicationStatus.approved,
        stallLocation: 'Stall 18, Grain Section, Bodija Market (Lat: 7.4343, Lon: 3.9056)',
        latitude: 7.4343,
        longitude: 3.9056,
      );

      // Verify session getters recognize approved status
      expect(approvedSession.isApprovedSeller, isTrue);
      expect(approvedSession.isSeller, isTrue);
      expect(approvedSession.canSubmitVerifiedListing, isTrue);
      expect(approvedSession.isCustomer, isFalse);
    });

    test('8. Detailed location scanning produces formatted stall address with GPS coordinates', () async {
      final scanned = await LocationService.scanDetailedStallLocation(
        fallback: const GeoPoint(
          latitude: 7.4343,
          longitude: 3.9056,
          label: 'Bodija Market Hub',
          city: 'Ibadan',
          town: 'Bodija',
          isDeviceLocation: true,
        ),
      );

      expect(scanned, isNotNull);
      expect(scanned!.latitude, closeTo(7.4343, 0.001));
      expect(scanned.longitude, closeTo(3.9056, 0.001));
      expect(scanned.closestHub.isNotEmpty, isTrue);

      final formatted = scanned.formatStallAddress(prefix: 'Stall B44');
      expect(formatted, contains('Stall B44'));
      // Verified requirement: Latitude and longitude are preserved in numeric fields (scanned.latitude/longitude)
      // for backend positioning and map distance calculation, and NEVER polluted into user-facing address plain text.
      expect(formatted.contains('Lat:'), isFalse);
      expect(formatted.contains('Lon:'), isFalse);
    });

    test('9. Submitting application with scanned GPS coordinates preserves location data', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const applicant = UserSession(
        id: 'usr-gps-01',
        email: 'gps@market.ng',
        displayName: 'GPS Trader',
        role: 'Customer',
      );
      container.read(authProvider.notifier).setSession(applicant);

      container.read(sellerApplicationsProvider.notifier).submitApplication(
            user: applicant,
            businessName: 'GPS Agro Hub',
            marketHub: 'Bodija Market',
            sellerChannel: 'Local Market',
            stallLocation: 'Stall 12, Main Grain Line, Bodija Market (Lat: 7.4343, Lon: 3.9056)',
            latitude: 7.4343,
            longitude: 3.9056,
            phone: '+234 803 111 2222',
          );

      final apps = container.read(sellerApplicationsProvider);
      final submitted = apps.firstWhere((a) => a.userId == 'usr-gps-01');
      expect(submitted.latitude, equals(7.4343));
      expect(submitted.longitude, equals(3.9056));
      expect(submitted.stallLocation, contains('Lat: 7.4343'));

      // Approve application and verify user session inherits GPS coordinates
      container.read(sellerApplicationsProvider.notifier).approveApplication(submitted.id);
      final updatedUser = container.read(authProvider);
      expect(updatedUser.isApprovedSeller, isTrue);
      expect(updatedUser.latitude, equals(7.4343));
      expect(updatedUser.longitude, equals(3.9056));
      expect(updatedUser.stallLocation, contains('Stall 12'));
    });

    test('10. DecisionEngine uses seller physical GPS coordinates to calculate buyer navigation distance', () {
      final trader = SellerApplication(
        id: 'trader-bodija-1',
        userId: 'usr-trader-01',
        applicantName: 'Chief Ade',
        applicantEmail: 'ade@bodija.ng',
        businessName: 'Ade Grain Terminals',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        stallLocation: 'Stall 4, Grain Line, Bodija Market (Lat: 7.4343, Lon: 3.9056)',
        latitude: 7.4343,
        longitude: 3.9056,
        phone: '+234 802 333 4444',
        status: SellerApplicationStatus.approved,
        submittedAt: DateTime.now(),
      );

      // Buyer at Dugbe (Lat: 7.3876, Lon: 3.8767)
      const buyerLocation = GeoPoint(
        latitude: 7.3876,
        longitude: 3.8767,
        label: 'Dugbe Commercial Hub',
        city: 'Ibadan',
        town: 'Dugbe',
        isDeviceLocation: true,
      );

      final shoppingItems = [
        ShoppingItem(
          id: 'item-rice',
          productName: 'Parboiled Rice 50kg',
          quantity: 1,
          unit: '50kg bag',
          estimatedUnitPrice: 75000,
        ),
      ];

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 100000,
        baseTransportFare: 1000,
        maxTimeHours: 3.0,
        items: shoppingItems,
        userLocation: buyerLocation,
        registeredTraders: [trader],
      );

      expect(plans.isNotEmpty, isTrue);
      final planA = plans.firstWhere((p) => p.id == 'plan-a');
      expect(planA.stops.isNotEmpty, isTrue);

      final sellerStop = planA.stops.firstWhere((s) => s.isPlatformRegisteredTrader);
      expect(sellerStop.location, contains('Stall 4, Grain Line, Bodija Market'));
      // Verified distance from Dugbe (7.3876, 3.8767) to Bodija (7.4343, 3.9056) is ~6.1 km
      expect(sellerStop.distanceKm, closeTo(6.1, 1.5));
    });

    test('11. Revoking approved seller demotes user back to Customer and updates application status', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const user = UserSession(
        id: 'usr-revoke-test',
        email: 'tunde@kuto.ng',
        displayName: 'Tunde Trader',
        role: 'Trader',
        sellerApplicationStatus: SellerApplicationStatus.approved,
        businessName: 'Tunde Grains',
      );
      container.read(authProvider.notifier).setSession(user);

      container.read(sellerApplicationsProvider.notifier).submitApplication(
            user: user,
            businessName: 'Tunde Grains',
            marketHub: 'Kuto Market, Abeokuta',
            sellerChannel: 'Local Market',
            phone: '+234 803 123 4567',
          );

      final app = container.read(sellerApplicationsProvider).first;
      container.read(sellerApplicationsProvider.notifier).approveApplication(app.id);

      var currentUser = container.read(authProvider);
      expect(currentUser.isApprovedSeller, isTrue);

      // SuperAdmin revokes the approval
      container.read(sellerApplicationsProvider.notifier).revokeApproval(
            app.id,
            reason: 'Inaccurate market pricing reported',
          );

      final updatedApp = container.read(sellerApplicationsProvider).first;
      expect(updatedApp.status, SellerApplicationStatus.rejected);
      expect(updatedApp.rejectionReason, contains('Inaccurate market pricing'));

      currentUser = container.read(authProvider);
      expect(currentUser.isApprovedSeller, isFalse);
      expect(currentUser.role, equals('Customer'));
      expect(currentUser.sellerApplicationStatus, SellerApplicationStatus.rejected);
    });

    test('12. Re-opening application restores status to pending review for admin re-evaluation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const user = UserSession(
        id: 'usr-reopen-test',
        email: 'reopen@market.ng',
        displayName: 'Amina',
        role: 'Customer',
        sellerApplicationStatus: SellerApplicationStatus.rejected,
      );
      container.read(authProvider.notifier).setSession(user);

      container.read(sellerApplicationsProvider.notifier).submitApplication(
            user: user,
            businessName: 'Amina Provisions',
            marketHub: 'Oja Oba Market, Akure',
            sellerChannel: 'Local Market',
            phone: '+234 809 988 7766',
          );

      final app = container.read(sellerApplicationsProvider).first;
      container.read(sellerApplicationsProvider.notifier).rejectApplication(app.id, reason: 'Invalid phone');

      var currentApp = container.read(sellerApplicationsProvider).first;
      expect(currentApp.status, SellerApplicationStatus.rejected);

      // SuperAdmin re-opens the application
      container.read(sellerApplicationsProvider.notifier).reopenApplication(app.id);

      currentApp = container.read(sellerApplicationsProvider).first;
      expect(currentApp.status, SellerApplicationStatus.pending);
      expect(currentApp.rejectionReason, isNull);
    });

    test('13. Submitting re-application cleanly replaces previous application without duplicates', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const user = UserSession(
        id: 'usr-dedup-test',
        email: 'dedup@ogun.ng',
        displayName: 'Femi',
        role: 'Customer',
      );
      container.read(authProvider.notifier).setSession(user);

      // First submission
      container.read(sellerApplicationsProvider.notifier).submitApplication(
            user: user,
            businessName: 'Femi First Draft',
            marketHub: 'Omida Market, Abeokuta',
            sellerChannel: 'Local Market',
            phone: '+234 801 111 2222',
          );

      expect(container.read(sellerApplicationsProvider).length, 1);
      expect(container.read(sellerApplicationsProvider).first.businessName, 'Femi First Draft');

      // Re-apply with corrected business name and stall
      container.read(sellerApplicationsProvider.notifier).submitApplication(
            user: user,
            businessName: 'Femi Verified Superstore',
            marketHub: 'Kuto Market, Abeokuta',
            sellerChannel: 'Local Market',
            phone: '+234 801 111 2222',
            stallLocation: 'Stall B2, Produce Row',
          );

      // Must be 1 application (replaced cleanly), not 2 duplicates
      final apps = container.read(sellerApplicationsProvider);
      expect(apps.length, 1);
      expect(apps.first.businessName, 'Femi Verified Superstore');
      expect(apps.first.stallLocation, 'Stall B2, Produce Row');
    });
  });
}


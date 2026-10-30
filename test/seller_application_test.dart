import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/services/auth_service.dart';
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
  });
}


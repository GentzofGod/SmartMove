import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService & UserSession Unit Tests (Role-Based Access Control)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. UserRole enum parses labels and handles case-insensitive strings', () {
      expect(UserRole.customer.label, equals('Customer'));
      expect(UserRole.trader.label, equals('Trader'));
      expect(UserRole.admin.label, equals('Admin'));

      expect(UserRole.fromString('Trader'), equals(UserRole.trader));
      expect(UserRole.fromString('seller'), equals(UserRole.trader));
      expect(UserRole.fromString('Admin'), equals(UserRole.admin));
      expect(UserRole.fromString('administrator'), equals(UserRole.admin));
      expect(UserRole.fromString('Customer'), equals(UserRole.customer));
      expect(UserRole.fromString('unknown'), equals(UserRole.customer));
      expect(UserRole.fromString(null), equals(UserRole.customer));
    });

    test('2. UserSession.guest provides default guest customer permissions', () {
      const guest = UserSession.guest;
      expect(guest.isGuest, isTrue);
      expect(guest.role, equals('Customer'));
      expect(guest.isCustomer, isTrue);
      expect(guest.isSeller, isFalse);
      expect(guest.isAdmin, isFalse);
      expect(guest.canModerate, isFalse);
      expect(guest.canSubmitVerifiedListing, isFalse);
      expect(guest.businessName, isNull);
    });

    test('3. Trader / Seller session carries business metadata and seller permissions', () {
      const traderSession = UserSession(
        id: 'usr-trader-01',
        email: 'bello@bodijamarket.ng',
        displayName: 'Mama Bello',
        role: 'Trader',
        businessName: 'Mama Bello Grains & Oil',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        phone: '+234 802 345 6789',
      );

      expect(traderSession.isSeller, isTrue);
      expect(traderSession.isCustomer, isFalse);
      expect(traderSession.isAdmin, isFalse);
      expect(traderSession.canSubmitVerifiedListing, isTrue);
      expect(traderSession.canModerate, isFalse);
      expect(traderSession.businessName, equals('Mama Bello Grains & Oil'));
      expect(traderSession.marketHub, equals('Bodija Market'));
      expect(traderSession.sellerChannel, equals('Local Market'));
      expect(traderSession.phone, equals('+234 802 345 6789'));
    });

    test('4. Admin session carries moderation permissions and can submit verified listings', () {
      const adminSession = UserSession(
        id: 'usr-admin-01',
        email: 'supervisor@smartmove.app',
        displayName: 'Market Supervisor',
        role: 'Admin',
      );

      expect(adminSession.isAdmin, isTrue);
      expect(adminSession.isSeller, isFalse);
      expect(adminSession.isCustomer, isFalse);
      expect(adminSession.canModerate, isTrue);
      expect(adminSession.canSubmitVerifiedListing, isTrue);
    });

    test('5. UserSession serialization (toJson / fromJson) preserves full seller metadata', () {
      const original = UserSession(
        id: 'usr-12345',
        email: 'dugbestore@gmail.com',
        displayName: 'Kazeem Ade',
        isGuest: false,
        role: 'Trader',
        businessName: 'Ade Wholesale Foods',
        marketHub: 'Dugbe Market',
        sellerChannel: 'SMB Store',
        phone: '+234 809 111 2233',
      );

      final json = original.toJson();
      final restored = UserSession.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.email, equals(original.email));
      expect(restored.displayName, equals(original.displayName));
      expect(restored.role, equals('Trader'));
      expect(restored.isSeller, isTrue);
      expect(restored.businessName, equals('Ade Wholesale Foods'));
      expect(restored.marketHub, equals('Dugbe Market'));
      expect(restored.sellerChannel, equals('SMB Store'));
      expect(restored.phone, equals('+234 809 111 2233'));
    });

    test('6. UserSession copyWith cleanly modifies role and seller fields', () {
      const base = UserSession.guest;
      final promoted = base.copyWith(
        role: 'Trader',
        businessName: 'Gent Grains',
        marketHub: 'Oje Market',
        sellerChannel: 'Local Market',
      );

      expect(promoted.role, equals('Trader'));
      expect(promoted.isSeller, isTrue);
      expect(promoted.businessName, equals('Gent Grains'));
      expect(promoted.marketHub, equals('Oje Market'));
      expect(promoted.sellerChannel, equals('Local Market'));
    });

    test('7. AuthService persistSession and restorePersistedSession persist to SharedPreferences', () async {
      const session = UserSession(
        id: 'usr-persisted-99',
        email: 'test@smartmove.app',
        displayName: 'Test Submitter',
        role: 'Admin',
      );

      await AuthService.persistSession(session);
      final restored = await AuthService.restorePersistedSession();

      expect(restored.id, equals('usr-persisted-99'));
      expect(restored.email, equals('test@smartmove.app'));
      expect(restored.role, equals('Admin'));
      expect(restored.isAdmin, isTrue);
      expect(restored.canModerate, isTrue);
    });

    test('8. AuthService signUpWithEmail defaults to Customer and supports seller application workflow', () async {
      final session = await AuthService.signUpWithEmail(
        email: 'ibadan.oil@gmail.com',
        password: 'secure_password_123',
        displayName: 'Ibadan Pure Oil',
      );

      expect(session.email, equals('ibadan.oil@gmail.com'));
      expect(session.role, equals('Customer'));
      expect(session.isCustomer, isTrue);
      expect(session.isSeller, isFalse);
      expect(session.canApplyForSeller, isTrue);
      expect(session.sellerApplicationStatus, equals(SellerApplicationStatus.none));

      // Simulate applying for seller status
      final pendingSession = session.copyWith(
        businessName: 'Ibadan Pure Oil Mills',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        phone: '+234 805 999 8877',
        stallLocation: 'Stall B44',
        sellerApplicationStatus: SellerApplicationStatus.pending,
      );
      await AuthService.persistSession(pendingSession);

      final restoredPending = await AuthService.restorePersistedSession();
      expect(restoredPending.isPendingSeller, isTrue);
      expect(restoredPending.businessName, equals('Ibadan Pure Oil Mills'));

      // Simulate admin approval
      final approvedSession = restoredPending.copyWith(
        role: 'Trader',
        sellerApplicationStatus: SellerApplicationStatus.approved,
      );
      await AuthService.persistSession(approvedSession);

      final restoredApproved = await AuthService.restorePersistedSession();
      expect(restoredApproved.isSeller, isTrue);
      expect(restoredApproved.isApprovedSeller, isTrue);
      expect(restoredApproved.canSubmitVerifiedListing, isTrue);
    });

    test('9. AuthService signOut removes persisted session and restores to guest', () async {
      await AuthService.signUpWithEmail(
        email: 'temp@smartmove.app',
        password: 'password',
        displayName: 'Temp User',
      );
      expect((await AuthService.restorePersistedSession()).email, equals('temp@smartmove.app'));

      await AuthService.signOut();
      final restored = await AuthService.restorePersistedSession();
      expect(restored.isGuest, isTrue);
      expect(restored.id, equals(UserSession.guest.id));
    });
  });
}


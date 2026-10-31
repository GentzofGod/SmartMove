import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/admin/presentation/superadmin_panel_screen.dart';
import 'package:smartmove/features/community/presentation/community_screen.dart';
import 'package:smartmove/features/home/presentation/home_screen.dart';
import 'package:smartmove/features/profile/presentation/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserRole & SuperAdmin Governance Unit Tests', () {
    test('1. UserRole enum properly parses SuperAdmin variants', () {
      expect(UserRole.fromString('SuperAdmin'), equals(UserRole.superAdmin));
      expect(UserRole.fromString('superAdmin'), equals(UserRole.superAdmin));
      expect(UserRole.fromString('super_admin'), equals(UserRole.superAdmin));
      expect(UserRole.fromString('super-admin'), equals(UserRole.superAdmin));
      expect(UserRole.fromString('SUPERADMIN'), equals(UserRole.superAdmin));

      expect(UserRole.superAdmin.label, equals('SuperAdmin'));
    });

    test('2. UserSession correctly evaluates isSuperAdmin, isAdmin, and canModerate', () {
      const superAdminSession = UserSession(
        id: 'usr-super-01',
        email: 'root@smartmove.app',
        displayName: 'Platform SuperAdmin',
        role: 'SuperAdmin',
      );
      expect(superAdminSession.isSuperAdmin, isTrue);
      expect(superAdminSession.isAdmin, isTrue);
      expect(superAdminSession.canModerate, isTrue);
      expect(superAdminSession.isCustomer, isFalse);
      expect(superAdminSession.isSeller, isFalse);

      const adminSession = UserSession(
        id: 'usr-admin-01',
        email: 'moderator@smartmove.app',
        displayName: 'Market Moderator',
        role: 'Admin',
      );
      expect(adminSession.isSuperAdmin, isFalse);
      expect(adminSession.isAdmin, isTrue);
      expect(adminSession.canModerate, isTrue);

      const customerSession = UserSession(
        id: 'usr-cust-01',
        email: 'shopper@smartmove.app',
        displayName: 'Bisi Shopper',
        role: 'Customer',
      );
      expect(customerSession.isSuperAdmin, isFalse);
      expect(customerSession.isAdmin, isFalse);
      expect(customerSession.canModerate, isFalse);
      expect(customerSession.isCustomer, isTrue);
    });

    test('3. UserSession serialization and deserialization retains SuperAdmin role', () {
      const session = UserSession(
        id: 'usr-super-42',
        email: 'superadmin@smartmove.app',
        displayName: 'Ibrahim SuperAdmin',
        role: 'SuperAdmin',
        businessName: 'SmartMove Governance',
        marketHub: 'Bodija Market',
      );

      final json = session.toJson();
      expect(json['role'], equals('SuperAdmin'));
      expect(json['displayName'], equals('Ibrahim SuperAdmin'));

      final restored = UserSession.fromJson(json);
      expect(restored.isSuperAdmin, isTrue);
      expect(restored.isAdmin, isTrue);
      expect(restored.canModerate, isTrue);
    });
  });

  group('CommunityScreen Role-Separated Moderation Widget Tests', () {
    testWidgets('4. Customer sees only 2 tabs and NO superadmin chip', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default session is Customer
      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'c1',
              email: 'shopper@test.ng',
              displayName: 'Customer Ayo',
              role: 'Customer',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CommunityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only 2 consumer tabs
      expect(find.text('Price Feed'), findsOneWidget);
      expect(find.text('Seller Portal'), findsOneWidget);
      expect(find.text('Moderation Queue'), findsNothing);

      // SuperAdmin button does NOT appear for consumer
      expect(find.byKey(const ValueKey('btn_open_superadmin_panel')), findsNothing);
    });

    testWidgets('5. SuperAdmin sees navigation chip to SuperAdmin Panel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'sa1',
              email: 'super@smartmove.ng',
              displayName: 'SuperAdmin Chioma',
              role: 'SuperAdmin',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CommunityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SuperAdmin navigation chip is visible in the AppBar
      expect(find.byKey(const ValueKey('btn_open_superadmin_panel')), findsOneWidget);
    });
  });

  group('SuperAdminPanelScreen Widget Tests', () {
    testWidgets('6. Renders SuperAdmin console with 4 tabs and role switcher', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'sa1',
              email: 'superadmin@smartmove.ng',
              displayName: 'Director Aminu',
              role: 'SuperAdmin',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SuperAdminPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Console Header
      expect(find.text('SuperAdmin Console'), findsOneWidget);
      expect(find.text('Platform Governance & Moderation'), findsOneWidget);

      // Verify Role Switcher chip
      expect(find.byKey(const ValueKey('chip_superadmin_role_switcher')), findsOneWidget);
      expect(find.text('SuperAdmin'), findsWidgets);

      // Verify the 4 Administration Tabs
      expect(find.text('Seller Approvals'), findsOneWidget);
      expect(find.text('Price Quotes'), findsOneWidget);
      expect(find.text('Categories & Hubs'), findsOneWidget);
      expect(find.text('Security & Audit'), findsOneWidget);
    });

    testWidgets('7. Approves pending seller application and updates state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'sa1',
              email: 'superadmin@smartmove.ng',
              displayName: 'Director Aminu',
              role: 'SuperAdmin',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SuperAdminPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By default, initial mock application app-001 (Kudirat Grains) is pending
      final pendingApps = container
          .read(sellerApplicationsProvider)
          .where((a) => a.status == SellerApplicationStatus.pending)
          .toList();
      expect(pendingApps.isNotEmpty, isTrue);

      final firstPendingId = pendingApps.first.id;
      final approveBtnFinder = ValueKey('btn_approve_app_$firstPendingId');
      expect(find.byKey(approveBtnFinder), findsOneWidget);

      // Tap Approve
      await tester.tap(find.byKey(approveBtnFinder));
      await tester.pumpAndSettle();

      // Check that the application is now approved
      final updatedApp = container
          .read(sellerApplicationsProvider)
          .firstWhere((a) => a.id == firstPendingId);
      expect(updatedApp.status, equals(SellerApplicationStatus.approved));
      expect(updatedApp.reviewedAt, isNotNull);
    });

    testWidgets('8. Interacts with Price Quotes tab and AI anomaly scan trigger', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'sa1',
              email: 'superadmin@smartmove.ng',
              displayName: 'Director Aminu',
              role: 'SuperAdmin',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SuperAdminPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Price Quotes Tab
      await tester.tap(find.text('Price Quotes'));
      await tester.pumpAndSettle();

      // AI Scan buttons exist
      expect(find.byKey(const ValueKey('btn_superadmin_ai_anomaly_scan')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_superadmin_ai_duplicate_scan')), findsOneWidget);

      // Tap AI Anomaly Scan button
      await tester.tap(find.byKey(const ValueKey('btn_superadmin_ai_anomaly_scan')));
      await tester.pumpAndSettle();

      // Modal bottom sheet opens with audit details
      expect(find.text('Meta AI Price Anomaly Audit'), findsOneWidget);
    });

    testWidgets('9. Switches to Security & Audit tab and verifies governance matrix', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'sa1',
              email: 'superadmin@smartmove.ng',
              displayName: 'Director Aminu',
              role: 'SuperAdmin',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SuperAdminPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll into view and tap Security & Audit Tab
      await tester.ensureVisible(find.text('Security & Audit'));
      await tester.tap(find.text('Security & Audit'));
      await tester.pumpAndSettle();

      // Verify Session Audit and Governance Matrix
      expect(find.text('Active SuperAdmin Session'), findsOneWidget);
      expect(find.text('Role-Based Governance Matrix'), findsOneWidget);
      expect(find.text('Full Governance (Seller Verification, Anomaly Audit, RLS SuperAdmin)'), findsOneWidget);
    });

    testWidgets('10. /superadmin GoRoute mounts SuperAdminPanelScreen correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/superadmin',
        routes: [
          GoRoute(
            path: '/superadmin',
            builder: (context, state) => const SuperAdminPanelScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SuperAdminPanelScreen), findsOneWidget);
      expect(find.text('SuperAdmin Console'), findsOneWidget);
    });

    testWidgets('11. Customer or Guest accessing SuperAdminPanelScreen sees Access Denied', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Customer session
      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'c1',
              email: 'shopper@test.ng',
              displayName: 'Shopper Ayo',
              role: 'Customer',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SuperAdminPanelScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Access Denied screen shown
      expect(find.text('Access Denied — SuperAdmin Privileges Required'), findsOneWidget);
      expect(find.text('Return to Home'), findsOneWidget);
      // Governance tabs NOT accessible
      expect(find.text('Seller Approvals'), findsNothing);
    });

    testWidgets('12. In ProfileScreen, Customer does not see SuperAdmin role switcher, SuperAdmin does', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Customer session
      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'c1',
              email: 'shopper@test.ng',
              displayName: 'Shopper Ayo',
              role: 'Customer',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Role switcher is NOT visible for customer
      expect(find.text('SuperAdmin Role Mode:'), findsNothing);
      expect(find.text('SuperAdmin Moderation Panel'), findsNothing);

      // Verify My Wallet and Saved Items are removed from settings
      expect(find.text('12'), findsNothing);
      expect(find.byKey(const ValueKey('menu_my_wallet')), findsNothing);
      expect(find.byKey(const ValueKey('menu_saved_items')), findsNothing);

      // Upgrade to SuperAdmin
      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'sa1',
              email: 'super@smartmove.ng',
              displayName: 'SuperAdmin Chioma',
              role: 'SuperAdmin',
            ),
          );
      await tester.pumpAndSettle();

      // SuperAdmin sees the switcher and the panel button
      expect(find.text('SuperAdmin Role Mode:'), findsOneWidget);
      expect(find.text('Open SuperAdmin Moderation Panel'), findsOneWidget);
    });

    testWidgets('13. In CommunityScreen, Customer sees seller application workflow and no simulation artifacts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'c1',
              email: 'shopper@test.ng',
              displayName: 'Shopper Ayo',
              role: 'Customer',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CommunityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Seller Portal tab
      await tester.tap(find.text('Seller Portal'));
      await tester.pumpAndSettle();

      // Customer sees onboarding CTA, no simulation toggle exists
      expect(find.text('SmartMove Seller Hub'), findsOneWidget);
      expect(find.text('Apply to Become a Verified Seller'), findsOneWidget);
      expect(find.text('Simulate Seller'), findsNothing);
    });

    testWidgets('14. In HomeScreen, SuperAdmin sees SuperAdmin chip, Customer does not', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'c1',
              email: 'shopper@test.ng',
              displayName: 'Shopper Ayo',
              role: 'Customer',
            ),
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

      // Customer does not see SuperAdmin chip or Role: Customer
      expect(find.byKey(const ValueKey('btn_superadmin_home_chip')), findsNothing);
      expect(find.textContaining('Role: Customer'), findsNothing);

      // Switch to SuperAdmin
      container.read(authProvider.notifier).setSession(
            const UserSession(
              id: 'sa1',
              email: 'super@smartmove.ng',
              displayName: 'SuperAdmin Chioma',
              role: 'SuperAdmin',
            ),
          );
      await tester.pumpAndSettle();

      // SuperAdmin chip is present
      expect(find.byKey(const ValueKey('btn_superadmin_home_chip')), findsOneWidget);
      expect(find.textContaining('SuperAdmin'), findsWidgets);
    });
  });
}

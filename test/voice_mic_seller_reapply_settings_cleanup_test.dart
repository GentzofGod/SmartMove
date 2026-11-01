import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/features/home/presentation/widgets/muse_voice_input_sheet.dart';
import 'package:smartmove/features/profile/presentation/profile_screen.dart';
import 'package:smartmove/features/seller/presentation/seller_portal_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Microphone & Sound Integration Tests', () {
    testWidgets('MuseVoiceInputSheet mounts and handles real-time microphone recording flow', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? capturedText;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MuseVoiceInputSheet(
              onTranscriptConfirmed: (t) => capturedText = t,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap microphone record button to start
      final recordBtn = find.byKey(const ValueKey('voice_record_button'));
      expect(recordBtn, findsOneWidget);
      await tester.tap(recordBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Listening in Auto-Detect'), findsOneWidget);

      // Tap again to stop listening
      await tester.tap(recordBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // In unit test environment without real audio hardware, graceful fallback informs user
      expect(
        find.text('Voice input unavailable. Please type your request directly below.'),
        findsOneWidget,
      );

      // Typing directly is fully functional
      final inputField = find.byKey(const ValueKey('txt_voice_transcript'));
      await tester.enterText(inputField, '2 bags of rice and vegetable oil');
      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(const ValueKey('btn_generate_plan_proposal'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(capturedText, '2 bags of rice and vegetable oil');
    });
  });

  group('2. Seller Application Approval & Account Switch Persistence Tests', () {
    test('Applicant approved by admin retains Trader status when returning to account', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const applicantEmail = 'vendor.ade@gmail.com';
      const applicantName = 'Adeola Vendor';

      // 1. Applicant logs in and submits seller application
      final applicantUser = UserSession(
        id: 'usr-vendor-ade',
        email: applicantEmail,
        displayName: applicantName,
        role: 'Customer',
        sellerApplicationStatus: SellerApplicationStatus.none,
        isGuest: false,
      );
      container.read(authProvider.notifier).setSession(applicantUser);

      container.read(sellerApplicationsProvider.notifier).submitApplication(
            user: applicantUser,
            businessName: 'Adeola Grains Mart',
            marketHub: 'Bodija Market',
            sellerChannel: 'Local Market',
            phone: '+234 802 111 2222',
            stallLocation: 'Stall D12, Grain Sector, Bodija Market',
            latitude: 7.4350,
            longitude: 3.9060,
          );

      // Verify application submitted and pending
      final appsAfterSubmit = container.read(sellerApplicationsProvider);
      final submittedApp = appsAfterSubmit.firstWhere((a) => a.applicantEmail == applicantEmail);
      expect(submittedApp.status, SellerApplicationStatus.pending);

      // 2. Admin logs in (simulating account switch)
      final adminUser = const UserSession(
        id: 'usr-admin-001',
        email: 'superadmin@smartmove.app',
        displayName: 'Platform Admin',
        role: 'SuperAdmin',
        isGuest: false,
      );
      container.read(authProvider.notifier).setSession(adminUser);
      expect(container.read(authProvider).role, 'SuperAdmin');

      // 3. Admin approves applicant's application
      container.read(sellerApplicationsProvider.notifier).approveApplication(submittedApp.id);

      final approvedApps = container.read(sellerApplicationsProvider);
      final approvedApp = approvedApps.firstWhere((a) => a.id == submittedApp.id);
      expect(approvedApp.status, SellerApplicationStatus.approved);

      // 4. Going back to applicant account (sign in with applicantEmail)
      final restoredApplicantSession = await AuthService.signInWithEmail(
        email: applicantEmail,
        password: 'password123',
      );

      // Applicant MUST be upgraded to Trader with approved status and NOT prompted to reapply!
      expect(restoredApplicantSession.role, 'Trader');
      expect(restoredApplicantSession.isSeller, true);
      expect(restoredApplicantSession.isApprovedSeller, true);
      expect(restoredApplicantSession.canApplyForSeller, false);
      expect(restoredApplicantSession.businessName, 'Adeola Grains Mart');
      expect(restoredApplicantSession.marketHub, 'Bodija Market');
      expect(restoredApplicantSession.stallLocation, 'Stall D12, Grain Sector, Bodija Market');
    });

    testWidgets('ProfileScreen renders Registered Seller Profile when approved (no reapply prompt)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const applicantEmail = 'kudirat.grains@gmail.com';
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final applicantSession = UserSession(
        id: 'usr-kudirat',
        email: applicantEmail,
        displayName: 'Alhaja Kudirat',
        role: 'Customer',
        sellerApplicationStatus: SellerApplicationStatus.none,
        isGuest: false,
      );
      container.read(authProvider.notifier).setSession(applicantSession);

      container.read(sellerApplicationsProvider.notifier).submitApplication(
        user: applicantSession,
        businessName: 'Kudirat Grains & Staples',
        marketHub: 'Bodija Market',
        sellerChannel: 'Open Stall',
        phone: '+2348031234567',
        stallLocation: 'Line 2, Bodija Market',
      );
      final appId = container.read(sellerApplicationsProvider).first.id;
      container.read(sellerApplicationsProvider.notifier).approveApplication(appId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must show Registered Seller Profile and NOT "Apply to Become a Verified Seller"
      expect(find.text('Registered Seller Profile'), findsOneWidget);
      expect(find.text('Open Seller Portal'), findsOneWidget);
      expect(find.text('Apply to Become a Verified Seller'), findsNothing);
      expect(find.text('Reapply as Verified Seller'), findsNothing);
    });

    testWidgets('SellerPortalScreen renders without prompt to reapply when approved', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const applicantEmail = 'kudirat.grains@gmail.com';
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final applicantSession = UserSession(
        id: 'usr-kudirat',
        email: applicantEmail,
        displayName: 'Alhaja Kudirat',
        role: 'Customer',
        sellerApplicationStatus: SellerApplicationStatus.none,
        isGuest: false,
      );
      container.read(authProvider.notifier).setSession(applicantSession);

      container.read(sellerApplicationsProvider.notifier).submitApplication(
        user: applicantSession,
        businessName: 'Kudirat Grains & Staples',
        marketHub: 'Bodija Market',
        sellerChannel: 'Open Stall',
        phone: '+2348031234567',
        stallLocation: 'Line 2, Bodija Market',
      );
      final appId = container.read(sellerApplicationsProvider).first.id;
      container.read(sellerApplicationsProvider.notifier).approveApplication(appId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SellerPortalScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must not show prompt to apply
      expect(find.text('Kudirat Grains & Staples'), findsOneWidget);
      expect(find.text('Apply to Become a Verified Seller'), findsNothing);
      expect(find.text('Reapply as Verified Seller'), findsNothing);
    });
  });

  group('3. Settings Page List Tiles Text Cleanup Tests', () {
    testWidgets('NDPA / FCCPC and FAQs & Desk are removed from settings list tiles', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // NDPA / FCCPC should NOT be visible on the Legal & Terms tile
      expect(find.text('NDPA / FCCPC'), findsNothing);

      // FAQs & Desk should NOT be visible on the Help & Support tile
      expect(find.text('FAQs & Desk'), findsNothing);

      // Language should still show current language (e.g. English)
      expect(find.byKey(const ValueKey('menu_language')), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // About SmartMove should still show version
      expect(find.byKey(const ValueKey('menu_about_smartmove')), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
    });
  });

  group('4. App Guide & Tour Removal Tests', () {
    testWidgets('App Guide and Tour menu item is completely removed from settings', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // menu_app_guide and 'App Guide & Tour' must be absent
      expect(find.byKey(const ValueKey('menu_app_guide')), findsNothing);
      expect(find.text('App Guide & Tour'), findsNothing);
      expect(find.text('Replay'), findsNothing);
    });
  });
}

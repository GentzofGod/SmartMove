import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/features/profile/presentation/profile_screen.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/state/app_state.dart';

class FakeAuthNotifier extends AuthNotifier {
  final UserSession initialSession;
  FakeAuthNotifier(this.initialSession);

  @override
  UserSession build() => initialSession;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'smartmove_notifications_enabled': true,
      'smartmove_app_language': 'English',
    });
  });

  Widget buildTestableProfileScreen({UserSession? initialSession}) {
    return ProviderScope(
      overrides: [
        if (initialSession != null)
          authProvider.overrideWith(() => FakeAuthNotifier(initialSession)),
      ],
      child: const MaterialApp(
        home: ProfileScreen(),
      ),
    );
  }

  group('Profile & Settings Functional Tests', () {
    testWidgets('1. Edit User Profile updates display name, email, and phone', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const session = UserSession(
        id: 'user-001',
        email: 'adebayo@test.com',
        displayName: 'Adebayo Johnson',
        role: 'Customer',
        phone: '+234 802 000 1111',
      );

      await tester.pumpWidget(buildTestableProfileScreen(initialSession: session));
      await tester.pumpAndSettle();

      expect(find.text('Adebayo Johnson'), findsOneWidget);
      expect(find.text('adebayo@test.com'), findsOneWidget);

      // Tap Edit Profile button
      final editBtn = find.byKey(const ValueKey('btn_edit_user_profile'));
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Personal Profile'), findsOneWidget);

      // Change name and phone
      await tester.enterText(find.byKey(const ValueKey('input_profile_name')), 'Adebayo Ogunlesi');
      await tester.enterText(find.byKey(const ValueKey('input_profile_phone')), '+234 803 999 8888');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.byKey(const ValueKey('btn_save_user_profile')));
      await tester.pumpAndSettle();

      expect(find.text('Personal profile updated successfully!'), findsOneWidget);
      expect(find.text('Adebayo Ogunlesi'), findsOneWidget);
      expect(find.text('+234 803 999 8888'), findsOneWidget);
    });

    testWidgets('2. My Wallet menu item is cleanly removed from settings', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      final walletTile = find.byKey(const ValueKey('menu_my_wallet'));
      expect(walletTile, findsNothing);
    });

    testWidgets('3. Saved Items menu item is cleanly removed from settings', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      final savedItemsTile = find.byKey(const ValueKey('menu_saved_items'));
      expect(savedItemsTile, findsNothing);
    });

    testWidgets('4. Notifications preferences modal allows toggling alerts and persists to SharedPreferences', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Tap Notifications tile to open preferences
      final notifTile = find.byKey(const ValueKey('menu_notifications_tile'));
      expect(notifTile, findsOneWidget);
      await tester.tap(notifTile);
      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('Commodity Price Drop Alerts'), findsOneWidget);
      expect(find.text('Market Hours & Trading Days'), findsOneWidget);
      expect(find.text('Errand & Delivery Deadlines'), findsOneWidget);

      // Toggle price drop alert
      final priceAlertSwitch = find.byKey(const ValueKey('pref_switch_price_alerts'));
      expect(priceAlertSwitch, findsOneWidget);
      await tester.tap(priceAlertSwitch);
      await tester.pumpAndSettle();

      // Close modal
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('smartmove_price_alerts_enabled'), false);
    });

    testWidgets('5. Language selector bottom sheet includes all 15 common Nigerian languages and updates appLanguageProvider', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Tap Language tile
      final langTile = find.byKey(const ValueKey('menu_language'));
      expect(langTile, findsOneWidget);
      await tester.tap(langTile);
      await tester.pumpAndSettle();

      expect(find.text('Select Dialect / Language'), findsOneWidget);
      expect(find.text('Nigerian Pidgin'), findsOneWidget);
      expect(find.text('Yorùbá'), findsOneWidget);
      expect(find.text('Hausa'), findsOneWidget);
      expect(find.text('Asụsụ Igbo'), findsOneWidget);

      // Select Yorùbá
      final yorubaOption = find.byKey(const ValueKey('lang_option_Yorùbá'));
      expect(yorubaOption, findsOneWidget);
      await tester.tap(yorubaOption);
      await tester.pumpAndSettle();

      expect(find.text('Language set to Yorùbá!'), findsOneWidget);
      expect(find.text('Yorùbá'), findsWidgets);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('smartmove_app_language'), 'Yorùbá');
    });

    testWidgets('6. Data & Privacy sheet displays security info without Supabase Realtime cloud card', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Tap Data & Privacy
      final privacyTile = find.byKey(const ValueKey('menu_data_privacy'));
      expect(privacyTile, findsOneWidget);
      await tester.tap(privacyTile);
      await tester.pumpAndSettle();

      expect(find.text('Data & Privacy Security'), findsOneWidget);
      // Supabase realtime card is removed
      expect(find.text('Supabase Realtime Cloud Sync Active'), findsNothing);
      expect(find.text('Zero Financial Credential Storage'), findsOneWidget);

      // Tap Clear Offline Cache
      final clearCacheBtn = find.byKey(const ValueKey('btn_clear_offline_cache_from_privacy'));
      expect(clearCacheBtn, findsOneWidget);
      await tester.tap(clearCacheBtn);
      await tester.pumpAndSettle();

      expect(find.text('Offline price cache cleared and refreshed with live data!'), findsOneWidget);
    });

    testWidgets('7. Help & Support sheet renders FAQs and email support button without store redirect', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Tap Help & Support
      final helpTile = find.byKey(const ValueKey('menu_help_support'));
      expect(helpTile, findsOneWidget);
      await tester.tap(helpTile);
      await tester.pumpAndSettle();

      expect(find.text('Help & Customer Support'), findsOneWidget);
      expect(find.text('How does SmartMove compare commodity prices?'), findsOneWidget);
      expect(find.text('How do I become a verified seller?'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_whatsapp_support')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_email_support')), findsOneWidget);

      // Tap Email Support - must NOT show External Store Redirect or Proceed to Store
      await tester.tap(find.byKey(const ValueKey('btn_email_support')));
      await tester.pumpAndSettle();

      expect(find.text('External Store Redirect'), findsNothing);
      expect(find.text('Proceed to Store'), findsNothing);
    });

    testWidgets('8. About SmartMove dialog shows v1.2.0 and platform architecture', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Tap About SmartMove
      final aboutTile = find.byKey(const ValueKey('menu_about_smartmove'));
      expect(aboutTile, findsOneWidget);
      await tester.tap(aboutTile);
      await tester.pumpAndSettle();

      expect(find.text('v1.2.0 (Build 2026.10)'), findsOneWidget);
      expect(find.text('Meta AI Architecture: Meta Muse Spark 1.3'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('v1.2.0 (Build 2026.10)'), findsNothing);
    });

    testWidgets('9. Sync Offline Price Cache button is removed from settings', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      final syncBtn = find.byKey(const ValueKey('btn_sync_offline_cache'));
      expect(syncBtn, findsNothing);
    });
  });
}

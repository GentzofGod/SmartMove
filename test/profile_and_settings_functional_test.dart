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

    testWidgets('2. My Wallet sheet allows setting preset and custom budgets', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Tap My Wallet
      final walletTile = find.byKey(const ValueKey('menu_my_wallet'));
      expect(walletTile, findsOneWidget);
      await tester.tap(walletTile);
      await tester.pumpAndSettle();

      expect(find.text('My Wallet & Shopping Budget'), findsOneWidget);
      expect(find.text('Preset Budget Adjustments'), findsOneWidget);

      // Select ₦35k preset
      final preset35k = find.byKey(const ValueKey('chip_budget_35000'));
      expect(preset35k, findsOneWidget);
      await tester.tap(preset35k);
      await tester.pumpAndSettle();

      // Verify text field holds 35000
      final budgetField = tester.widget<TextField>(find.byKey(const ValueKey('input_wallet_budget')));
      expect(budgetField.controller?.text, '35000');

      // Tap Save Shopping Budget
      await tester.tap(find.byKey(const ValueKey('btn_save_wallet_budget')));
      await tester.pumpAndSettle();

      expect(find.text('Shopping budget set to ₦35000!'), findsOneWidget);
      expect(find.text('₦35,000'), findsOneWidget);
    });

    testWidgets('3. Saved Items sheet displays items and allows adding a new commodity', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Tap Saved Items
      final savedItemsTile = find.byKey(const ValueKey('menu_saved_items'));
      expect(savedItemsTile, findsOneWidget);
      await tester.tap(savedItemsTile);
      await tester.pumpAndSettle();

      expect(find.textContaining('Saved Commodities'), findsOneWidget);

      // Tap Add Item button
      final addItemBtn = find.byKey(const ValueKey('btn_add_saved_commodity'));
      expect(addItemBtn, findsOneWidget);
      await tester.tap(addItemBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Commodity'), findsOneWidget);

      // Fill in new commodity details
      await tester.enterText(find.byKey(const ValueKey('input_commodity_name')), 'Brown Beans Oloyin');
      await tester.enterText(find.byKey(const ValueKey('input_commodity_qty')), '2');
      await tester.enterText(find.byKey(const ValueKey('input_commodity_unit')), 'derica');
      await tester.enterText(find.byKey(const ValueKey('input_commodity_price')), '2200');
      await tester.pumpAndSettle();

      // Tap Confirm Add
      await tester.tap(find.byKey(const ValueKey('btn_confirm_add_commodity')));
      await tester.pumpAndSettle();

      expect(find.text('Added Brown Beans Oloyin to saved items!'), findsOneWidget);
      expect(find.text('Brown Beans Oloyin'), findsOneWidget);
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

    testWidgets('5. Language selector bottom sheet allows changing dialect and updates UI', (tester) async {
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
      await tester.tap(find.byKey(const ValueKey('lang_option_Yorùbá')));
      await tester.pumpAndSettle();

      expect(find.text('Language set to Yorùbá!'), findsOneWidget);
      expect(find.text('Yorùbá'), findsWidgets);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('smartmove_app_language'), 'Yorùbá');
    });

    testWidgets('6. Data & Privacy sheet displays security info and clears cache', (tester) async {
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
      expect(find.text('Supabase Realtime Cloud Sync Active'), findsOneWidget);
      expect(find.text('Zero Financial Credential Storage'), findsOneWidget);

      // Tap Clear Offline Cache
      final clearCacheBtn = find.byKey(const ValueKey('btn_clear_offline_cache_from_privacy'));
      expect(clearCacheBtn, findsOneWidget);
      await tester.tap(clearCacheBtn);
      await tester.pumpAndSettle();

      expect(find.text('Offline price cache cleared and refreshed with live data!'), findsOneWidget);
    });

    testWidgets('7. Help & Support sheet renders FAQs and support options', (tester) async {
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

    testWidgets('9. Sync Offline Price Cache button triggers live refresh', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      final syncBtn = find.byKey(const ValueKey('btn_sync_offline_cache'));
      await tester.ensureVisible(syncBtn);
      await tester.pumpAndSettle();
      await tester.tap(syncBtn);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Offline price cache and user profile synchronized with Supabase!'), findsOneWidget);
    });
  });
}

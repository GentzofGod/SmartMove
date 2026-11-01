import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/state/app_state.dart';
import 'package:smartmove/core/localization/app_language.dart';
import 'package:smartmove/features/auth/presentation/auth_screen.dart';
import 'package:smartmove/features/profile/presentation/profile_screen.dart';
import 'package:smartmove/features/legal/presentation/legal_screen.dart';
import 'package:smartmove/features/home/presentation/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Session Persistence & SharedPreferences Tests', () {
    test('Offline session restore retrieves cached authenticated session without reverting to Guest', () async {
      final user = UserSession(
        id: 'usr-offline-trader-01',
        email: 'trader.kudirat@gmail.com',
        displayName: 'Alhaja Kudirat',
        role: 'Trader',
        businessName: 'Kudirat Grains Bodija',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        stallLocation: 'Stall B44, Bodija Market Wholesale Hub',
        isGuest: false,
      );

      SharedPreferences.setMockInitialValues({
        'smartmove_user_session': jsonEncode(user.toJson()),
      });

      // 1. Instant local read has zero latency and returns the trader
      final localSession = await AuthService.getPersistedSessionOnly();
      expect(localSession, isNotNull);
      expect(localSession!.isGuest, isFalse);
      expect(localSession.role, 'Trader');
      expect(localSession.displayName, 'Alhaja Kudirat');
      expect(localSession.businessName, 'Kudirat Grains Bodija');

      // 2. Full restore when offline preserves the cached trader
      final restored = await AuthService.restorePersistedSession();
      expect(restored.isGuest, isFalse);
      expect(restored.role, 'Trader');
      expect(restored.email, 'trader.kudirat@gmail.com');
    });

    test('AuthNotifier boots with preloaded authenticated session on frame 0', () async {
      final user = UserSession(
        id: 'usr-admin-01',
        email: 'superadmin@smartmove.app',
        displayName: 'Chief Moderator',
        role: 'SuperAdmin',
        isGuest: false,
      );

      final notifier = AuthNotifier(user);
      expect(notifier.build().isGuest, isFalse);
      expect(notifier.build().role, 'SuperAdmin');
      expect(notifier.build().isSuperAdmin, isTrue);
    });

    test('signInWithEmail gracefully falls back to offline authenticated session on network outage', () async {
      SharedPreferences.setMockInitialValues({});

      final session = await AuthService.signInWithEmail(
        email: 'trader.bodija@test.com',
        password: 'password123',
      );

      expect(session.isGuest, isFalse);
      expect(session.role, 'Trader');
      expect(session.email, 'trader.bodija@test.com');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('smartmove_user_session'), contains('trader.bodija@test.com'));
    });
  });

  group('Legal Screens & Compliance Navigation Tests', () {
    Widget buildTestApp({String initialLocation = '/legal'}) {
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/legal',
            builder: (context, state) {
              final tabParam = state.uri.queryParameters['tab'];
              return LegalScreen(initialTab: tabParam);
            },
          ),
          GoRoute(
            path: '/auth',
            builder: (context, state) => const AuthScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      );

      return ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('LegalScreen displays all 3 tabs: Terms, Privacy, Fair Trade Rules', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildTestApp(initialLocation: '/legal'));
      await tester.pumpAndSettle();

      // Verify Tab titles
      expect(find.text('Terms of Service'), findsWidgets);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Market Fair Trade Rules'), findsWidgets);

      // Verify Terms content
      expect(find.textContaining('Federal Competition and Consumer Protection Act'), findsOneWidget);
      expect(find.textContaining('FCCPC Compliant'), findsOneWidget);

      // Switch to Privacy Policy tab
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nigeria Data Protection Act (NDPA 2023)'), findsOneWidget);
      expect(find.textContaining('Strict Non-Collection of Financial Credentials'), findsOneWidget);

      // Switch to Fair Trade tab
      await tester.tap(find.text('Market Fair Trade Rules'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Standardized Commodity Measurement Units'), findsOneWidget);
      expect(find.textContaining('Derica'), findsOneWidget);

      // Tap "I Understand & Accept"
      final acceptBtn = find.byKey(const ValueKey('btn_accept_legal_terms'));
      expect(acceptBtn, findsOneWidget);
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      expect(find.text('Terms & Privacy Policy acknowledged.'), findsOneWidget);
    });

    testWidgets('LegalScreen initialTab query parameter opens specific tab directly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildTestApp(initialLocation: '/legal?tab=privacy'));
      await tester.pumpAndSettle();

      // Opens directly to Privacy tab
      expect(find.textContaining('NDPA 2023 Compliant'), findsOneWidget);
    });

    testWidgets('AuthScreen has clickable links to Terms of Service & Privacy Policy', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildTestApp(initialLocation: '/auth'));
      await tester.pumpAndSettle();

      // Find Terms link
      final termsLink = find.byKey(const ValueKey('btn_auth_terms_link'));
      expect(termsLink, findsOneWidget);
      await tester.tap(termsLink);
      await tester.pumpAndSettle();

      // Navigated to /legal with Terms
      expect(find.textContaining('FCCPC Compliant'), findsOneWidget);
    });

    testWidgets('ProfileScreen has Legal & Terms menu item that navigates to LegalScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({
        'smartmove_app_language': 'English',
      });

      await tester.pumpWidget(buildTestApp(initialLocation: '/profile'));
      await tester.pumpAndSettle();

      final legalTile = find.byKey(const ValueKey('menu_legal_terms'));
      expect(legalTile, findsOneWidget);
      await tester.tap(legalTile);
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsWidgets);
    });
  });

  group('Deep Multi-Screen Language Translation Tests', () {
    testWidgets('HomeScreen greeting and titles update dynamically when language changes', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({
        'smartmove_app_language': 'English',
      });

      Widget buildHomeApp() {
        return const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        );
      }

      await tester.pumpWidget(buildHomeApp());
      await tester.pumpAndSettle();

      // Initially English
      expect(find.text('Commodity Price Optimizer'), findsOneWidget);
      expect(find.text('No active shopping options yet'), findsOneWidget);

      final element = tester.element(find.byType(HomeScreen));
      final container = ProviderScope.containerOf(element);

      // Switch to Yorùbá
      await container.read(appLanguageProvider.notifier).setLanguage('Yorùbá');
      await tester.pumpAndSettle();

      expect(find.text('Ètò Iye Owó Ọjà'), findsOneWidget);
      expect(find.text('Kò sí àwọn àṣàyàn rírà tí ó wà'), findsOneWidget);

      // Switch to Hausa
      await container.read(appLanguageProvider.notifier).setLanguage('Hausa');
      await tester.pumpAndSettle();

      expect(find.text('Mai Kula Da Farashin Kaya'), findsOneWidget);
      expect(find.text('Babu zaɓin sayayya mai aiki tukuna'), findsOneWidget);

      // Switch to Asụsụ Igbo
      await container.read(appLanguageProvider.notifier).setLanguage('Asụsụ Igbo');
      await tester.pumpAndSettle();

      expect(find.text('Nkwalite Ọnụahịa Ngwa Ahịa'), findsOneWidget);
      expect(find.text('Enweghị nhọrọ ịzụ ahịa na-arụ ọrụ ma'), findsOneWidget);
    });
  });
}

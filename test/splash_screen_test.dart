import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/services/guide_service.dart';
import 'package:smartmove/features/splash/presentation/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({required String initialLocation}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(
            body: Text('Home Screen Loaded'),
          ),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const Scaffold(
            body: Text('Onboarding Screen Loaded'),
          ),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('SplashScreen Guide & Routing Tests', () {
    testWidgets('Shows start guide buttons when user has not seen guide yet', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildTestApp(initialLocation: '/'));
      await tester.pumpAndSettle();

      // Should display the guide content and "Get Started" / "Skip to Home"
      expect(find.text('SmartMove'), findsWidgets);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip to Home'), findsOneWidget);
      expect(find.text('Market Price Intelligence'), findsOneWidget);
      expect(find.byKey(const ValueKey('splash_language_selection_banner')), findsOneWidget);
    });

    testWidgets('Automatically routes to /home when user has already completed/seen the guide', (tester) async {
      SharedPreferences.setMockInitialValues({
        'smartmove_has_seen_start_guide_v1': true,
      });

      await tester.pumpWidget(buildTestApp(initialLocation: '/'));
      await tester.pumpAndSettle();

      // Should have automatically transitioned to Home Screen
      expect(find.text('Home Screen Loaded'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
    });

    testWidgets('Tapping "Skip to Home" marks guide as seen and navigates to /home', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildTestApp(initialLocation: '/'));
      await tester.pumpAndSettle();

      final skipButton = find.text('Skip to Home');
      expect(skipButton, findsOneWidget);
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      expect(find.text('Home Screen Loaded'), findsOneWidget);
      expect(await GuideService.hasSeenGuide(), isTrue);
    });

    testWidgets('Tapping Change on splash screen opens LanguageSelectionSheet and allows selecting Hausa', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildTestApp(initialLocation: '/'));
      await tester.pumpAndSettle();

      final changeBtn = find.byKey(const ValueKey('btn_select_language_splash'));
      expect(changeBtn, findsOneWidget);
      await tester.tap(changeBtn);
      await tester.pumpAndSettle();

      // Sheet is visible with first-launch greeting
      expect(find.textContaining('Barka da zuwa'), findsWidgets);
      expect(find.byKey(const ValueKey('lang_option_Hausa')), findsOneWidget);

      // Select Hausa
      await tester.tap(find.byKey(const ValueKey('lang_option_Hausa')));
      await tester.pumpAndSettle();

      // Splash banner updates to Hausa
      expect(find.text('Preferred Language: Hausa'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('smartmove_app_language'), 'Hausa');
      expect(prefs.getBool('smartmove_first_language_chosen_v1'), isTrue);
    });

    testWidgets('Tapping Get Started on first launch opens language selection before onboarding', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildTestApp(initialLocation: '/'));
      await tester.pumpAndSettle();

      final getStartedBtn = find.text('Get Started');
      expect(getStartedBtn, findsOneWidget);
      await tester.tap(getStartedBtn);
      await tester.pumpAndSettle();

      // Language selection sheet pops up on first launch
      expect(find.byKey(const ValueKey('lang_option_Yorùbá')), findsOneWidget);

      // Select Yorùbá
      await tester.tap(find.byKey(const ValueKey('lang_option_Yorùbá')));
      await tester.pumpAndSettle();

      // Now reaches Onboarding
      expect(find.text('Onboarding Screen Loaded'), findsOneWidget);
    });
  });
}

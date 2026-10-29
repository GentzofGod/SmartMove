import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    return MaterialApp.router(
      routerConfig: router,
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
  });
}

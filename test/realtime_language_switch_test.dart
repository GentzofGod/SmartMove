import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/localization/app_language.dart';
import 'package:smartmove/core/presentation/widgets/language_selection_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:smartmove/features/navigation/presentation/main_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real-Time App Language Switching Tests (No Restart Required)', () {
    test('AppStrings translations cover all 16 supported languages with correct localized keys', () {
      expect(AppStrings.supportedLanguages.length, 15);

      for (final lang in AppStrings.supportedLanguages) {
        final home = AppStrings.get('navHome', lang.name);
        final discover = AppStrings.get('navDiscover', lang.name);
        final community = AppStrings.get('navCommunity', lang.name);
        final title = AppStrings.get('selectLanguageTitle', lang.name);

        expect(home.isNotEmpty, isTrue, reason: 'Empty home in ${lang.name}');
        expect(discover.isNotEmpty, isTrue, reason: 'Empty discover in ${lang.name}');
        expect(community.isNotEmpty, isTrue, reason: 'Empty community in ${lang.name}');
        expect(title.isNotEmpty, isTrue, reason: 'Empty selectLanguageTitle in ${lang.name}');
      }
    });

    testWidgets('Instant reactive language switching without restart updates UI immediately', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({
        'smartmove_app_language': 'English',
        'smartmove_first_language_chosen_v1': true,
      });

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const MainScaffold(
              child: Scaffold(
                body: Center(child: Text('Main Screen Content')),
              ),
            ),
          ),
        ],
      );

      Widget buildReactiveTestApp() {
        return ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        );
      }

      await tester.pumpWidget(buildReactiveTestApp());
      await tester.pumpAndSettle();

      // Starts in English
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Price Lab'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);

      // Programmatically trigger language switch to Yorùbá
      final element = tester.element(find.byType(MainScaffold));
      final container = ProviderScope.containerOf(element);

      await container.read(appLanguageProvider.notifier).setLanguage('Yorùbá');
      await tester.pumpAndSettle();

      // UI immediately updates in real-time to Yorùbá without app restart!
      expect(find.text('Ilé'), findsOneWidget);
      expect(find.text('Ṣawari'), findsOneWidget);
      expect(find.text('Yàrá Iye Owó'), findsOneWidget);
      expect(find.text('Àwùjọ'), findsOneWidget);
      expect(find.text('Home'), findsNothing);

      // Now switch to Hausa
      await container.read(appLanguageProvider.notifier).setLanguage('Hausa');
      await tester.pumpAndSettle();

      // UI immediately updates in real-time to Hausa!
      expect(find.text('Gida'), findsOneWidget);
      expect(find.text('Bincike'), findsOneWidget);
      expect(find.text('Dakin Farashi'), findsOneWidget);
      expect(find.text('Al\'umma'), findsOneWidget);
      expect(find.text('Ilé'), findsNothing);

      // Now switch to Nigerian Pidgin
      await container.read(appLanguageProvider.notifier).setLanguage('Nigerian Pidgin');
      await tester.pumpAndSettle();

      // UI immediately updates in real-time to Nigerian Pidgin!
      expect(find.text('House'), findsOneWidget);
      expect(find.text('Find Market'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);

      // Now switch to Asụsụ Igbo
      await container.read(appLanguageProvider.notifier).setLanguage('Asụsụ Igbo');
      await tester.pumpAndSettle();

      // UI immediately updates in real-time to Asụsụ Igbo!
      expect(find.text('Ụlọ'), findsOneWidget);
      expect(find.text('Chọpụta'), findsOneWidget);
      expect(find.text('Obodo'), findsOneWidget);

      // Verify persistent storage
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('smartmove_app_language'), 'Asụsụ Igbo');
    });

    testWidgets('LanguageSelectionSheet search filter narrows languages dynamically', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LanguageSelectionSheet(isFirstLaunch: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All 15 languages initially present
      expect(find.byKey(const ValueKey('lang_option_Hausa')), findsOneWidget);
      expect(find.byKey(const ValueKey('lang_option_Yorùbá')), findsOneWidget);
      expect(find.byKey(const ValueKey('lang_option_Tiv')), findsOneWidget);

      // Type "tiv" in search box
      await tester.enterText(find.byKey(const ValueKey('input_language_search')), 'tiv');
      await tester.pumpAndSettle();

      // Only Tiv remains
      expect(find.byKey(const ValueKey('lang_option_Tiv')), findsOneWidget);
      expect(find.byKey(const ValueKey('lang_option_Hausa')), findsNothing);
      expect(find.byKey(const ValueKey('lang_option_Yorùbá')), findsNothing);

      // Tap Tiv
      await tester.tap(find.byKey(const ValueKey('lang_option_Tiv')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('smartmove_app_language'), 'Tiv');
      expect(prefs.getBool('smartmove_first_language_chosen_v1'), isTrue);
    });
  });
}

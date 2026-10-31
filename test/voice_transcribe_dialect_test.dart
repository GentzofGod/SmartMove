import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/features/home/presentation/widgets/muse_voice_input_sheet.dart';

void main() {
  group('Meta Muse Voice Transcribe Multi-Dialect Unit Tests', () {
    const aiService = MetaAiService();

    test('1. Dialect Enum defines authentic West African languages & codes', () {
      expect(VoiceDialect.autoDetect.languageCode, 'auto');
      expect(VoiceDialect.nigerianPidgin.languageCode, 'pcm');
      expect(VoiceDialect.yoruba.languageCode, 'yo');
      expect(VoiceDialect.hausa.languageCode, 'ha');
      expect(VoiceDialect.igbo.languageCode, 'ig');
      expect(VoiceDialect.nigerianEnglish.languageCode, 'en-NG');
    });

    test('2. detectDialect correctly identifies vernacular speech text', () {
      // Pidgin
      expect(
        aiService.detectDialect(
            'I get ₦15,000. I wan buy two paint rubber of garri for Bodija market'),
        VoiceDialect.nigerianPidgin,
      );

      // Yoruba
      expect(
        aiService.detectDialect(
            'Mo ní ẹgbẹ̀rún mẹ́ẹ̀ẹ́dógún náírà. Mo fẹ́ ra àpò ìrẹsì kan àti epo pupa ní ọjà Bodija'),
        VoiceDialect.yoruba,
      );

      // Hausa
      expect(
        aiService.detectDialect(
            'Ina da naira dubu goma sha biyar. Ina son in sayi buhun shinkafa da kwai a kasuwar Wuse'),
        VoiceDialect.hausa,
      );

      // Igbo
      expect(
        aiService.detectDialect(
            'Enwere m puku naira iri na ise. Achọrọ m ịzụ akpa osikapa na àkwá na mmanụ nri na ahịa'),
        VoiceDialect.igbo,
      );

      // English
      expect(
        aiService.detectDialect(
            'I have ₦15,000 budget for rice, eggs, tomatoes, and vegetable oil in Bodija'),
        VoiceDialect.nigerianEnglish,
      );
    });

    test('3. transcribeAudio auto-detects and provides English translation for vernaculars', () async {
      final yorubaResult = await aiService.transcribeAudio(
        dialect: VoiceDialect.yoruba,
      );

      expect(yorubaResult.detectedDialect, VoiceDialect.yoruba);
      expect(yorubaResult.isDialectTranslated, true);
      expect(yorubaResult.englishTranslation, isNotNull);
      expect(yorubaResult.englishTranslation!.contains('₦15,000'), true);
      expect(yorubaResult.englishTranslation!.toLowerCase().contains('rice'), true);

      final pidginResult = await aiService.transcribeAudio(
        dialect: VoiceDialect.nigerianPidgin,
      );

      expect(pidginResult.detectedDialect, VoiceDialect.nigerianPidgin);
      expect(pidginResult.isDialectTranslated, true);
      expect(pidginResult.englishTranslation, isNotNull);
      expect(pidginResult.englishTranslation!.contains('₦15,000'), true);
    });

    test('4. parseToProposal extracts commodities, units, and budgets from Nigerian Pidgin', () async {
      final pidginPrompt =
          'I get ₦15,000. I wan buy two paint rubber of garri, one bag of rice, and cooking oil for Bodija market make e no pass my budget.';
      final proposal = await aiService.parseToProposal(pidginPrompt);

      expect(proposal.budget, 15000.0);
      expect(proposal.shoppingItems.isNotEmpty, true);

      final garri = proposal.shoppingItems.firstWhere((i) => i.productName == 'Garri');
      expect(garri.quantity, 2.0);
      expect(garri.unit, 'paint rubber');

      final rice = proposal.shoppingItems.firstWhere((i) => i.productName == 'Rice');
      expect(rice.quantity, 1.0);
      expect(rice.unit, 'bag');

      final oil = proposal.shoppingItems.firstWhere((i) => i.productName == 'Cooking Oil');
      expect(oil.quantity, 1.0);
      expect(oil.unit, 'L');
    });

    test('5. parseToProposal extracts commodities, units, and deadlines from Yorùbá', () async {
      final yorubaPrompt =
          'Mo ní ẹgbẹ̀rún mẹ́ẹ̀ẹ́dógún náírà. Mo fẹ́ ra àpò ìrẹsì kan, ẹyin, àti epo pupa ní ọjà Bodija kí n tó gba ẹrù mi ní aago méjì.';
      final proposal = await aiService.parseToProposal(yorubaPrompt);

      expect(proposal.budget, 15000.0);
      expect(proposal.shoppingItems.isNotEmpty, true);

      final rice = proposal.shoppingItems.firstWhere((i) => i.productName == 'Rice');
      expect(rice.quantity, 1.0);
      expect(rice.unit, 'bag');

      final eggs = proposal.shoppingItems.firstWhere((i) => i.productName == 'Eggs');
      expect(eggs.quantity, 1.0);
      expect(eggs.unit, 'crate');

      final palmOil = proposal.shoppingItems.firstWhere((i) => i.productName == 'Palm Oil');
      expect(palmOil.quantity, 1.0);
      expect(palmOil.unit, 'L');

      expect(proposal.deadlineErrand, isNotNull);
      expect(proposal.deadlineErrand!.deadline, '2:00 PM');
    });

    test('6. parseToProposal extracts commodities and deadlines from Hausa', () async {
      final hausaPrompt =
          'Ina da naira dubu goma sha biyar. Ina son in sayi buhun shinkafa da kwai da manja a kasuwar Wuse kafin karfe biyu.';
      final proposal = await aiService.parseToProposal(hausaPrompt);

      expect(proposal.budget, 15000.0);
      expect(proposal.shoppingItems.isNotEmpty, true);

      final rice = proposal.shoppingItems.firstWhere((i) => i.productName == 'Rice');
      expect(rice.quantity, 1.0);
      expect(rice.unit, 'bag');

      final eggs = proposal.shoppingItems.firstWhere((i) => i.productName == 'Eggs');
      expect(eggs.quantity, 1.0);
      expect(eggs.unit, 'crate');

      final palmOil = proposal.shoppingItems.firstWhere((i) => i.productName == 'Palm Oil');
      expect(palmOil.quantity, 1.0);
      expect(palmOil.unit, 'L');

      expect(proposal.deadlineErrand, isNotNull);
      expect(proposal.deadlineErrand!.deadline, '2:00 PM');
    });

    test('7. parseToProposal extracts commodities and deadlines from Asụsụ Igbo', () async {
      final igboPrompt =
          'Enwere m puku naira iri na ise. Achọrọ m ịzụ akpa osikapa na àkwá na mmanụ nri na ahịa tupu elekere abụọ nke ehihie.';
      final proposal = await aiService.parseToProposal(igboPrompt);

      expect(proposal.budget, 15000.0);
      expect(proposal.shoppingItems.isNotEmpty, true);

      final rice = proposal.shoppingItems.firstWhere((i) => i.productName == 'Rice');
      expect(rice.quantity, 1.0);
      expect(rice.unit, 'bag');

      final eggs = proposal.shoppingItems.firstWhere((i) => i.productName == 'Eggs');
      expect(eggs.quantity, 1.0);
      expect(eggs.unit, 'crate');

      final palmOil = proposal.shoppingItems.firstWhere((i) => i.productName == 'Palm Oil');
      expect(palmOil.quantity, 1.0);
      expect(palmOil.unit, 'L');

      expect(proposal.deadlineErrand, isNotNull);
      expect(proposal.deadlineErrand!.deadline, '2:00 PM');
    });
  });

  group('MuseVoiceInputSheet Multi-Dialect Widget Tests', () {
    testWidgets('8. Renders dialect chips and allows switching active dialect', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? confirmedTranscript;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MuseVoiceInputSheet(
              onTranscriptConfirmed: (text) => confirmedTranscript = text,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Muse Voice Transcribe'), findsOneWidget);
      expect(find.text('Multi-Dialect West African Speech-to-Text Model'), findsOneWidget);

      // Verify Dialect Chips exist
      expect(find.byKey(const ValueKey('chip_dialect_auto')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_dialect_pcm')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_dialect_yo')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_dialect_ha')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_dialect_ig')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_dialect_en-NG')), findsOneWidget);

      // Select Yorùbá chip
      await tester.tap(find.byKey(const ValueKey('chip_dialect_yo')));
      await tester.pumpAndSettle();

      // Verify Yorùbá language code indicator
      expect(find.text('YO'), findsOneWidget);

      // Tap "Test Sample" button for Yorùbá
      await tester.tap(find.byKey(const ValueKey('btn_simulate_dialect_voice')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify Transcribed Request and English Translation card are shown
      expect(find.text('Transcribed Request:'), findsOneWidget);
      expect(find.text('English Translation (Yorùbá):'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_use_translation')), findsOneWidget);

      // Tap "Use Translation"
      await tester.tap(find.byKey(const ValueKey('btn_use_translation')));
      await tester.pumpAndSettle();

      // Scroll and Tap "Generate Plan Proposal"
      final proposalBtn = find.byKey(const ValueKey('btn_generate_plan_proposal'));
      await tester.ensureVisible(proposalBtn);
      await tester.pumpAndSettle();
      await tester.tap(proposalBtn);
      await tester.pumpAndSettle();

      expect(confirmedTranscript, isNotNull);
      expect(confirmedTranscript!.toLowerCase().contains('rice'), true);
      expect(confirmedTranscript!.contains('₦15,000'), true);
    });

    testWidgets('9. Push-to-talk recording flow clears fallback to empty and allows direct text input', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? confirmedTranscript;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MuseVoiceInputSheet(
              onTranscriptConfirmed: (text) => confirmedTranscript = text,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Nigerian Pidgin
      await tester.tap(find.byKey(const ValueKey('chip_dialect_pcm')));
      await tester.pumpAndSettle();

      expect(find.text('PCM'), findsOneWidget);

      // Tap recording button to start
      await tester.tap(find.byKey(const ValueKey('voice_record_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Listening in Nigerian Pidgin'), findsOneWidget);

      // Tap again to stop and transcribe
      await tester.tap(find.byKey(const ValueKey('voice_record_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      // Verify that fallback is cleared to empty string and user-friendly error is shown
      expect(
        find.text('Voice input unavailable. Please type your request directly below.'),
        findsOneWidget,
      );

      // Enter shopping request manually without having to delete canned mock text
      await tester.enterText(
        find.byType(TextField),
        '2 paint rubber of garri and 1 bag of rice',
      );
      await tester.pumpAndSettle();

      // Scroll and Tap Generate proposal
      final proposalBtn = find.byKey(const ValueKey('btn_generate_plan_proposal'));
      await tester.ensureVisible(proposalBtn);
      await tester.pumpAndSettle();
      await tester.tap(proposalBtn);
      await tester.pumpAndSettle();

      expect(confirmedTranscript, isNotNull);
      expect(confirmedTranscript!.contains('paint rubber of garri'), true);
    });
  });
}

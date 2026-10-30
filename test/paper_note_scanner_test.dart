import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/features/home/presentation/widgets/paper_note_scanner_sheet.dart';
import 'package:smartmove/features/home/presentation/widgets/meta_ai_scenario_card.dart';
import 'package:smartmove/features/discover/presentation/discover_screen.dart';

void main() {
  group('Meta Muse Spark Vision - Handwritten Paper Note Parsing Unit Tests', () {
    const aiService = MetaAiService();

    test('1. Default sample notes define authentic Nigerian paper lists & budgets', () {
      expect(SamplePaperNote.defaultSamples.length, 3);

      final bodija = SamplePaperNote.defaultSamples
          .firstWhere((s) => s.id == 'sample_bodija');
      expect(bodija.title, 'Bodija Market Foodstuffs');
      expect(bodija.suggestedBudget, 25000.0);
      expect(bodija.handwrittenContent.contains('Mama Gold'), true);
      expect(bodija.recognizedLines.isNotEmpty, true);

      final pantry = SamplePaperNote.defaultSamples
          .firstWhere((s) => s.id == 'sample_pantry');
      expect(pantry.title, 'Household Pantry Restock');
      expect(pantry.suggestedBudget, 18000.0);

      final vernacular = SamplePaperNote.defaultSamples
          .firstWhere((s) => s.id == 'sample_vernacular');
      expect(vernacular.title, 'Naija Market Paper Scrap');
      expect(vernacular.suggestedBudget, 22000.0);
    });

    test('2. parsePaperNoteImage correctly extracts commodities from Bodija paper note', () async {
      final result = await aiService.parsePaperNoteImage(
        simulatedNoteId: 'sample_bodija',
      );

      expect(result.modelName, 'Meta Muse Spark 1.3 (Vision)');
      expect(result.confidence >= 0.95, true);
      expect(result.proposal.budget, 25000.0);
      expect(result.proposal.shoppingItems.isNotEmpty, true);

      // Verify Rice
      final rice = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Rice');
      expect(rice.quantity, 5.0);
      expect(rice.unit, 'kg');
      expect(rice.brandOrGrade, isNotNull);
      expect(rice.brandOrGrade!.contains('Mama Gold'), true);

      // Verify Garri
      final garri = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Garri');
      expect(garri.quantity, 2.0);
      expect(garri.unit, 'paint rubber');

      // Verify Eggs
      final eggs = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Eggs');
      expect(eggs.quantity, 1.0);
      expect(eggs.unit, 'crate');

      // Verify Cooking Oil
      final oil = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Cooking Oil');
      expect(oil.quantity, 2.0);
      expect(oil.unit, 'L');
      expect(oil.brandOrGrade, isNotNull);
      expect(oil.brandOrGrade!.contains('Kings'), true);
    });

    test('3. parsePaperNoteImage correctly extracts provisions from Pantry restock note', () async {
      final result = await aiService.parsePaperNoteImage(
        simulatedNoteId: 'sample_pantry',
      );

      expect(result.proposal.budget, 18000.0);

      // Verify Indomie
      final noodles = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Indomie Noodles');
      expect(noodles.quantity, 1.0);
      expect(noodles.unit, 'carton');

      // Verify Bread
      final bread = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Sliced Bread');
      expect(bread.quantity, 2.0);
      expect(bread.unit, 'loaf');

      // Verify Milk
      final milk = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Evaporated Milk');
      expect(milk.quantity, 2.0);
      expect(milk.unit, 'tin');
    });

    test('4. parsePaperNoteImage correctly extracts vernacular Pidgin market scrap', () async {
      final result = await aiService.parsePaperNoteImage(
        simulatedNoteId: 'sample_vernacular',
      );

      expect(result.proposal.budget, 22000.0);

      final garri = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Garri');
      expect(garri.quantity, 2.0);
      expect(garri.unit, 'paint rubber');

      final rice = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Rice');
      expect(rice.quantity, 1.0);
      expect(rice.unit, 'bag');

      final palmOil = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Palm Oil');
      expect(palmOil.quantity, 2.0);
      expect(palmOil.unit, 'L');
    });

    test('5. parsePaperNoteImage supports raw custom handwritten note text & byte inputs', () async {
      final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final result = await aiService.parsePaperNoteImage(
        imageBytes: dummyBytes,
        customNoteText:
            'Handwritten Note:\n1. 10kg Rice\n2. 2 crates Eggs\n3. 3L Cooking Oil\nBudget: ₦30,000',
      );

      expect(result.proposal.budget, 30000.0);
      expect(result.noteTitle, 'Custom Paper Note');
      expect(result.extractedLines.length >= 4, true);

      final rice = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Rice');
      expect(rice.quantity, 10.0);

      final eggs = result.proposal.shoppingItems
          .firstWhere((i) => i.productName == 'Eggs');
      expect(eggs.quantity, 2.0);
      expect(eggs.unit, 'crate');
    });
  });

  group('PaperNoteScannerSheet Widget Tests', () {
    testWidgets('6. Renders paper scanner sheet, switches samples, and parses note', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? confirmedTranscript;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaperNoteScannerSheet(
              onTranscriptConfirmed: (text) => confirmedTranscript = text,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Scan Paper Shopping List'), findsOneWidget);
      expect(find.text('Meta Muse Spark Multimodal Vision Model'), findsOneWidget);

      // Verify Action Buttons
      expect(find.byKey(const ValueKey('btn_take_camera_photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_choose_gallery_photo')), findsOneWidget);

      // Verify Preset Sample Note Chips
      expect(find.byKey(const ValueKey('chip_sample_sample_bodija')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_sample_sample_pantry')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_sample_sample_vernacular')), findsOneWidget);

      // Select Household Pantry Restock Note
      await tester.tap(find.byKey(const ValueKey('chip_sample_sample_pantry')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify note content preview
      expect(find.textContaining('Pantry Restock'), findsWidgets);

      // Verify parse button and tap it
      final parseBtn = find.byKey(const ValueKey('btn_analyze_paper_note'));
      await tester.ensureVisible(parseBtn);
      await tester.tap(parseBtn);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify Recognized Commodities list is shown
      expect(find.textContaining('Recognized Commodities'), findsOneWidget);
      expect(find.text('Indomie Noodles'), findsOneWidget);
      expect(find.text('Sliced Bread'), findsOneWidget);

      // Scroll and Tap "Generate Plan Proposal from Note"
      final generateBtn = find.byKey(const ValueKey('btn_generate_plan_from_paper'));
      await tester.ensureVisible(generateBtn);
      await tester.tap(generateBtn);
      await tester.pumpAndSettle();

      expect(confirmedTranscript, isNotNull);
      expect(confirmedTranscript!.toLowerCase().contains('indomie'), true);
      expect(confirmedTranscript!.contains('₦18,000'), true);
    });

    testWidgets('7. MetaAiScenarioCard opens paper note scanner from scan button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MetaAiScenarioCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header updated to Muse Spark, Voice & Vision
      expect(find.text('Muse Spark, Voice & Vision'), findsOneWidget);

      // Verify Scan Paper Note button exists
      final scanBtn = find.byKey(const ValueKey('btn_scan_paper_note'));
      expect(scanBtn, findsOneWidget);

      // Tap scan button
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      // Verify PaperNoteScannerSheet opened
      expect(find.text('Scan Paper Shopping List'), findsOneWidget);
    });

    testWidgets('8. DiscoverScreen provides quick paper note scan button in search bar', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiscoverScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify scan paper note button in search bar
      final discoverScanBtn = find.byKey(const ValueKey('btn_discover_scan_paper_note'));
      expect(discoverScanBtn, findsOneWidget);

      // Tap button to open scanner
      await tester.tap(discoverScanBtn);
      await tester.pumpAndSettle();

      expect(find.text('Scan Paper Shopping List'), findsOneWidget);
    });
  });
}


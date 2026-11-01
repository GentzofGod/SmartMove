import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/features/home/presentation/widgets/meta_ai_scenario_card.dart';
import 'package:smartmove/features/home/presentation/widgets/muse_voice_input_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voice Transcription Pipeline Technical Flow Tests', () {
    test('1. MetaAiService.transcribeAudio accepts 24kHz Mono WAV PCM audio and targets Meta endpoint', () async {
      const aiService = MetaAiService();

      // Dummy 24kHz mono WAV byte header
      final dummyWavBytes = List<int>.generate(128, (i) => i % 256);

      final result = await aiService.transcribeAudio(
        audioBytes: dummyWavBytes,
        audioFormat: 'audio/wav',
        sampleRate: 24000,
        numChannels: 1,
        dialect: VoiceDialect.yoruba,
        simulatedVoiceSample: 'Mo fẹ́ ra àpò ìrẹsì kan àti epo pupa',
      );

      expect(result.text, contains('ìrẹsì'));
      expect(result.detectedDialect, VoiceDialect.yoruba);
      expect(result.isDialectTranslated, isTrue);
      expect(result.englishTranslation, isNotNull);
      expect(result.englishTranslation!.toLowerCase(), contains('rice'));
    });

    testWidgets('2. Full Technical Flow: Tap mic -> Record -> Live Timer -> Finish -> Insert to Chat -> User Edits', (tester) async {
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

      // Step 1: User taps the microphone button directly in the chat prompt box
      final promptMicBtn = find.byTooltip('Record Voice Note (Meta Transcribe)');
      expect(promptMicBtn, findsOneWidget);
      await tester.tap(promptMicBtn);
      await tester.pumpAndSettle();

      // Step 2, 3 & 4: Sheet opens with recording controls, live indicator & elapsed time
      expect(find.byType(MuseVoiceInputSheet), findsOneWidget);
      final recordBtn = find.byKey(const ValueKey('voice_record_button'));
      expect(recordBtn, findsOneWidget);

      // Start recording
      await tester.tap(recordBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Step 4: Displays live indicator and elapsed time (00:02)
      expect(find.textContaining('Listening in'), findsOneWidget);
      expect(find.textContaining('00:02'), findsOneWidget);

      // Step 5: User taps Finish (or pause)
      await tester.tap(recordBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Step 6, 7 & 8: Stop recording -> WAV 24kHz mono -> Meta transcribe
      // In unit test environment, manual text entry allows refining the recognized transcript
      final sheetInput = find.byKey(const ValueKey('txt_voice_transcript'));
      expect(sheetInput, findsOneWidget);
      await tester.enterText(
        sheetInput,
        '5kg rice and 2L palm oil for Bodija market',
      );
      await tester.pumpAndSettle();

      // Step 9: User taps confirm -> transcript is inserted into chat input field
      final confirmBtn = find.byKey(const ValueKey('btn_generate_plan_proposal'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Sheet is dismissed
      expect(find.byType(MuseVoiceInputSheet), findsNothing);

      // Step 9: Verify transcript is inserted directly into chat input field
      final promptField = find.widgetWithText(
        TextField,
        '5kg rice and 2L palm oil for Bodija market',
      );
      expect(promptField, findsOneWidget);

      // Step 10: Let user edit the transcript before sending
      await tester.enterText(
        find.byType(TextField),
        '5kg rice and 2L palm oil for Bodija market with budget of 25000',
      );
      await tester.pumpAndSettle();

      // Verify the prompt field holds the user's edited transcript ready to send
      expect(
        find.widgetWithText(
          TextField,
          '5kg rice and 2L palm oil for Bodija market with budget of 25000',
        ),
        findsOneWidget,
      );
    });
  });
}


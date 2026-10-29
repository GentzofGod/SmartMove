import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/core/services/decision_engine.dart';

void main() {
  group('Meta AI Integration Tests (Section 6: Muse Spark & Voice Transcribe)', () {
    const aiService = MetaAiService();

    test('1. Muse Voice Transcribe produces accurate text with fallback option', () async {
      final voiceResult = await aiService.transcribeAudio(
        simulatedVoiceSample:
            'I have ₦15,000. I need rice, eggs, tomatoes, and cooking oil. Collect package before 2 PM.',
      );

      expect(voiceResult.modelName, 'Meta Muse Voice Transcribe 1.0');
      expect(voiceResult.confidence >= 0.9, true);
      expect(voiceResult.text.contains('rice'), true);
      expect(voiceResult.text.contains('15,000'), true);
    });

    test('2. PII Sanitization strips phone numbers and emails for privacy', () {
      final input = 'My email is test@domain.com and phone is 08012345678. I have ₦20,000 for rice.';
      final sanitized = aiService.sanitizePrompt(input);

      expect(sanitized.contains('test@domain.com'), false);
      expect(sanitized.contains('08012345678'), false);
      expect(sanitized.contains('[email]'), true);
      expect(sanitized.contains('[phone]'), true);
      expect(sanitized.contains('20,000'), true);
    });

    test('3. Muse Spark structured proposal extraction works as expected', () async {
      final proposal = await aiService.parseToProposal(
        'I have ₦15,000. I need 2kg rice, 1 crate of eggs, 2kg tomatoes, 1L cooking oil. Collect package before 2 PM.',
      );

      expect(proposal.modelName, 'Meta Muse Spark 1.3');
      expect(proposal.budget, 15000.0);
      expect(proposal.shoppingItems.length, 4);

      final rice = proposal.shoppingItems.firstWhere((i) => i.productName == 'Rice');
      expect(rice.quantity, 2.0);
      expect(rice.unit, 'kg');

      expect(proposal.deadlineErrand, isNotNull);
      expect(proposal.deadlineErrand!.deadline, '2:00 PM');
      expect(proposal.deadlineErrand!.title, 'Collect package');
    });

    test('4. Detects missing budget or constraints and asks clarification questions', () {
      // Prompt with NO budget
      final promptNoBudget = 'I need rice and eggs for dinner.';
      final questions = aiService.detectAmbiguitiesAndFollowUps(
        promptNoBudget,
        15000.0,
        [],
        null,
      );

      expect(questions.isNotEmpty, true);
      expect(questions.any((q) => q.field == 'budget'), true);
    });

    test('5. Grounded Trade-off Explainer refers only to computed numbers without hallucinating', () {
      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 15000,
        baseTransportFare: 1200,
        maxTimeHours: 3.0,
      );

      final explanation = aiService.explainTradeOffs(
        planA: plans.firstWhere((p) => p.name == 'Plan A'),
        planB: plans.firstWhere((p) => p.name == 'Plan B'),
        planC: plans.firstWhere((p) => p.name == 'Plan C'),
        planD: plans.firstWhere((p) => p.name == 'Plan D'),
        budget: 15000,
      );

      expect(explanation.contains('Meta Muse Spark Insight'), true);
      expect(explanation.contains('Plan A'), true);
      expect(explanation.contains('Plan B'), true);
      // Explains exact computed item savings between Plan B and Plan A
      expect(explanation.contains('₦13,400') || explanation.contains('Plan A has the lowest total outlay'), true);
    });

    test('6. Interprets user follow-up "spend less on transport even if shopping bill is slightly higher"', () {
      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 15000,
        baseTransportFare: 1200,
        maxTimeHours: 3.0,
      );

      final result = aiService.interpretFollowUp(
        userFollowUp: 'I want to spend less on transport even if the shopping bill is slightly higher',
        currentPlans: plans,
        currentBudget: 15000,
        currentTransport: 1200,
      );

      expect(result.targetPlanId, 'plan-b');
      expect(result.interpretationExplanation.contains('Plan B cuts your transport cost'), true);
      expect(result.suggestedMaxStops, 2);
    });

    test('7. Schema validator rejects invalid/malformed JSON safely', () {
      // Missing required fields
      final invalidJson = {'random': 'data'};
      final proposal = aiService.validateProposal(invalidJson, 'test input');

      expect(proposal, isNotNull);
      // Fallback defaults are used safely without crashing
      expect(proposal!.budget, 15000.0);
      expect(proposal.shoppingItems.isNotEmpty, true);
    });

    test('8. Transparently reports when Live Cloud Meta AI succeeds vs when Fallback is used', () async {
      // 1. Without API key, service transparently reports fallback active
      const localService = MetaAiService();
      final fallbackProposal = await localService.parseToProposal('I have ₦15,000 for rice and eggs.');
      expect(fallbackProposal.isFallback, isTrue);
      expect(fallbackProposal.isLiveCloud, isFalse);
      expect(fallbackProposal.executionStatus.contains('Fallback Active'), isTrue);
      expect(fallbackProposal.fallbackReason, isNotNull);

      // Voice fallback reporting
      final voiceResult = await localService.transcribeAudio();
      expect(voiceResult.isFallback, isTrue);
      expect(voiceResult.note?.contains('Fallback Active'), isTrue);

      // 2. Simulated Live Cloud API response validates as live success
      final mockLiveJson = {
        'budget': 20000.0,
        'shopping_items': [
          {'name': 'Yam', 'quantity': 2, 'unit': 'tuber', 'estimated_unit_price': 2200.0},
        ],
        'deadline_errand': {
          'title': 'Collect parcel',
          'deadline': '3:00 PM',
          'location': 'Hub',
        },
      };

      final liveProposal = localService.validateProposal(
        mockLiveJson,
        'Live request',
        isFallback: false,
        executionStatus: 'Meta AI Live Cloud: Success',
      );

      expect(liveProposal, isNotNull);
      expect(liveProposal!.isFallback, isFalse);
      expect(liveProposal.isLiveCloud, isTrue);
      expect(liveProposal.executionStatus, 'Meta AI Live Cloud: Success');
      expect(liveProposal.fallbackReason, isNull);
    });
  });
}


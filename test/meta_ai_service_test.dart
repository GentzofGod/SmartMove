import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/models/product.dart';
import 'package:smartmove/core/models/price_observation.dart';

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
      // Malformed model output reports user-friendly error without inventing fallback mock commodities
      expect(proposal!.hasError, isTrue);
      expect(proposal.errorMessage, isNotNull);
      expect(proposal.shoppingItems, isEmpty);
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

    test('9. Muse Spark coordinates online price research for commodities', () {
      final researchPlan = aiService.coordinatePriceResearch('Parboiled Rice');

      expect(researchPlan.commodityName, 'Parboiled Rice');
      expect(researchPlan.category, 'Grains & Cereals');
      expect(researchPlan.standardizedUnit, '1kg');
      expect(researchPlan.targetPlatforms.contains('Jumia Supermarket'), true);
      expect(researchPlan.searchKeywords.isNotEmpty, true);
      expect(researchPlan.estimatedBenchmarkMin < researchPlan.estimatedBenchmarkMax, true);
    });

    test('10. Muse Spark detects duplicate listings across sellers', () {
      const product = Product(
        id: 'p-rice',
        name: 'Mama Gold Rice (50kg)',
        category: 'Groceries',
        standardUnit: '50kg',
        lowestPrice: 75000,
        bestSeller: 'Bodija Market',
        distanceKm: 2.0,
        updateTime: '1h ago',
      );

      final candidateDuplicates = [
        PriceObservation(
          id: 'c1',
          productId: 'p-custom',
          productName: 'Mama Gold Rice (50kg)',
          sellerName: 'Jumia Store',
          marketLocation: 'Online',
          price: 78000,
          unit: '50kg',
          timestamp: DateTime.now(),
          sourceType: ObservationSource.onlineGrounded,
          submitterName: 'Web Scraper',
        ),
        PriceObservation(
          id: 'c2',
          productId: 'p-custom',
          productName: 'Brown Beans',
          sellerName: 'Dugbe Mart',
          marketLocation: 'Dugbe',
          price: 2400,
          unit: '1kg',
          timestamp: DateTime.now(),
          sourceType: ObservationSource.communityReported,
          submitterName: 'Trader',
        ),
      ];

      final results = aiService.detectDuplicateListings(
        product: product,
        candidates: candidateDuplicates,
      );

      expect(results.length, 2);
      expect(results[0].isLikelyDuplicate, true); // Exact match
      expect(results[0].similarityScore >= 0.9, true);
      expect(results[1].isLikelyDuplicate, false); // Brown Beans != Rice
    });

    test('11. Muse Spark explains grounded commodity price comparison', () {
      const product = Product(
        id: 'p-oil',
        name: 'Cooking Oil (1L)',
        category: 'Groceries',
        standardUnit: '1L',
        lowestPrice: 2850,
        bestSeller: 'Bodija Wholesale',
        distanceKm: 2.5,
        updateTime: '2h ago',
      );

      final quotes = [
        PriceObservation(
          id: 'q1',
          productId: 'p-oil',
          productName: 'Cooking Oil (1L)',
          sellerName: 'Bodija Wholesale',
          marketLocation: 'Bodija Market',
          price: 2850,
          unit: '1L',
          timestamp: DateTime.now(),
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Trader',
          channel: 'Local Market',
        ),
        PriceObservation(
          id: 'q2',
          productId: 'p-oil',
          productName: 'Cooking Oil (1L)',
          sellerName: 'Jumia Supermarket',
          marketLocation: 'Online',
          price: 3300,
          unit: '1L',
          timestamp: DateTime.now(),
          sourceType: ObservationSource.onlineGrounded,
          submitterName: 'System',
          channel: 'Online Retailer',
        ),
      ];

      final explanation = aiService.explainCommodityPriceComparison(
        product: product,
        observations: quotes,
        userBudget: 15000,
      );

      expect(explanation.contains('Meta Muse Spark Price Intelligence'), true);
      expect(explanation.contains('Bodija Wholesale'), true);
      expect(explanation.contains('Jumia Supermarket'), true);
      // Explains calculated ₦450 savings
      expect(explanation.contains('450'), true);
    });

    test('12. Muse Spark extracts brand, specifications, and preferred seller channels', () async {
      final proposal = await aiService.parseToProposal(
        'I need 5kg of Mama Gold parboiled destoned rice and 2L of Kings cooking oil from Bodija market with ₦25,000 budget.',
      );

      expect(proposal.budget, 25000.0);
      final rice = proposal.shoppingItems.firstWhere((i) => i.productName == 'Rice');
      expect(rice.brandOrGrade, 'Mama Gold (Grade A)');
      expect(rice.specification?.contains('Parboiled'), isTrue);
      expect(rice.specification?.contains('De-stoned'), isTrue);
      expect(rice.preferredSellerType, 'Local Market');
      expect(rice.acceptableAlternatives.contains('Royal Stallion'), isTrue);

      final oil = proposal.shoppingItems.firstWhere((i) => i.productName == 'Cooking Oil');
      expect(oil.brandOrGrade, 'Kings Pure Vegetable Oil');
      expect(oil.acceptableAlternatives.contains('Golden Penny'), isTrue);
    });

    test('13. Muse Spark coordinates price research across diverse commodities', () {
      final garriPlan = aiService.coordinatePriceResearch('Ijebu Garri');
      expect(garriPlan.category, 'Grains & Flours');
      expect(garriPlan.standardizedUnit, 'paint bucket');
      expect(garriPlan.estimatedBenchmarkMin, 3200.0);
      expect(garriPlan.targetPlatforms.contains('PriceCheck Nigeria (Verified Crawl)'), isTrue);

      final drugPlan = aiService.coordinatePriceResearch('Paracetamol 500mg');
      expect(drugPlan.category, 'Pharmacy & Health');
      expect(drugPlan.standardizedUnit, 'pack');
    });

    test('14. Enhanced duplicate listing detection evaluates brand match & vendor repeats', () {
      const product = Product(
        id: 'p-rice',
        name: 'Rice (50kg)',
        category: 'Groceries',
        standardUnit: '50kg',
        lowestPrice: 78000,
        bestSeller: 'Bodija Grain Stalls',
        distanceKm: 1.5,
        updateTime: '1h ago',
        brandOrGrade: 'Mama Gold (Grade A)',
      );

      final candidateObs = [
        PriceObservation(
          id: 'dup-vendor',
          productId: 'p-rice-alt',
          productName: 'Rice (50kg)',
          sellerName: 'Bodija Grain Stalls',
          marketLocation: 'Bodija Market Hub',
          price: 78500,
          unit: '50kg',
          timestamp: DateTime.now(),
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Mallam',
          brandOrGrade: 'Mama Gold (Grade A)',
        ),
      ];

      final results = aiService.detectDuplicateListings(
        product: product,
        candidates: candidateObs,
      );

      expect(results.first.isLikelyDuplicate, isTrue);
      expect(results.first.similarityScore >= 0.95, isTrue);
      expect(results.first.reasoning.contains('repeated listing from same vendor'), isTrue);
    });

    test('15. Meta AI detects price anomalies with structured warnings and guidance', () {
      const product = Product(
        id: 'p-rice',
        name: 'Rice (1kg)',
        category: 'Groceries',
        standardUnit: '1kg',
        lowestPrice: 1650,
        bestSeller: 'Bodija Market',
        distanceKm: 1.5,
        updateTime: '1h ago',
      );

      final now = DateTime.now();
      final observations = [
        PriceObservation(
          id: 'o1',
          productId: 'p-rice',
          productName: 'Rice (1kg)',
          sellerName: 'Bodija Market',
          marketLocation: 'Bodija',
          price: 1650,
          unit: '1kg',
          timestamp: now,
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Trader',
        ),
        PriceObservation(
          id: 'o2',
          productId: 'p-rice',
          productName: 'Rice (1kg)',
          sellerName: 'Foodco',
          marketLocation: 'Bodija',
          price: 1850,
          unit: '1kg',
          timestamp: now,
          sourceType: ObservationSource.communityReported,
          submitterName: 'Customer',
        ),
        PriceObservation(
          id: 'o-fake',
          productId: 'p-rice',
          productName: 'Rice (1kg)',
          sellerName: 'FlyByNight Stall',
          marketLocation: 'Unknown',
          price: 450, // >50% below average
          unit: '1kg',
          timestamp: now,
          sourceType: ObservationSource.communityReported,
          submitterName: 'Anon',
        ),
      ];

      final anomalies = aiService.detectPriceAnomalies(
        product: product,
        observations: observations,
      );

      expect(anomalies.isNotEmpty, isTrue);
      expect(anomalies.first.issueType, 'Unusually Low Price');
      expect(anomalies.first.observation.sellerName, 'FlyByNight Stall');
      expect(anomalies.first.recommendedAction.contains('Verify product authenticity'), isTrue);
    });

    test('16. parseToProposal with prompt lacking commodities reports friendly error without mock foodstuffs', () async {
      final proposal = await aiService.parseToProposal('Hello, I am heading to the market now.');
      expect(proposal.hasError, isTrue);
      expect(proposal.errorMessage, isNotNull);
      expect(proposal.errorMessage!.contains('could not identify any shopping commodities'), isTrue);
      expect(proposal.shoppingItems, isEmpty);
    });

    test('17. transcribeAudio with audio recording failure reports friendly error instead of coded sample', () async {
      final voiceResult = await aiService.transcribeAudio(
        audioBytes: const [0, 1, 2, 3],
      );
      expect(voiceResult.hasError, isTrue);
      expect(voiceResult.errorMessage, isNotNull);
      expect(voiceResult.errorMessage!.contains('currently unavailable'), isTrue);
      expect(voiceResult.text, isEmpty);
    });

    test('18. parsePaperNoteImage with photo failure reports friendly error instead of coded note', () async {
      final scanResult = await aiService.parsePaperNoteImage(
        imageBytes: const [0xFF, 0xD8, 0xFF, 0xE0],
      );
      expect(scanResult.hasError, isTrue);
      expect(scanResult.errorMessage, isNotNull);
      expect(scanResult.errorMessage!.contains('currently unavailable'), isTrue);
      expect(scanResult.proposal.hasError, isTrue);
      expect(scanResult.proposal.shoppingItems, isEmpty);
    });
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/models/errand.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';

void main() {
  group('SmartMove DecisionEngine Tests (Hackathon Deterministic Calculations)', () {
    test('Calculates 4 primary candidate plans correctly under ₦15,000 budget', () {
      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 15000,
        baseTransportFare: 1200,
        maxTimeHours: 3.0,
      );

      // Options A, B, C, D
      expect(plans.length, 4);

      final planA = plans.firstWhere((p) => p.name == 'Option A');
      expect(planA.itemCost, 11600.0);
      expect(planA.transportCost, 1800.0); // 1200 * 1.5
      expect(planA.totalCost, 13400.0);
      expect(planA.isFeasibleBudget, true); // 13400 <= 15000
      expect(planA.isFeasibleDeadline, true); // 2.5 <= 3.0
      expect(planA.isRecommended, true);

      final planB = plans.firstWhere((p) => p.name == 'Option B');
      expect(planB.itemCost, 12600.0);
      expect(planB.transportCost, 1200.0);
      expect(planB.totalCost, 13800.0);
      expect(planB.estimatedHours, 1.8);
      expect(planB.stopCount, 2);

      final planC = plans.firstWhere((p) => p.name == 'Option C');
      expect(planC.estimatedHours, 1.2);
      expect(planC.stopCount, 1);

      final planD = plans.firstWhere((p) => p.name == 'Option D');
      expect(planD.tag, 'Delay Non-Urgent');
      expect(planD.totalCost <= 15000, true);
    });

    test('Identifies budget constraint violations when budget is reduced', () {
      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 11000,
        baseTransportFare: 1200,
        maxTimeHours: 3.0,
      );

      final planA = plans.firstWhere((p) => p.name == 'Option A');
      expect(planA.totalCost, 13400.0);
      expect(planA.isFeasibleBudget, false); // 13400 > 11000

      final insight = DecisionEngine.generateRecommendationInsight(
        budget: 11000,
        transportCost: 1200,
        timeAvailable: 3.0,
        candidates: plans,
      );
      expect(insight.contains('Strict budget safety'), true);
      expect(insight.contains('Option D'), true);
    });

    test('Meta AI Service parses prompt into structured items and package errand', () async {
      const aiService = MetaAiService();
      final result = await aiService.parseRequest(
        'I have ₦15,000. I need rice, eggs, tomatoes, oil and collect package before 2 PM',
      );

      expect(result.budget, 15000);
      expect(result.shoppingItems.length, 4);
      expect(result.shoppingItems.any((i) => i.productName == 'Rice'), true);
      expect(result.shoppingItems.any((i) => i.productName == 'Eggs'), true);
      expect(result.shoppingItems.any((i) => i.productName == 'Tomatoes'), true);
      expect(result.shoppingItems.any((i) => i.productName == 'Cooking Oil'), true);

      expect(result.errand, isNotNull);
      expect(result.errand!.title, 'Collect package');
      expect(result.errand!.deadline, '2:00 PM');
    });

    test('Dynamically calculates candidate plans with arbitrary custom items and custom errands', () {
      final customItems = [
        ShoppingItem(
          id: 'si-yam',
          productName: 'Yam',
          quantity: 2,
          unit: 'tuber',
          estimatedUnitPrice: 2200, // 4400
        ),
        ShoppingItem(
          id: 'si-beans',
          productName: 'Beans',
          quantity: 3,
          unit: 'kg',
          estimatedUnitPrice: 2400, // 7200
        ),
        ShoppingItem(
          id: 'si-bread',
          productName: 'Bread',
          quantity: 1,
          unit: 'loaf',
          estimatedUnitPrice: 1400, // 1400
          priority: ErrandPriority.low,
        ),
      ]; // Total = 13,000

      final customErrand = Errand(
        id: 'e-cleaners',
        title: 'Drop off Dry Cleaning',
        locationName: 'Local Cleaners Hub',
        scheduledTime: '11:00 AM',
        deadline: '1:00 PM',
        priority: ErrandPriority.high,
        category: 'service',
      );

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 20000,
        baseTransportFare: 1500,
        maxTimeHours: 2.5,
        items: customItems,
        errands: [customErrand],
      );

      expect(plans.length, 4);

      // Option A (Multi-market competitive pricing)
      final planA = plans.firstWhere((p) => p.name == 'Option A');
      expect(planA.itemCost, 12350.0); // 13000 * 0.95
      expect(planA.transportCost, 2250.0); // 1500 * 1.5
      expect(planA.totalCost, 14600.0);
      expect(planA.isFeasibleBudget, true);

      // Verify dynamic itinerary stops contain user's custom items and errand
      expect(planA.stops.any((s) => s.title.contains('Market')), true);
      expect(planA.stops.any((s) => s.title == 'Drop off Dry Cleaning'), true);

      // Option D (Postpones non-urgent low priority bread)
      final planD = plans.firstWhere((p) => p.name == 'Option D');
      expect(planD.itemCost, 11600.0); // 4400 (yam) + 7200 (beans), excluding bread
      expect(planD.isFeasibleBudget, true);
    });

    test('Meta AI parses arbitrary commodities and non-shopping errands with deadlines', () async {
      const aiService = MetaAiService();
      final proposal = await aiService.parseToProposal(
        'I have ₦25,000. I need 2 tubers of yam, 3kg beans, and 1 loaf of bread. Drop off dry cleaning before 1 PM.',
      );

      expect(proposal.budget, 25000);
      expect(proposal.shoppingItems.length, 3);
      expect(proposal.shoppingItems.any((i) => i.productName == 'Yam'), true);
      expect(proposal.shoppingItems.any((i) => i.productName == 'Beans'), true);
      expect(proposal.shoppingItems.any((i) => i.productName == 'Sliced Bread'), true);

      expect(proposal.deadlineErrand, isNotNull);
      expect(proposal.deadlineErrand!.title, 'Drop off Dry Cleaning');
      expect(proposal.deadlineErrand!.deadline, '1:00 PM');
    });

    test('Meta AI generates proactive optimization tips and processes conversational commands', () {
      const aiService = MetaAiService();

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 12000,
        baseTransportFare: 1200,
        maxTimeHours: 3.0,
      );

      final tips = aiService.generateOptimizationTips(
        currentPlans: plans,
        currentBudget: 12000,
        currentTransport: 1200,
        items: [],
        errands: [],
      );

      expect(tips.isNotEmpty, true);
      expect(tips.any((t) => t.id == 'tip-budget-safety'), true);

      // Conversational commands: Add item, Change budget, Fastest plan
      final addResult = aiService.processConversationalCommand(
        command: 'Add 2 tubers of yam',
        currentPlans: plans,
        currentBudget: 12000,
        currentTransport: 1200,
        currentHours: 3.0,
        currentItems: [],
      );
      expect(addResult.addedItem, isNotNull);
      expect(addResult.addedItem!.productName, 'Yam');

      final budgetResult = aiService.processConversationalCommand(
        command: 'Set budget to 25k',
        currentPlans: plans,
        currentBudget: 12000,
        currentTransport: 1200,
        currentHours: 3.0,
        currentItems: [],
      );
      expect(budgetResult.updatedBudget, 25000.0);

      final fastResult = aiService.processConversationalCommand(
        command: 'I am in a hurry, give me the fastest route',
        currentPlans: plans,
        currentBudget: 12000,
        currentTransport: 1200,
        currentHours: 3.0,
        currentItems: [],
      );
      expect(fastResult.selectedPlanId, 'plan-c');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
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

      // Plans A, B, C, D
      expect(plans.length, 4);

      final planA = plans.firstWhere((p) => p.name == 'Plan A');
      expect(planA.itemCost, 11600.0);
      expect(planA.transportCost, 1800.0); // 1200 * 1.5
      expect(planA.totalCost, 13400.0);
      expect(planA.isFeasibleBudget, true); // 13400 <= 15000
      expect(planA.isFeasibleDeadline, true); // 2.5 <= 3.0
      expect(planA.isRecommended, true);

      final planB = plans.firstWhere((p) => p.name == 'Plan B');
      expect(planB.itemCost, 12600.0);
      expect(planB.transportCost, 1200.0);
      expect(planB.totalCost, 13800.0);
      expect(planB.estimatedHours, 1.8);
      expect(planB.stopCount, 2);

      final planC = plans.firstWhere((p) => p.name == 'Plan C');
      expect(planC.estimatedHours, 1.2);
      expect(planC.stopCount, 2);

      final planD = plans.firstWhere((p) => p.name == 'Plan D');
      expect(planD.tag, 'Delay Non-Urgent');
      expect(planD.totalCost <= 15000, true);
    });

    test('Identifies budget constraint violations when budget is reduced', () {
      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 11000,
        baseTransportFare: 1200,
        maxTimeHours: 3.0,
      );

      final planA = plans.firstWhere((p) => p.name == 'Plan A');
      expect(planA.totalCost, 13400.0);
      expect(planA.isFeasibleBudget, false); // 13400 > 11000

      final insight = DecisionEngine.generateRecommendationInsight(
        budget: 11000,
        transportCost: 1200,
        timeAvailable: 3.0,
        candidates: plans,
      );
      expect(insight.contains('Strict budget safety'), true);
      expect(insight.contains('Plan D'), true);
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
  });
}

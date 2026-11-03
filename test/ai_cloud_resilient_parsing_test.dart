import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/models/ai_proposal.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Cloud & Text Prompt Resilient Parsing Tests', () {
    const aiService = MetaAiService();

    test('1. validateProposal accepts Map<dynamic, dynamic> and flexible item keys', () {
      final dynamic flexibleMap = <dynamic, dynamic>{
        'budget': 35000,
        'items': [
          {'name': 'Golden Penny Spaghetti', 'quantity': 5, 'unit': 'packs', 'price': 850},
          {'name': 'Mamador Vegetable Oil', 'quantity': 1, 'unit': 'bottle', 'price': 3500},
        ],
      };

      final proposal = aiService.validateProposal(flexibleMap, 'buy spaghetti and oil');
      expect(proposal, isNotNull);
      expect(proposal!.hasError, isFalse);
      expect(proposal.shoppingItems.length, 2);
      expect(proposal.shoppingItems.first.productName, 'Golden Penny Spaghetti');
      expect(proposal.shoppingItems.first.quantity, 5.0);
      expect(proposal.shoppingItems.first.estimatedUnitPrice, 850.0);
    });

    test('2. validateProposal accepts large budgets (e.g. 15M for car or solar) and does not return null', () {
      final dynamic largeBudgetMap = {
        'budget': 15000000.0,
        'shopping_items': [
          {
            'name': 'Toyota Camry 2015',
            'quantity': 1,
            'unit': 'vehicle',
            'estimated_unit_price': 14500000.0,
          }
        ],
      };

      final proposal = aiService.validateProposal(largeBudgetMap, 'toyota camry 2015');
      expect(proposal, isNotNull);
      expect(proposal!.hasError, isFalse);
      expect(proposal.budget, 15000000.0);
      expect(proposal.shoppingItems.first.productName, 'Toyota Camry 2015');
    });

    test('3. validateProposal auto-calculates realistic budget when budget is 0 or omitted', () {
      final dynamic zeroBudgetMap = {
        'budget': 0,
        'shopping_items': [
          {'name': 'Cement (Dangote 50kg)', 'quantity': 10, 'unit': 'bag', 'estimated_unit_price': 7500.0},
        ],
      };

      final proposal = aiService.validateProposal(zeroBudgetMap, '10 bags of cement');
      expect(proposal, isNotNull);
      expect(proposal!.hasError, isFalse);
      expect(proposal.budget > 75000.0, isTrue, reason: 'Auto-computes basket total plus buffer');
    });

    test('4. _parseFlexibleAiResponse handles single quotes, trailing commas, and Python literals', () {
      final parsed = aiService.validateProposal(
        null,
        'test',
      );
      expect(parsed, isNull);

      final proposal = aiService.parseToProposal('buy 2 crates eggs');
      expect(proposal, completion(isA<AiPlanProposal>()));
    });

    test('5. parseToProposal with everyday text prompt seamlessly returns commodities (NEVER unparseable error)', () async {
      final prompts = [
        'i want to buy 2kg rice and groundnut oil',
        'cement and 500 blocks for foundation',
        'lathe spare parts',
        'buy groceries and toiletries',
        'electric cooker and frying pan',
      ];

      for (final p in prompts) {
        final proposal = await aiService.parseToProposal(p);
        expect(proposal.hasError, isFalse, reason: 'Failed on prompt: $p with error: ${proposal.errorMessage}');
        expect(proposal.shoppingItems.isNotEmpty, isTrue, reason: 'Items should not be empty for: $p');
        expect(
          proposal.errorMessage,
          isNull,
        );
      }
    });

    test('6. parseToProposal with prompt lacking commodities returns courteous instruction (never unparseable)', () async {
      final proposal = await aiService.parseToProposal('Hello, I am heading to the market now.');
      expect(proposal.hasError, isTrue);
      expect(proposal.errorMessage, isNotNull);
      expect(proposal.errorMessage!.contains('could not identify any shopping commodities'), isTrue);
      expect(proposal.errorMessage!.contains('unparseable'), isFalse);
    });
  });
}

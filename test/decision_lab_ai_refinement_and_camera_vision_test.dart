import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/models/commodity_item.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';

void main() {
  group('1. Decision Lab AI Refinement & Conversational Output Tests', () {
    const aiService = MetaAiService();

    final testItems = [
      ShoppingItem(
        id: 'item-1',
        productName: 'Rice 50kg',
        quantity: 1,
        unit: 'bag',
        estimatedUnitPrice: 12000,
      ),
      ShoppingItem(
        id: 'item-2',
        productName: 'Vegetable Oil 5L',
        quantity: 1,
        unit: 'bottle',
        estimatedUnitPrice: 3000,
      ),
    ];

    final testCandidates = DecisionEngine.calculateCandidatePlans(
      userBudget: 18000,
      baseTransportFare: 1000,
      maxTimeHours: 2.0,
      items: testItems,
    );

    test('refineOptionsWithAi cleans raw JSON responses into natural conversational prose', () async {
      final result = await aiService.refineOptionsWithAi(
        userQuery: 'I want to spend less on transport across options',
        currentPlans: testCandidates,
        items: testItems,
        currentBudget: 18000,
        currentTransport: 1000,
      );

      expect(result.targetPlanId.isNotEmpty, isTrue);
      // Explanation must NEVER be raw JSON
      expect(result.interpretationExplanation.contains('{'), isFalse);
      expect(result.interpretationExplanation.contains('}'), isFalse);
      expect(result.interpretationExplanation.contains('"shopping_items"'), isFalse);
      expect(result.interpretationExplanation.contains('AI Shopping Assistant'), isTrue);
    });

    test('refineOptionsWithAi handles proximity suggestion without returning raw JSON or failing', () async {
      final result = await aiService.refineOptionsWithAi(
        userQuery: 'Which plan has the closest verified sellers?',
        currentPlans: testCandidates,
        items: testItems,
        currentBudget: 18000,
        currentTransport: 1000,
      );

      expect(result.targetPlanId.isNotEmpty, isTrue);
      expect(result.interpretationExplanation.contains('{'), isFalse);
      expect(result.interpretationExplanation.contains('AI Proximity Analysis'), isTrue);
    });

    test('refineOptionsWithAi handles cheapest overall suggestion dynamically', () async {
      final result = await aiService.refineOptionsWithAi(
        userQuery: 'Find the cheapest overall option',
        currentPlans: testCandidates,
        items: testItems,
        currentBudget: 18000,
        currentTransport: 1000,
      );

      expect(result.targetPlanId.isNotEmpty, isTrue);
      expect(result.interpretationExplanation.contains('{'), isFalse);
      expect(result.interpretationExplanation.contains('lowest total outlay'), isTrue);
    });
  });

  group('2. Camera Artifact Filtering & AI Vision Tests', () {
    const aiService = MetaAiService();
    final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

    test('parsePaperNoteImage ignores Android scaled_image_picker camera names', () async {
      final result = await aiService.parsePaperNoteImage(
        imageBytes: dummyBytes,
        imageName: 'scaled_image_picker_849204810294.jpg',
      );

      // Must NEVER use "Scaled Image Picker..." as the product name
      expect(result.detectedProductName, isNull);
      expect(result.noteTitle, isNot(contains('Scaled Image Picker')));
    });

    test('parsePaperNoteImage ignores camera HAL artifacts like IMG_, PXL_, and screenshot names', () async {
      final resultImg = await aiService.parsePaperNoteImage(
        imageBytes: dummyBytes,
        imageName: 'IMG_20261103_142301.jpg',
      );
      expect(resultImg.detectedProductName, isNull);

      final resultPxl = await aiService.parsePaperNoteImage(
        imageBytes: dummyBytes,
        imageName: 'PXL_20261103_091244.jpg',
      );
      expect(resultPxl.detectedProductName, isNull);
    });

    test('parsePaperNoteImage preserves legitimate user product photo filenames', () async {
      final resultToyota = await aiService.parsePaperNoteImage(
        imageBytes: dummyBytes,
        imageName: 'toyota_camry_2015.jpg',
      );
      expect(resultToyota.detectedProductName, 'Toyota Camry 2015');

      final resultCooker = await aiService.parsePaperNoteImage(
        imageBytes: dummyBytes,
        imageName: 'electric_cooker_hotplate.png',
      );
      expect(resultCooker.detectedProductName, 'Electric Cooker Hotplate');
    });
  });
}

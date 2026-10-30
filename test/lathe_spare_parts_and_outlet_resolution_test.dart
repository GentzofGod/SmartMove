import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartmove/core/models/commodity_item.dart';
import 'package:smartmove/core/models/item_acquisition_source.dart';
import 'package:smartmove/core/services/location_service.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';
import 'package:smartmove/core/services/safe_outlet_launcher.dart';
import 'package:smartmove/features/decision_lab/presentation/widgets/trader_negotiation_sheet.dart';

void main() {
  group('Lathe Spare Parts & Grounding Tests', () {
    const aiService = MetaAiService();

    test('Prompt "lathe spare parts" extracts genuine mechanical spares and never "soluble lathe" or "litters"', () async {
      final proposal = await aiService.parseToProposal('lathe spare parts');

      expect(proposal.errorMessage, isNull);
      expect(proposal.shoppingItems.isNotEmpty, true);

      for (final item in proposal.shoppingItems) {
        final lower = item.productName.toLowerCase();
        // Strict assertion against hallucinated fluid / mangled terms
        expect(lower.contains('soluble lathe'), false, reason: 'Mangled "soluble lathe" should never appear');
        expect(item.unit.toLowerCase(), isNot('litters'), reason: 'Misspelled "litters" should never appear');
      }

      // Verify that lathe tool bits or lathe machine parts are present
      final hasLatheSpares = proposal.shoppingItems.any(
        (i) => i.productName.toLowerCase().contains('lathe') ||
               i.productName.toLowerCase().contains('tool') ||
               i.productName.toLowerCase().contains('carbide'),
      );
      expect(hasLatheSpares, true);
    });

    test('Heuristic search "i search for lathe spare parts" extracts legitimate items', () async {
      final proposal = await aiService.parseToProposal('i search for lathe spare parts');

      expect(proposal.errorMessage, isNull);
      expect(proposal.shoppingItems.isNotEmpty, true);
      expect(
        proposal.shoppingItems.any((i) => i.productName.toLowerCase().contains('lathe')),
        true,
      );
    });

    test('validateProposal cleanses hallucinated "soluble lathe" and "litters"', () {
      final badJson = {
        'budget': 20000.0,
        'shopping_items': [
          {
            'name': 'four litters of soluble lathe',
            'quantity': 4.0,
            'unit': 'litters',
            'estimated_unit_price': 3000.0,
          }
        ],
      };

      final cleaned = aiService.validateProposal(badJson, 'raw test input');
      expect(cleaned, isNotNull);
      expect(cleaned!.shoppingItems.first.productName, contains('Lathe Machine Spare'));
      expect(cleaned.shoppingItems.first.unit, equals('set'));
    });
  });

  group('SafeOutletLauncher Phone Validation Tests', () {
    test('isValidPhoneNumber correctly distinguishes real vs dummy or null numbers', () {
      expect(SafeOutletLauncher.isValidPhoneNumber(null), false);
      expect(SafeOutletLauncher.isValidPhoneNumber(''), false);
      expect(SafeOutletLauncher.isValidPhoneNumber('   '), false);
      expect(SafeOutletLauncher.isValidPhoneNumber('123'), false); // too short
      expect(SafeOutletLauncher.isValidPhoneNumber('0000000000'), false); // repeated dummy
      expect(SafeOutletLauncher.isValidPhoneNumber('1111111111'), false); // repeated dummy

      // Valid Nigerian mobile and landline numbers
      expect(SafeOutletLauncher.isValidPhoneNumber('+234 802 345 6789'), true);
      expect(SafeOutletLauncher.isValidPhoneNumber('08032345678'), true);
      expect(SafeOutletLauncher.isValidPhoneNumber('+234 803 234 5678'), true);
    });
  });

  group('DecisionEngine Industrial & Spare Parts Outlet Resolution Tests', () {
    test('Lathe spare parts resolve to machine tools / hardware lines, NOT Mama Bello grain seller', () {
      final latheItem = ShoppingItem(
        id: 'si-lathe-1',
        productName: 'Lathe High-Speed Steel (HSS) Tool Bits Set',
        quantity: 1.0,
        unit: 'set',
        estimatedUnitPrice: 14500.0,
      );

      final plans = DecisionEngine.calculateCandidatePlans(
        items: [latheItem],
        userBudget: 50000.0,
        baseTransportFare: 400.0,
        maxTimeHours: 3.0,
        userLocation: const GeoPoint(
          latitude: 7.3775,
          longitude: 3.9470,
          city: 'Ibadan',
          label: 'Ibadan Central',
        ),
      );

      final planA = plans.firstWhere((p) => p.id == 'plan-a');
      final planB = plans.firstWhere((p) => p.id == 'plan-b');
      final planC = plans.firstWhere((p) => p.id == 'plan-c');
      final planD = plans.firstWhere((p) => p.id == 'plan-d');

      final srcA = planA.acquisitionSources.first;
      final srcB = planB.acquisitionSources.first;
      final srcC = planC.acquisitionSources.first;
      final srcD = planD.acquisitionSources.first;

      // 1. Must NOT map to Mama Bello (grain trader)
      expect(srcA.outletName.toLowerCase().contains('mama bello'), false);
      expect(srcB.outletName.toLowerCase().contains('mama bello'), false);
      expect(srcC.outletName.toLowerCase().contains('mama bello'), false);
      expect(srcD.outletName.toLowerCase().contains('mama bello'), false);

      // 2. Hardware / machine tools outlets
      expect(srcA.outletName, contains('Machine Tools'));
      expect(srcB.outletName, contains('Engineering'));
      expect(srcC.outletName, contains('Hardware'));
      expect(srcD.outletName, contains('Jumia Industrial'));

      // 3. No fake registered trader or fake phone numbers
      expect(srcA.isPlatformRegisteredTrader, false);
      expect(srcB.isPlatformRegisteredTrader, false);
      expect(srcA.contactPhone, isNull);
      expect(srcB.contactPhone, isNull);
      expect(srcC.contactPhone, isNull);
      expect(srcD.contactPhone, isNull);
    });
  });

  group('Trader Negotiation Sheet Contextual Greeting Tests', () {
    testWidgets('Renders professional, non-perishable welcome message for hardware spare parts', (tester) async {
      final source = ItemAcquisitionSource(
        id: 'src-test-lathe',
        itemId: 'item-lathe-1',
        commodityName: 'Lathe High-Speed Steel (HSS) Tool Bits Set',
        quantity: 1.0,
        unit: 'set',
        unitPrice: 14500.0,
        totalCost: 14500.0,
        outletName: 'Dugbe Industrial Machine Spares',
        channel: AcquisitionChannel.registeredTrader,
        marketHubOrLocation: 'Dugbe Central Engineering District',
        latitude: 7.3876,
        longitude: 3.8767,
        dynamicDistanceKm: 1.5,
        isPlatformRegisteredTrader: true,
        contactPhone: null, // No phone number -> Call button should be hidden!
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TraderNegotiationSheet(source: source),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Welcome message should NOT contain "fresh, genuine stock"
      expect(find.textContaining('fresh, genuine stock'), findsNothing);
      expect(find.textContaining('Thank you for inquiring about Lathe High-Speed Steel'), findsOneWidget);

      // Call button should be HIDDEN because contactPhone is null
      expect(find.byTooltip('Call Trader'), findsNothing);
      expect(find.byTooltip('WhatsApp Inquiry'), findsNothing);
    });
  });
}

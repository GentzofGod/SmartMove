import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/services/auth_service.dart';
import 'package:smartmove/core/models/errand.dart';
import 'package:smartmove/core/models/seller_application.dart';
import 'package:smartmove/core/services/decision_engine.dart';
import 'package:smartmove/core/services/meta_ai_service.dart';

void main() {
  group('Database Role Sync & Parsing Tests', () {
    test('UserRole.fromString correctly parses Admin and SuperAdmin variations from Supabase profiles', () {
      expect(UserRole.fromString('Admin'), UserRole.admin);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('ADMIN'), UserRole.admin);

      expect(UserRole.fromString('SuperAdmin'), UserRole.superAdmin);
      expect(UserRole.fromString('superadmin'), UserRole.superAdmin);
      expect(UserRole.fromString('SUPER_ADMIN'), UserRole.superAdmin);
      expect(UserRole.fromString('super_admin'), UserRole.superAdmin);

      expect(UserRole.fromString('Trader'), UserRole.trader);
      expect(UserRole.fromString('trader'), UserRole.trader);

      expect(UserRole.fromString('Customer'), UserRole.customer);
      expect(UserRole.fromString('customer'), UserRole.customer);
      expect(UserRole.fromString(null), UserRole.customer);
    });
  });

  group('Electric Cooker & Appliance Extraction Tests', () {
    const aiService = MetaAiService();

    test('Prompt "i want to buy electric cooker" extracts Electric Cooker and NEVER Pay Electricity Bill errand', () async {
      final proposal = await aiService.parseToProposal('i want to buy electric cooker');

      expect(proposal.hasError, false);
      expect(proposal.shoppingItems.isNotEmpty, true);
      expect(proposal.shoppingItems.first.productName, 'Electric Cooker');

      // Crucial: Must NOT generate a utility errand to PHCN
      expect(proposal.deadlineErrand, isNull);
    });

    test('Prompt "buy rice cooker" extracts Rice Cooker and NEVER grain Rice', () async {
      final proposal = await aiService.parseToProposal('buy rice cooker');

      expect(proposal.hasError, false);
      expect(proposal.shoppingItems.isNotEmpty, true);

      final itemNames = proposal.shoppingItems.map((i) => i.productName).toList();
      expect(itemNames.contains('Rice Cooker'), true);
      expect(itemNames.contains('Rice'), false, reason: 'Grain rice must not be extracted for rice cooker');
      expect(proposal.deadlineErrand, isNull);
    });

    test('Explicit utility request "pay electricity bill before 2pm" extracts utility errand', () async {
      final proposal = await aiService.parseToProposal('pay electricity bill before 2pm');

      expect(proposal.deadlineErrand, isNotNull);
      expect(proposal.deadlineErrand!.title, 'Pay Electricity Bill');
      expect(proposal.deadlineErrand!.locationName.contains('PHCN'), true);
    });
  });

  group('Appliance Sourcing & Zero Fake Trader Fallback Tests', () {
    test('Electric cooker acquires from Electronics Arcade / Jumia, NOT Foodco or Bodija Grain Line', () {
      final cookerItem = ShoppingItem(
        id: 'si-cooker',
        productName: 'Electric Cooker',
        quantity: 1,
        unit: 'unit',
        estimatedUnitPrice: 35000.0,
      );

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 50000,
        baseTransportFare: 1200,
        maxTimeHours: 3.0,
        items: [cookerItem],
        registeredTraders: const [], // Zero registered traders
      );

      expect(plans.isNotEmpty, true);

      for (final plan in plans) {
        for (final source in plan.acquisitionSources) {
          expect(source.isPlatformRegisteredTrader, false,
              reason: 'With 0 registered traders, no source should be a registered trader');
          expect(source.outletName.toLowerCase().contains('mama bello'), false,
              reason: 'Mama Bello Grains must never supply electric cookers');
          expect(source.outletName.toLowerCase().contains('grain'), false);

          if (plan.id == 'plan-d') {
            expect(source.outletName, 'Jumia Official Appliance Store');
            expect(source.webUrl, isNotNull);
          } else if (plan.id == 'plan-c') {
            expect(source.outletName, 'Mega Electronics & Household Appliances Mart');
          } else {
            expect(source.outletName.toLowerCase().contains('electronics'), true);
          }
        }
      }
    });

    test('Registered Grain Trader is NEVER matched for Electric Cooker', () {
      final cookerItem = ShoppingItem(
        id: 'si-cooker',
        productName: 'Electric Cooker',
        quantity: 1,
        unit: 'unit',
        estimatedUnitPrice: 35000.0,
      );

      final grainTrader = SellerApplication(
        id: 'app-bello',
        userId: 'usr-bello',
        applicantName: 'Mama Bello',
        applicantEmail: 'bello@bodijamarket.ng',
        businessName: 'Mama Bello Grains & Oil Enterprise',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        stallLocation: 'Stall 14, Main Grain Line',
        phone: '+234 802 345 6789',
        status: SellerApplicationStatus.approved,
        submittedAt: DateTime(2025, 1, 1),
      );

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 50000,
        baseTransportFare: 1200,
        maxTimeHours: 3.0,
        items: [cookerItem],
        registeredTraders: [grainTrader],
      );

      for (final plan in plans) {
        for (final source in plan.acquisitionSources) {
          expect(source.isPlatformRegisteredTrader, false,
              reason: 'Grain trader must never match electric cooker');
          expect(source.outletName.contains('Mama Bello'), false);
        }
      }
    });

    test('Registered Electronics Trader IS matched when approved', () {
      final cookerItem = ShoppingItem(
        id: 'si-cooker',
        productName: 'Electric Cooker',
        quantity: 1,
        unit: 'unit',
        estimatedUnitPrice: 35000.0,
      );

      final electronicsTrader = SellerApplication(
        id: 'app-electro',
        userId: 'usr-electro',
        applicantName: 'Chidi Okafor',
        applicantEmail: 'chidi.electro@gmail.com',
        businessName: 'Okafor Electronics & Home Appliances',
        marketHub: 'Dugbe Commercial Area',
        sellerChannel: 'Retail Store',
        stallLocation: 'Shop 12, Dugbe Electronics Arcade',
        phone: '+234 803 765 4321',
        status: SellerApplicationStatus.approved,
        submittedAt: DateTime(2025, 1, 1),
      );

      final plans = DecisionEngine.calculateCandidatePlans(
        userBudget: 50000,
        baseTransportFare: 1200,
        maxTimeHours: 3.0,
        items: [cookerItem],
        registeredTraders: [electronicsTrader],
      );

      final planA = plans.firstWhere((p) => p.id == 'plan-a');
      final source = planA.acquisitionSources.first;
      expect(source.isPlatformRegisteredTrader, true);
      expect(source.outletName, 'Okafor Electronics & Home Appliances');
      expect(source.contactPhone, '+234 803 765 4321');
    });
  });
}

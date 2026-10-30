import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/models/commodity_category.dart';
import 'package:smartmove/core/models/product.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/core/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommodityCategory & Product Schema Model Tests', () {
    test('1. CommodityCategory model serializes and deserializes properly', () {
      const cat = CommodityCategory(
        id: 'cat-grains-01',
        name: 'Grains & Flours',
        slug: 'grains-flours',
        iconName: 'grain_outlined',
        description: 'Rice, beans, garri, and flours.',
        displayOrder: 2,
        isActive: true,
      );

      final json = cat.toJson();
      expect(json['id'], equals('cat-grains-01'));
      expect(json['name'], equals('Grains & Flours'));
      expect(json['slug'], equals('grains-flours'));

      final restored = CommodityCategory.fromJson(json);
      expect(restored.name, equals('Grains & Flours'));
      expect(restored.slug, equals('grains-flours'));
      expect(restored.displayOrder, equals(2));

      final dbMap = cat.toDbMap();
      expect(dbMap['slug'], equals('grains-flours'));
      expect(dbMap['is_active'], isTrue);
    });

    test('2. Product model serializes to JSON and maps to Supabase snake_case schema', () {
      const product = Product(
        id: 'prod-garri-01',
        name: 'Ijebu Garri (Paint Rubber)',
        category: 'Grains & Flours',
        categoryId: 'cat-grains-01',
        standardUnit: '4kg paint rubber',
        lowestPrice: 3800.0,
        bestSeller: 'Bodija Market Hub',
        createdBy: 'usr-seller-001',
        sellerId: 'usr-seller-001',
        distanceKm: 1.5,
        updateTime: '10m ago',
        brandOrGrade: 'Crisp White Dry (Grade A)',
        standardizedUnitPrice: 950.0,
        baseUnit: 'kg',
        channel: 'Local Market',
      );

      final json = product.toJson();
      expect(json['id'], equals('prod-garri-01'));
      expect(json['brandOrGrade'], equals('Crisp White Dry (Grade A)'));
      expect(json['standardizedUnitPrice'], equals(950.0));
      expect(json['createdBy'], equals('usr-seller-001'));

      final dbMap = product.toDbMap();
      expect(dbMap['name'], equals('Ijebu Garri (Paint Rubber)'));
      expect(dbMap['standard_unit'], equals('4kg paint rubber'));
      expect(dbMap['best_seller_name'], equals('Bodija Market Hub'));
      expect(dbMap['brand_or_grade'], equals('Crisp White Dry (Grade A)'));
      expect(dbMap['standardized_unit_price'], equals(950.0));
      expect(dbMap['created_by'], equals('usr-seller-001'));
    });

    test('3. Product deserializes from Supabase SQL response containing snake_case fields', () {
      final dbRow = {
        'id': 'b1111111-2222-3333-4444-555555555555',
        'name': 'Palm Oil (5L Keg)',
        'category': 'Oils & Seasonings',
        'category_id': 'c0000000-0000-0000-0000-000000000004',
        'standard_unit': '5L',
        'lowest_price': 12500.0,
        'best_seller_name': 'Mama Nkechi Provisions',
        'created_by': 'u8888888-9999-0000-1111-222222222222',
        'brand_or_grade': 'Pure Nsukka Palm Oil (Unadulterated)',
        'standardized_unit_price': 2500.0,
        'base_unit': 'L',
        'channel': 'Local Market',
        'percentage_change': -2.5,
        'is_cheapest': true,
        'source_type': 'trader_confirmed',
        'observation_count': 4,
      };

      final product = Product.fromJson(dbRow);
      expect(product.id, equals('b1111111-2222-3333-4444-555555555555'));
      expect(product.name, equals('Palm Oil (5L Keg)'));
      expect(product.lowestPrice, equals(12500.0));
      expect(product.bestSeller, equals('Mama Nkechi Provisions'));
      expect(product.brandOrGrade, equals('Pure Nsukka Palm Oil (Unadulterated)'));
      expect(product.standardizedUnitPrice, equals(2500.0));
      expect(product.baseUnit, equals('L'));
      expect(product.sourceType, equals(ObservationSource.traderConfirmed));
      expect(product.observationCount, equals(4));
    });
  });

  group('ProductsNotifier Seller Upload & State Lifecycle Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('4. Seller can upload a new product listing and query it through ProductsNotifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const newListing = Product(
        id: 'prod-new-honey-01',
        name: 'Pure Wild Honey (750ml)',
        category: 'Groceries',
        standardUnit: '750ml bottle',
        lowestPrice: 4500.0,
        bestSeller: 'Alhaji Gbadamosi Organics',
        createdBy: 'usr-gbadamosi',
        distanceKm: 2.1,
        updateTime: 'Just now',
        brandOrGrade: 'Grade A Unpasteurized',
        standardizedUnitPrice: 6000.0,
        baseUnit: 'L',
        channel: 'Local Market',
      );

      // Upload product
      container.read(productsProvider.notifier).addProduct(newListing);

      final products = container.read(productsProvider);
      final uploaded = products.firstWhere((p) => p.id == 'prod-new-honey-01');
      expect(uploaded.name, equals('Pure Wild Honey (750ml)'));
      expect(uploaded.bestSeller, equals('Alhaji Gbadamosi Organics'));
      expect(uploaded.brandOrGrade, equals('Grade A Unpasteurized'));

      // Filter by Groceries
      container.read(productsProvider.notifier).filterCategory('Groceries');
      expect(container.read(productsProvider).any((p) => p.id == 'prod-new-honey-01'), isTrue);

      // Search by keyword
      container.read(productsProvider.notifier).search('Honey');
      expect(container.read(productsProvider).length, equals(1));
      expect(container.read(productsProvider).first.id, equals('prod-new-honey-01'));
    });

    test('5. Seller can update product details and price through ProductsNotifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const initial = Product(
        id: 'prod-test-01',
        name: 'Local Brown Rice',
        category: 'Groceries',
        standardUnit: '1kg',
        lowestPrice: 1700.0,
        bestSeller: 'Bodija Stalls',
        distanceKm: 1.0,
        updateTime: '1h ago',
      );
      container.read(productsProvider.notifier).addProduct(initial);

      // Update price and seller
      final updated = initial.copyWith(
        lowestPrice: 1600.0,
        bestSeller: 'Mama Bisi Grains',
        brandOrGrade: 'Clean Stone-free Sorted',
      );
      container.read(productsProvider.notifier).updateProduct(updated);

      final products = container.read(productsProvider);
      final found = products.firstWhere((p) => p.id == 'prod-test-01');
      expect(found.lowestPrice, equals(1600.0));
      expect(found.bestSeller, equals('Mama Bisi Grains'));
      expect(found.brandOrGrade, equals('Clean Stone-free Sorted'));

      // Delete listing
      container.read(productsProvider.notifier).deleteProduct('prod-test-01');
      expect(container.read(productsProvider).any((p) => p.id == 'prod-test-01'), isFalse);
    });
  });
}


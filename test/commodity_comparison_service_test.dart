import 'package:flutter_test/flutter_test.dart';
import 'package:smartmove/core/models/price_observation.dart';
import 'package:smartmove/core/services/commodity_comparison_service.dart';

void main() {
  group('CommodityComparisonService & Unit Standardization Tests (Phase 2)', () {
    test('1. Accurately calculates unit multipliers for Nigerian commercial units', () {
      // Weight & Grain units
      expect(CommodityComparisonService.calculateUnitMultiplier('50kg bag'), 50.0);
      expect(CommodityComparisonService.calculateUnitMultiplier('25kg'), 25.0);
      expect(CommodityComparisonService.calculateUnitMultiplier('10kg bag'), 10.0);
      expect(CommodityComparisonService.calculateUnitMultiplier('1kg'), 1.0);
      expect(CommodityComparisonService.calculateUnitMultiplier('500g'), 0.5);

      // Paint bucket / rubber volumetric conversions by commodity density
      expect(
        CommodityComparisonService.calculateUnitMultiplier('paint bucket', commodityName: 'Rice'),
        4.0,
      );
      expect(
        CommodityComparisonService.calculateUnitMultiplier('paint rubber', commodityName: 'Brown Beans'),
        3.2,
      );
      expect(
        CommodityComparisonService.calculateUnitMultiplier('paint bucket', commodityName: 'Ijebu Garri'),
        3.0,
      );

      // Derica / Congo measures
      expect(
        CommodityComparisonService.calculateUnitMultiplier('derica', commodityName: 'Rice'),
        0.8,
      );
      expect(
        CommodityComparisonService.calculateUnitMultiplier('derica', commodityName: 'Garri'),
        0.7,
      );
      expect(
        CommodityComparisonService.calculateUnitMultiplier('half derica', commodityName: 'Rice'),
        0.4,
      );

      // Liquid / Volume units
      expect(CommodityComparisonService.calculateUnitMultiplier('25L keg'), 25.0);
      expect(CommodityComparisonService.calculateUnitMultiplier('jerrycan 25L'), 25.0);
      expect(CommodityComparisonService.calculateUnitMultiplier('5L gallon'), 5.0);
      expect(CommodityComparisonService.calculateUnitMultiplier('1L bottle'), 1.0);
      expect(CommodityComparisonService.calculateUnitMultiplier('75cl bottle'), 0.75);

      // Discrete count units
      expect(CommodityComparisonService.calculateUnitMultiplier('crate of 30'), 1.0);
      expect(CommodityComparisonService.calculateUnitMultiplier('half crate'), 0.5);
      expect(CommodityComparisonService.calculateUnitMultiplier('heap of 5'), 5.0);
    });

    test('2. Resolves base unit correctly across solid grains, liquids, and produce', () {
      expect(CommodityComparisonService.resolveBaseUnit('1kg', commodityName: 'Rice'), 'kg');
      expect(CommodityComparisonService.resolveBaseUnit('paint bucket', commodityName: 'Garri'), 'kg');
      expect(CommodityComparisonService.resolveBaseUnit('1L', commodityName: 'Palm Oil'), 'L');
      expect(CommodityComparisonService.resolveBaseUnit('25L keg', commodityName: 'Vegetable Oil'), 'L');
      expect(CommodityComparisonService.resolveBaseUnit('crate', commodityName: 'Farm Eggs'), 'crate');
      expect(CommodityComparisonService.resolveBaseUnit('tuber', commodityName: 'Yam'), 'tuber');
    });

    test('3. Computes standardized unit prices fairly across bulk vs retail packages', () {
      // 50kg bag at ₦78,000 -> ₦1,560 / kg
      final bulkRicePrice = CommodityComparisonService.calculateStandardizedUnitPrice(
        price: 78000,
        rawUnit: '50kg bag',
        commodityName: 'Rice',
      );
      expect(bulkRicePrice, 1560.0);

      // 4kg paint bucket at ₦6,600 -> ₦1,650 / kg
      final rubberRicePrice = CommodityComparisonService.calculateStandardizedUnitPrice(
        price: 6600,
        rawUnit: 'paint bucket',
        commodityName: 'Rice',
      );
      expect(rubberRicePrice, 1650.0);

      // 1kg retail at ₦1,850 -> ₦1,850 / kg
      final retailRicePrice = CommodityComparisonService.calculateStandardizedUnitPrice(
        price: 1850,
        rawUnit: '1kg',
        commodityName: 'Rice',
      );
      expect(retailRicePrice, 1850.0);

      // Bulk offers ₦290/kg savings vs retail!
      expect(retailRicePrice - bulkRicePrice, 290.0);
    });

    test('4. Standardizes and ranks quotes according to user preferences', () {
      final now = DateTime.now();
      final quotes = [
        PriceObservation(
          id: 'q-online',
          productId: 'p-rice',
          productName: 'Rice',
          sellerName: 'Jumia Express',
          marketLocation: 'Online Hub',
          price: 1950,
          unit: '1kg',
          timestamp: now,
          sourceType: ObservationSource.onlineGrounded,
          submitterName: 'Web Engine',
          channel: 'Online Retailer',
          isVerified: true,
          standardizedUnitPrice: 1950.0,
          baseUnit: 'kg',
        ),
        PriceObservation(
          id: 'q-market',
          productId: 'p-rice',
          productName: 'Rice',
          sellerName: 'Bodija Market Hub',
          marketLocation: 'Bodija Market Hub',
          price: 1650,
          unit: '1kg',
          timestamp: now,
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Alhaji Musa',
          submitterRole: 'Trader',
          channel: 'Local Market',
          isVerified: true,
          standardizedUnitPrice: 1650.0,
          baseUnit: 'kg',
        ),
        PriceObservation(
          id: 'q-smb',
          productId: 'p-rice',
          productName: 'Rice',
          sellerName: 'Foodco Bodija',
          marketLocation: 'Foodco Bodija',
          price: 1850,
          unit: '1kg',
          timestamp: now,
          sourceType: ObservationSource.communityReported,
          submitterName: 'Shopper',
          channel: 'SMB Store',
          isVerified: false,
          standardizedUnitPrice: 1850.0,
          baseUnit: 'kg',
        ),
      ];

      final standardized = CommodityComparisonService.standardizeQuotes(
        quotes: quotes,
        commodityName: 'Rice',
      );

      // Rank by cheapest unit price
      final rankedByPrice = CommodityComparisonService.rankQuotes(
        quotes: standardized,
        preference: ComparisonSortPreference.cheapestUnitPrice,
      );

      expect(rankedByPrice.first.observation.sellerName, 'Bodija Market Hub');
      expect(rankedByPrice.first.isLowestPrice, isTrue);
      expect(rankedByPrice.first.standardizedUnitPrice, 1650.0);
      expect(rankedByPrice.last.observation.sellerName, 'Jumia Express');
      expect(rankedByPrice.last.priceDifferenceVsLowest, 300.0);

      // Rank by highest trust
      final rankedByTrust = CommodityComparisonService.rankQuotes(
        quotes: standardized,
        preference: ComparisonSortPreference.highestTrust,
      );
      // Trader confirmed with isVerified: true ranks highest
      expect(rankedByTrust.first.observation.sellerName, 'Bodija Market Hub');
    });

    test('5. Calculates arbitrary basket outlay for user-selected quantities and units', () {
      final quote = StandardizedQuote(
        observation: PriceObservation(
          id: 'q-sample',
          productId: 'p1',
          productName: 'Rice',
          sellerName: 'Bodija Market',
          marketLocation: 'Bodija',
          price: 1650,
          unit: '1kg',
          timestamp: DateTime.now(),
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Trader',
        ),
        unitMultiplier: 1.0,
        baseUnit: 'kg',
        standardizedUnitPrice: 1650.0,
        dynamicDistanceKm: 1.2,
      );

      // 5kg at ₦1,650/kg = ₦8,250
      final outlay5kg = quote.calculateOutlayForQuantity(
        requestedQuantity: 5.0,
        requestedUnit: '1kg',
      );
      expect(outlay5kg, 8250.0);

      // 1 paint bucket (4kg) at ₦1,650/kg = ₦6,600
      final outlay1Bucket = quote.calculateOutlayForQuantity(
        requestedQuantity: 1.0,
        requestedUnit: 'paint bucket',
        commodityName: 'Rice',
      );
      expect(outlay1Bucket, 6600.0);
    });

    test('6. Generates analytical summary with price spread and channel bests', () {
      final now = DateTime.now();
      final quotes = [
        PriceObservation(
          id: 'q1',
          productId: 'p1',
          productName: 'Cooking Oil',
          sellerName: 'Bodija Wholesale',
          marketLocation: 'Bodija',
          price: 2850,
          unit: '1L',
          timestamp: now,
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Trader',
          channel: 'Local Market',
          isVerified: true,
          standardizedUnitPrice: 2850.0,
          baseUnit: 'L',
        ),
        PriceObservation(
          id: 'q2',
          productId: 'p1',
          productName: 'Cooking Oil',
          sellerName: 'Ace Supermarket',
          marketLocation: 'Dugbe',
          price: 3100,
          unit: '1L',
          timestamp: now,
          sourceType: ObservationSource.communityReported,
          submitterName: 'Community',
          channel: 'SMB Store',
          isVerified: true,
          standardizedUnitPrice: 3100.0,
          baseUnit: 'L',
        ),
        PriceObservation(
          id: 'q3',
          productId: 'p1',
          productName: 'Cooking Oil',
          sellerName: 'Supermart NG',
          marketLocation: 'Online Platform',
          price: 3300,
          unit: '1L',
          timestamp: now,
          sourceType: ObservationSource.onlineGrounded,
          submitterName: 'System',
          channel: 'Online Retailer',
          isVerified: true,
          standardizedUnitPrice: 3300.0,
          baseUnit: 'L',
        ),
      ];

      final standardized = CommodityComparisonService.standardizeQuotes(
        quotes: quotes,
        commodityName: 'Cooking Oil',
      );

      final summary = CommodityComparisonService.generateSummary(
        quotes: standardized,
        commodityName: 'Cooking Oil',
      );

      expect(summary.lowestUnitPrice, 2850.0);
      expect(summary.highestUnitPrice, 3300.0);
      expect(summary.baseUnit, 'L');
      // Spread = ((3300 - 2850) / 2850) * 100 ≈ 15.78%
      expect(summary.priceSpreadPercentage, closeTo(15.78, 0.1));
      expect(summary.channelBests[SellerChannel.localMarket]?.observation.sellerName, 'Bodija Wholesale');
      expect(summary.channelBests[SellerChannel.smbStore]?.observation.sellerName, 'Ace Supermarket');
      expect(summary.channelBests[SellerChannel.onlineRetailer]?.observation.sellerName, 'Supermart NG');
      expect(summary.keySavingsInsight.contains('Save up to ₦450 / L'), isTrue);
    });

    test('7. Detects price anomalies when an offer is >50% below market average', () {
      final now = DateTime.now();
      final quotes = [
        PriceObservation(
          id: 'q-normal-1',
          productId: 'p1',
          productName: 'Rice',
          sellerName: 'Bodija Market Hub',
          marketLocation: 'Bodija',
          price: 1650,
          unit: '1kg',
          timestamp: now,
          sourceType: ObservationSource.traderConfirmed,
          submitterName: 'Trader',
          channel: 'Local Market',
          standardizedUnitPrice: 1650.0,
        ),
        PriceObservation(
          id: 'q-normal-2',
          productId: 'p1',
          productName: 'Rice',
          sellerName: 'Foodco',
          marketLocation: 'Bodija',
          price: 1850,
          unit: '1kg',
          timestamp: now,
          sourceType: ObservationSource.communityReported,
          submitterName: 'Shopper',
          channel: 'SMB Store',
          standardizedUnitPrice: 1850.0,
        ),
        PriceObservation(
          id: 'q-anomaly',
          productId: 'p1',
          productName: 'Rice',
          sellerName: 'Suspicious Cheap Stall',
          marketLocation: 'Side Street',
          price: 500, // Extremely low (< 50% average)
          unit: '1kg',
          timestamp: now,
          sourceType: ObservationSource.communityReported,
          submitterName: 'Anon',
          channel: 'Local Market',
          standardizedUnitPrice: 500.0,
        ),
      ];

      final standardized = CommodityComparisonService.standardizeQuotes(
        quotes: quotes,
        commodityName: 'Rice',
      );

      final summary = CommodityComparisonService.generateSummary(
        quotes: standardized,
        commodityName: 'Rice',
      );

      expect(summary.anomalies.isNotEmpty, isTrue);
      expect(summary.anomalies.first.contains('>50% below market average'), isTrue);
    });
  });
}

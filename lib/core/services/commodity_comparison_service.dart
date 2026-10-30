import 'dart:math';
import '../models/price_observation.dart';
import 'location_service.dart';

enum ComparisonSortPreference {
  cheapestUnitPrice,
  lowestPrice,
  closestDistance,
  highestTrust,
  bestValue,
}

extension ComparisonSortPreferenceX on ComparisonSortPreference {
  String get label {
    switch (this) {
      case ComparisonSortPreference.cheapestUnitPrice:
        return 'Lowest Unit Price';
      case ComparisonSortPreference.lowestPrice:
        return 'Lowest Total';
      case ComparisonSortPreference.closestDistance:
        return 'Nearest Distance';
      case ComparisonSortPreference.highestTrust:
        return 'Highest Trust';
      case ComparisonSortPreference.bestValue:
        return 'Best Value';
    }
  }
}

/// Standardized breakdown of a seller quote with unit conversions
class StandardizedQuote {
  final PriceObservation observation;
  final double unitMultiplier;
  final String baseUnit;
  final double standardizedUnitPrice;
  final double dynamicDistanceKm;
  final bool isLowestPrice;
  final double priceDifferenceVsLowest;
  final double percentDifferenceVsLowest;

  const StandardizedQuote({
    required this.observation,
    required this.unitMultiplier,
    required this.baseUnit,
    required this.standardizedUnitPrice,
    required this.dynamicDistanceKm,
    this.isLowestPrice = false,
    this.priceDifferenceVsLowest = 0.0,
    this.percentDifferenceVsLowest = 0.0,
  });

  String get displayStandardizedRate =>
      '₦${standardizedUnitPrice.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )} / $baseUnit';

  /// Calculate total cost for any user-requested quantity and target unit
  double calculateOutlayForQuantity({
    required double requestedQuantity,
    required String requestedUnit,
    String? commodityName,
  }) {
    final requestedMultiplier = CommodityComparisonService.calculateUnitMultiplier(
      requestedUnit,
      commodityName: commodityName ?? observation.productName,
    );
    final totalBaseUnits = requestedQuantity * requestedMultiplier;
    return totalBaseUnits * standardizedUnitPrice;
  }
}

/// Comprehensive summary of multi-seller commodity comparison
class ComparisonSummary {
  final String commodityName;
  final String baseUnit;
  final double lowestUnitPrice;
  final double highestUnitPrice;
  final double averageUnitPrice;
  final double priceSpreadPercentage;
  final StandardizedQuote? cheapestQuote;
  final StandardizedQuote? highestQuote;
  final Map<SellerChannel, StandardizedQuote?> channelBests;
  final String keySavingsInsight;
  final List<String> anomalies;

  const ComparisonSummary({
    required this.commodityName,
    required this.baseUnit,
    required this.lowestUnitPrice,
    required this.highestUnitPrice,
    required this.averageUnitPrice,
    required this.priceSpreadPercentage,
    this.cheapestQuote,
    this.highestQuote,
    this.channelBests = const {},
    required this.keySavingsInsight,
    this.anomalies = const [],
  });
}

/// Core Comparison Engine for Standardized Commodity Price Intelligence
class CommodityComparisonService {
  /// Maps raw localized units (50kg bag, paint bucket, derica, 25L keg, crate)
  /// to normalized multiplier count relative to standard base units (kg, L, crate, piece).
  static double calculateUnitMultiplier(
    String rawUnit, {
    String? commodityName,
  }) {
    final u = rawUnit.trim().toLowerCase();
    final name = (commodityName ?? '').toLowerCase();

    // 1. Weight Units (Base: kg)
    if (u.contains('50kg') || u.contains('50 kg')) return 50.0;
    if (u.contains('25kg') || u.contains('25 kg')) return 25.0;
    if (u.contains('10kg') || u.contains('10 kg')) return 10.0;
    if (u.contains('5kg') || u.contains('5 kg')) return 5.0;
    if (u.contains('2kg') || u.contains('2 kg')) return 2.0;
    if (u == '1kg' || u == 'kg' || u == 'kilogram' || u == 'kilo') return 1.0;
    if (u.contains('500g') || u.contains('500 g')) return 0.5;
    if (u.contains('250g') || u.contains('250 g')) return 0.25;

    // Localized Nigerian volumetric grain measures (Paint bucket / Rubber)
    // 4-liter standard plastic paint bucket filled with commodities
    if (u.contains('paint') || u.contains('rubber')) {
      if (name.contains('garri')) return 3.0; // Garri is less dense (~3.0kg per paint bucket)
      if (name.contains('bean')) return 3.2; // Beans ~3.2kg per paint bucket
      return 4.0; // Standard rice, maize, millet (~4.0kg per paint bucket)
    }

    // Derica / Congo tin measure (approx 0.8kg for rice, 0.7kg for beans/garri)
    if (u.contains('derica') || u.contains('derika') || u.contains('congo')) {
      if (u.contains('half')) {
        return name.contains('garri') || name.contains('bean') ? 0.35 : 0.4;
      }
      return name.contains('garri') || name.contains('bean') ? 0.7 : 0.8;
    }

    // 2. Liquid / Volume Units (Base: L)
    if (u.contains('25l') || u.contains('25 liters') || u.contains('keg') || u.contains('jerrycan')) {
      return 25.0;
    }
    if (u.contains('5l') || u.contains('5 liters') || u.contains('gallon')) {
      return 5.0;
    }
    if (u.contains('2l') || u.contains('2 liters')) return 2.0;
    if (u.contains('75cl') || u.contains('750ml')) return 0.75;
    if (u.contains('50cl') || u.contains('500ml')) return 0.5;
    if (u.contains('1l') || u == 'l' || u == 'liter' || u == 'litre' || u.contains('bottle')) {
      return 1.0;
    }

    // 3. Discrete Count / Packaging (Base: crate or piece)
    if (u.contains('crate') || u.contains('30')) {
      if (u.contains('half')) return 0.5;
      return 1.0;
    }
    if (u.contains('heap of 5') || u.contains('heap')) return 5.0;
    if (u.contains('pack of 20')) return 20.0;
    if (u.contains('pack of 10')) return 10.0;
    if (u.contains('dozen')) return 12.0;

    // Default 1:1 if unit is unknown or already singular
    return 1.0;
  }

  /// Determines the fundamental base unit ('kg', 'L', 'crate', 'tuber', 'piece')
  static String resolveBaseUnit(String rawUnit, {String? commodityName}) {
    final u = rawUnit.trim().toLowerCase();
    final name = (commodityName ?? '').toLowerCase();

    // Volume commodities
    if (u.contains('l') ||
        u.contains('liter') ||
        u.contains('litre') ||
        u.contains('cl') ||
        u.contains('ml') ||
        u.contains('keg') ||
        u.contains('jerrycan') ||
        name.contains('oil') ||
        name.contains('water') ||
        name.contains('drink') ||
        name.contains('milk') && !name.contains('tin')) {
      return 'L';
    }

    // Poultry / Egg crates
    if (name.contains('egg') || u.contains('crate')) {
      return 'crate';
    }

    // Produce count
    if (name.contains('yam') || u.contains('tuber')) {
      return 'tuber';
    }

    // Standard solids and grains
    return 'kg';
  }

  /// Calculates the standardized unit price (₦ per base unit)
  static double calculateStandardizedUnitPrice({
    required double price,
    required String rawUnit,
    String? commodityName,
  }) {
    final multiplier = calculateUnitMultiplier(rawUnit, commodityName: commodityName);
    if (multiplier <= 0) return price;
    return price / multiplier;
  }

  /// Standardizes and enriches a list of price observations
  static List<StandardizedQuote> standardizeQuotes({
    required List<PriceObservation> quotes,
    GeoPoint? userLocation,
    String? commodityName,
  }) {
    if (quotes.isEmpty) return const [];

    final resolvedCommodityName = commodityName ?? quotes.first.productName;
    final baseUnit = resolveBaseUnit(quotes.first.unit, commodityName: resolvedCommodityName);

    // Calculate raw standardized rates
    final preprocessed = quotes.map((q) {
      final multiplier = calculateUnitMultiplier(q.unit, commodityName: resolvedCommodityName);
      final standardizedPrice = q.standardizedUnitPrice ??
          (multiplier > 0 ? q.price / multiplier : q.price);

      // Dynamic distance calculation
      double distance = 1.5;
      if (userLocation != null && userLocation.isSet) {
        final marketCoord = LocationService.knownMarketCoordinates[q.sellerName] ??
            LocationService.knownMarketCoordinates[q.marketLocation];
        if (marketCoord != null) {
          distance = LocationService.calculateDistanceKm(
            lat1: userLocation.latitude,
            lon1: userLocation.longitude,
            lat2: marketCoord.latitude,
            lon2: marketCoord.longitude,
          );
        }
      }

      return _TempQuote(
        observation: q,
        multiplier: multiplier,
        standardizedPrice: standardizedPrice,
        distanceKm: distance,
      );
    }).toList();

    // Find the minimum standardized unit price
    final lowestPrice = preprocessed.map((t) => t.standardizedPrice).reduce(min);

    return preprocessed.map((t) {
      final isLowest = t.standardizedPrice <= lowestPrice + 0.01;
      final diff = t.standardizedPrice - lowestPrice;
      final pct = lowestPrice > 0 ? (diff / lowestPrice) * 100 : 0.0;

      return StandardizedQuote(
        observation: t.observation,
        unitMultiplier: t.multiplier,
        baseUnit: baseUnit,
        standardizedUnitPrice: t.standardizedPrice,
        dynamicDistanceKm: t.distanceKm,
        isLowestPrice: isLowest,
        priceDifferenceVsLowest: diff,
        percentDifferenceVsLowest: pct,
      );
    }).toList();
  }

  /// Ranks standardized quotes according to user-selected preference
  static List<StandardizedQuote> rankQuotes({
    required List<StandardizedQuote> quotes,
    required ComparisonSortPreference preference,
  }) {
    final list = List<StandardizedQuote>.from(quotes);

    switch (preference) {
      case ComparisonSortPreference.cheapestUnitPrice:
        list.sort((a, b) => a.standardizedUnitPrice.compareTo(b.standardizedUnitPrice));
        break;

      case ComparisonSortPreference.lowestPrice:
        list.sort((a, b) => a.observation.price.compareTo(b.observation.price));
        break;

      case ComparisonSortPreference.closestDistance:
        list.sort((a, b) => a.dynamicDistanceKm.compareTo(b.dynamicDistanceKm));
        break;

      case ComparisonSortPreference.highestTrust:
        list.sort((a, b) {
          // Compare verification status and stock first
          final scoreA = _trustScore(a.observation);
          final scoreB = _trustScore(b.observation);
          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          return a.standardizedUnitPrice.compareTo(b.standardizedUnitPrice);
        });
        break;

      case ComparisonSortPreference.bestValue:
        // Composite scoring: 50% price, 25% distance, 25% trust
        if (list.length <= 1) return list;
        final minPrice = list.map((q) => q.standardizedUnitPrice).reduce(min);
        final maxPrice = list.map((q) => q.standardizedUnitPrice).reduce(max);
        final minDistance = list.map((q) => q.dynamicDistanceKm).reduce(min);
        final maxDistance = list.map((q) => q.dynamicDistanceKm).reduce(max);

        list.sort((a, b) {
          final priceScoreA = maxPrice > minPrice
              ? 1.0 - ((a.standardizedUnitPrice - minPrice) / (maxPrice - minPrice))
              : 1.0;
          final priceScoreB = maxPrice > minPrice
              ? 1.0 - ((b.standardizedUnitPrice - minPrice) / (maxPrice - minPrice))
              : 1.0;

          final distScoreA = maxDistance > minDistance
              ? 1.0 - ((a.dynamicDistanceKm - minDistance) / (maxDistance - minDistance))
              : 1.0;
          final distScoreB = maxDistance > minDistance
              ? 1.0 - ((b.dynamicDistanceKm - minDistance) / (maxDistance - minDistance))
              : 1.0;

          final trustScoreA = _trustScore(a.observation) / 5.0;
          final trustScoreB = _trustScore(b.observation) / 5.0;

          final totalA = (priceScoreA * 0.50) + (distScoreA * 0.25) + (trustScoreA * 0.25);
          final totalB = (priceScoreB * 0.50) + (distScoreB * 0.25) + (trustScoreB * 0.25);

          return totalB.compareTo(totalA);
        });
        break;
    }

    return list;
  }

  /// Generates an analytical comparison summary with channel bests and savings breakdown
  static ComparisonSummary generateSummary({
    required List<StandardizedQuote> quotes,
    String? commodityName,
  }) {
    if (quotes.isEmpty) {
      return const ComparisonSummary(
        commodityName: 'Commodity',
        baseUnit: 'kg',
        lowestUnitPrice: 0,
        highestUnitPrice: 0,
        averageUnitPrice: 0,
        priceSpreadPercentage: 0,
        keySavingsInsight: 'No price observations available to compare.',
      );
    }

    final resolvedName = commodityName ?? quotes.first.observation.productName;
    final baseUnit = quotes.first.baseUnit;

    final sortedByPrice = List<StandardizedQuote>.from(quotes)
      ..sort((a, b) => a.standardizedUnitPrice.compareTo(b.standardizedUnitPrice));

    final lowest = sortedByPrice.first;
    final highest = sortedByPrice.last;
    final sumPrice = quotes.fold<double>(0.0, (acc, q) => acc + q.standardizedUnitPrice);
    final avgPrice = sumPrice / quotes.length;

    final spread = lowest.standardizedUnitPrice > 0
        ? ((highest.standardizedUnitPrice - lowest.standardizedUnitPrice) /
                lowest.standardizedUnitPrice) *
            100
        : 0.0;

    // Determine channel bests
    final channelBests = <SellerChannel, StandardizedQuote?>{};
    for (final channel in SellerChannel.values) {
      final channelQuotes = quotes
          .where((q) => q.observation.sellerChannel == channel)
          .toList()
        ..sort((a, b) => a.standardizedUnitPrice.compareTo(b.standardizedUnitPrice));
      if (channelQuotes.isNotEmpty) {
        channelBests[channel] = channelQuotes.first;
      }
    }

    // Generate clear, honest savings insight
    final savingsPerUnit = highest.standardizedUnitPrice - lowest.standardizedUnitPrice;
    final String insight;
    if (savingsPerUnit > 0) {
      insight =
          'Save up to ₦${savingsPerUnit.toStringAsFixed(0)} / $baseUnit (${spread.toStringAsFixed(0)}%) by buying from ${lowest.observation.sellerName} (${lowest.observation.sellerChannel.displayName}) compared to ${highest.observation.sellerName}.';
    } else {
      insight =
          'Prices are uniformly competitive across verified sellers in this market area at ₦${lowest.standardizedUnitPrice.toStringAsFixed(0)} / $baseUnit.';
    }

    // Detect price anomalies (>50% lower or >60% higher than average)
    final anomalies = <String>[];
    for (final q in quotes) {
      if (q.standardizedUnitPrice < avgPrice * 0.50) {
        anomalies.add(
            '${q.observation.sellerName} (₦${q.standardizedUnitPrice.toStringAsFixed(0)}/$baseUnit) is >50% below market average. Verify product grade and authenticity.');
      } else if (q.standardizedUnitPrice > avgPrice * 1.60) {
        anomalies.add(
            '${q.observation.sellerName} (₦${q.standardizedUnitPrice.toStringAsFixed(0)}/$baseUnit) is substantially above market average.');
      }
    }

    return ComparisonSummary(
      commodityName: resolvedName,
      baseUnit: baseUnit,
      lowestUnitPrice: lowest.standardizedUnitPrice,
      highestUnitPrice: highest.standardizedUnitPrice,
      averageUnitPrice: avgPrice,
      priceSpreadPercentage: spread,
      cheapestQuote: lowest,
      highestQuote: highest,
      channelBests: channelBests,
      keySavingsInsight: insight,
      anomalies: anomalies,
    );
  }

  static int _trustScore(PriceObservation obs) {
    int score = 0;
    if (obs.inStock) score += 2;
    if (obs.isVerified) score += 3;

    switch (obs.sourceType) {
      case ObservationSource.independentlyVerified:
        score += 5;
        break;
      case ObservationSource.traderConfirmed:
        score += 4;
        break;
      case ObservationSource.onlineGrounded:
        score += 3;
        break;
      case ObservationSource.traderProvided:
        score += 3;
        break;
      case ObservationSource.communityReported:
        score += 2;
        break;
      case ObservationSource.simulatedDemo:
        score += 1;
        break;
    }
    return score;
  }
}

class _TempQuote {
  final PriceObservation observation;
  final double multiplier;
  final double standardizedPrice;
  final double distanceKm;

  _TempQuote({
    required this.observation,
    required this.multiplier,
    required this.standardizedPrice,
    required this.distanceKm,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/product.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/commodity_item.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/commodity_comparison_service.dart';
import '../../../core/state/app_state.dart';
import '../../../core/presentation/widgets/commodity_image_widget.dart';
import '../../../core/presentation/widgets/seller_location_map_sheet.dart';
import '../../../core/presentation/widgets/community_assistance_sheet.dart';
import '../../../core/presentation/widgets/report_modal_sheet.dart';
import '../../../core/models/item_acquisition_source.dart';
import '../../decision_lab/presentation/widgets/trader_negotiation_sheet.dart';
import '../../../core/presentation/widgets/seller_catalog_sheet.dart';

class ProductDetailSheet extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailSheet({super.key, required this.product});

  @override
  ConsumerState<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<ProductDetailSheet> {
  double _quantity = 1.0;
  String? _selectedChannelFilter;
  ComparisonSortPreference _sortPreference =
      ComparisonSortPreference.cheapestUnitPrice;

  String _formatAmount(double amount) {
    return '₦${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  void _showReportStaleDialog(BuildContext context) {
    final observations = ref.read(communityProvider);
    final matchingObs = observations.cast<PriceObservation?>().firstWhere(
      (o) =>
          o != null &&
          (o.productId == widget.product.id ||
              o.productName.toLowerCase().contains(widget.product.name.toLowerCase()) ||
              widget.product.name.toLowerCase().contains(o.productName.toLowerCase())),
      orElse: () => null,
    );

    final targetObs = matchingObs ??
        PriceObservation(
          id: 'obs-${widget.product.id}',
          productId: widget.product.id,
          productName: widget.product.name,
          sellerName: widget.product.bestSeller,
          marketLocation: widget.product.bestSeller,
          price: widget.product.lowestPrice,
          unit: widget.product.standardUnit,
          timestamp: DateTime.now(),
          sourceType: ObservationSource.communityReported,
          submitterName: 'Market Shopper',
          channel: widget.product.channel,
          inStock: true,
        );

    ReportModalSheet.show(context, targetObs);
  }

  static String _cleanCommodityKey(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\b\d+(?:kg|g|l|cl|ml|k)?\b'), '')
        .replaceAll(RegExp(r'\b(?:bag|carton|crate|tuber|paint rubber|derica|congo|bottle|gallon|jerrycan|pack|piece|unit)\b'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
  }

  static String _cleanSellerKey(String seller) {
    return seller
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'\b(?:market hub|market|stalls|stall|depot|store|mart|supermarket|ventures|enterprise)\b'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
  }

  static bool _isSameOrSimilarCommodity(String prodNameA, String prodNameB) {
    final keyA = _cleanCommodityKey(prodNameA);
    final keyB = _cleanCommodityKey(prodNameB);
    if (keyA.isEmpty || keyB.isEmpty) return false;
    if (keyA == keyB) return true;

    final wordsA = keyA.split(RegExp(r'\s+')).where((w) => w.length >= 3).toSet();
    final wordsB = keyB.split(RegExp(r'\s+')).where((w) => w.length >= 3).toSet();
    final intersection = wordsA.intersection(wordsB);

    if (intersection.isNotEmpty) {
      if (keyA.contains('palm') && !keyB.contains('palm')) return false;
      if (!keyA.contains('palm') && keyB.contains('palm')) return false;
      return true;
    }
    return false;
  }

  List<PriceObservation> _getAlternativeQuotes(
    List<PriceObservation> communityObs,
  ) {
    final currentSellerKey = _cleanSellerKey(widget.product.bestSeller);
    final currentSellerRaw = widget.product.bestSeller.trim().toLowerCase();

    // Group alternative candidates strictly by distinct seller
    final Map<String, PriceObservation> bestQuotePerSeller = {};

    for (final obs in communityObs) {
      // 1. Exclude the product itself
      if (obs.id == widget.product.id ||
          (obs.productId.isNotEmpty &&
              obs.productId == widget.product.id &&
              obs.id.startsWith('listing-'))) {
        continue;
      }

      // 2. Must be the same or similar commodity
      if (!_isSameOrSimilarCommodity(obs.productName, widget.product.name)) {
        continue;
      }

      // 3. Must be from a DIFFERENT seller (never compare against the same seller or itself)
      final obsSellerKey = _cleanSellerKey(obs.sellerName);
      final obsSellerRaw = obs.sellerName.trim().toLowerCase();
      if (obsSellerRaw == currentSellerRaw ||
          (currentSellerKey.isNotEmpty && obsSellerKey == currentSellerKey)) {
        continue;
      }
      if (currentSellerKey.isNotEmpty && obsSellerKey.isNotEmpty) {
        if (obsSellerKey.contains(currentSellerKey) ||
            currentSellerKey.contains(obsSellerKey)) {
          continue;
        }
      }

      // 4. Deduplicate multiple listings from the same alternative seller (keep their lowest price)
      final sellerMapKey =
          obsSellerKey.isNotEmpty ? obsSellerKey : obsSellerRaw;
      final existing = bestQuotePerSeller[sellerMapKey];
      if (existing == null || obs.price < existing.price) {
        bestQuotePerSeller[sellerMapKey] = obs;
      }
    }

    return bestQuotePerSeller.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final observations = ref.watch(communityProvider);
    final alternativeQuotes = _getAlternativeQuotes(observations);
    final hasAlternatives = alternativeQuotes.isNotEmpty;
    final currentLocation = ref.watch(locationProvider);

    final basePrice = widget.product.lowestPrice;
    final productQuote = PriceObservation(
      id: 'listing-${widget.product.id}',
      productId: widget.product.id,
      productName: widget.product.name,
      sellerName: widget.product.bestSeller,
      marketLocation: '${widget.product.bestSeller} (Current Seller)',
      price: basePrice,
      unit: widget.product.standardUnit,
      timestamp: DateTime.now(),
      sourceType: widget.product.sourceType,
      submitterName: widget.product.bestSeller,
      submitterRole: 'Trader',
      isVerified: widget.product.sourceType == ObservationSource.independentlyVerified ||
          widget.product.sourceType == ObservationSource.traderConfirmed,
      channel: widget.product.channel.isNotEmpty ? widget.product.channel : 'Local Market',
      brandOrGrade: widget.product.brandOrGrade ?? 'Grade A / Market Benchmark',
      standardizedUnitPrice: widget.product.standardizedUnitPrice ?? basePrice,
      baseUnit: widget.product.baseUnit,
      inStock: true,
      notes: 'Current product listing.',
    );

    // Only combine with current product for comparison if genuine alternatives from other sellers exist
    final allComparisonQuotes = hasAlternatives
        ? [productQuote, ...alternativeQuotes]
        : <PriceObservation>[productQuote];

    final standardizedQuotes = CommodityComparisonService.standardizeQuotes(
      quotes: allComparisonQuotes,
      userLocation: currentLocation,
      commodityName: widget.product.name,
    );

    final comparisonSummary = CommodityComparisonService.generateSummary(
      quotes: standardizedQuotes,
      commodityName: widget.product.name,
    );

    // Filter alternative seller quotes only (excluding current product listing from alternative cards)
    var filteredQuotes = standardizedQuotes
        .where((q) => q.observation.id != productQuote.id)
        .toList();

    if (_selectedChannelFilter != null) {
      filteredQuotes = filteredQuotes
          .where((q) => q.observation.channel.toLowerCase() == _selectedChannelFilter!.toLowerCase())
          .toList();
    }

    filteredQuotes = CommodityComparisonService.rankQuotes(
      quotes: filteredQuotes,
      preference: _sortPreference,
    );

    final lowestQuotePrice = allComparisonQuotes.isNotEmpty
        ? allComparisonQuotes.map((q) => q.price).reduce((a, b) => a < b ? a : b)
        : widget.product.lowestPrice;

    final estimatedBasketTotal = lowestQuotePrice * _quantity;

    // Price History Trend: Only when genuine historical observations exist across time
    final historyQuotes =
        observations
            .where(
              (o) =>
                  (o.productId == widget.product.id ||
                      o.productName.toLowerCase() ==
                          widget.product.name.toLowerCase() ||
                      widget.product.name.toLowerCase().contains(
                        o.productName.toLowerCase(),
                      )) &&
                  o.isVerified,
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final hasHistoricalTrend = historyQuotes.length >= 3;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Product Hero Header
            Row(
              children: [
                CommodityImageWidget(
                  commodityName: widget.product.name,
                  imageUrl: widget.product.imageUrl,
                  size: 58,
                  borderRadius: 16,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Standard Unit: ${widget.product.standardUnit} • ${widget.product.category}${widget.product.brandOrGrade != null ? ' • ${widget.product.brandOrGrade}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price & Best Seller Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.product.formattedPrice,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'per ${widget.product.standardUnit}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Builder(
                          builder: (context) {
                            final currentLocation = ref.watch(locationProvider);
                            final dynamicDistance = LocationService.resolveDistanceKm(
                              userLocation: currentLocation,
                              destLocationName: widget.product.bestSeller,
                            );
                            final effectiveDist = dynamicDistance > 0
                                ? dynamicDistance
                                : (widget.product.distanceKm > 0
                                    ? widget.product.distanceKm
                                    : null);

                            return Row(
                              children: [
                                const Icon(
                                  Icons.store_outlined,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    effectiveDist != null
                                        ? '${widget.product.bestSeller} • ${effectiveDist.toStringAsFixed(1)} km away'
                                        : '${widget.product.bestSeller} • Open Market',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.badgeSuccessBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Best Price',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.badgeSuccessText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Explicit Data Source Label (Mandatory Hackathon Section 5.2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.product.sourceType == ObservationSource.simulatedDemo
                        ? Icons.info_outline_rounded
                        : Icons.verified_outlined,
                    color:
                        widget.product.sourceType ==
                            ObservationSource.simulatedDemo
                        ? AppColors.textSecondary
                        : AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Source: ${widget.product.sourceType.displayLabel} • ${widget.product.updateTime}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Multi-Seller Comparison Matrix Section (Section 5.2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Multi-Seller Comparison',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  hasAlternatives
                      ? '${alternativeQuotes.length} alternative seller(s)'
                      : 'No other sellers',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasAlternatives
                  ? 'Comparing identical / similar ${widget.product.name} quotes from different sellers.'
                  : 'Only one seller is currently listing this product on the platform.',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            if (!hasAlternatives) ...[
              Container(
                key: const ValueKey('card_no_alternative_sellers'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 40, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    const Text(
                      'No Alternative Sellers Available Yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This product is currently only available from ${widget.product.bestSeller}. No other verified traders or community members have logged alternative quotes for this commodity yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                      label: const Text(
                        'Report Quote from Another Stall',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/products');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              // Comparison Summary Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.badgeSuccessBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Price Spread: ${comparisonSummary.priceSpreadPercentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.badgeSuccessText,
                            ),
                          ),
                        ),
                        Text(
                          'Lowest: ₦${comparisonSummary.lowestUnitPrice.toStringAsFixed(0)} / ${comparisonSummary.baseUnit}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      comparisonSummary.keySavingsInsight,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (comparisonSummary.anomalies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFB74D)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Color(0xFFE65100),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                comparisonSummary.anomalies.first,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFBF360C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Sort Preference Selector
              Row(
                children: [
                  const Text(
                    'Sort by:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ComparisonSortPreference.values.map((pref) {
                          final isSelected = _sortPreference == pref;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(
                                pref.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primaryTint,
                              onSelected: (val) {
                                if (val) setState(() => _sortPreference = pref);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Channel Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChannelFilterChip(label: 'All Channels', channel: null),
                    const SizedBox(width: 6),
                    _buildChannelFilterChip(
                      label: 'Local Market',
                      channel: 'Local Market',
                    ),
                    const SizedBox(width: 6),
                    _buildChannelFilterChip(
                      label: 'SMB Store',
                      channel: 'SMB Store',
                    ),
                    const SizedBox(width: 6),
                    _buildChannelFilterChip(
                      label: 'Online Retailer',
                      channel: 'Online Retailer',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Multi-Seller Quote Cards
              if (filteredQuotes.isNotEmpty) ...[
                ...filteredQuotes.map((sq) {
                  final obs = sq.observation;
                  final isLowest = sq.isLowestPrice;
                  final diff = sq.priceDifferenceVsLowest;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isLowest
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.cardBorder,
                        width: isLowest ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Channel & Verification Badges Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildChannelBadge(obs.sellerChannel),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: obs.inStock
                                        ? AppColors.badgeSuccessText
                                        : AppColors.errorText,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  obs.inStock ? 'In Stock' : 'Out of Stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: obs.inStock
                                        ? AppColors.badgeSuccessText
                                        : AppColors.errorText,
                                  ),
                                ),
                                if (obs.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Seller Name & Price Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    obs.sellerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    sq.dynamicDistanceKm > 0
                                        ? '${obs.marketLocation} • ${sq.dynamicDistanceKm.toStringAsFixed(1)} km away • ${obs.sourceType.displayLabel}'
                                        : '${obs.marketLocation} • ${obs.sourceType.displayLabel}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (obs.brandOrGrade != null &&
                                      obs.brandOrGrade!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Grade: ${obs.brandOrGrade}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  obs.formattedPrice,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  sq.displayStandardizedRate,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (isLowest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.badgeSuccessBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Lowest Price',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.badgeSuccessText,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '+₦${diff.toStringAsFixed(0)} (+${sq.percentDifferenceVsLowest.toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.badgeWarningText,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Outlay for selected quantity
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Outlay for ${_quantity.toInt()} ${widget.product.standardUnit}:',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '₦${(obs.price * _quantity).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Builder(builder: (context) {
                          final isVerifiedTrader = obs.isVerified ||
                              obs.sourceType == ObservationSource.traderConfirmed ||
                              obs.sourceType == ObservationSource.traderProvided;

                          if (isVerifiedTrader) {
                            return Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                      side: const BorderSide(color: AppColors.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(Icons.explore_outlined, size: 15),
                                    label: const Text(
                                      'Locate Stall',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                    onPressed: () {
                                      SellerLocationMapSheet.show(
                                        context,
                                        sellerName: obs.sellerName,
                                        marketLocation: obs.marketLocation,
                                        stallLocation: obs.notes,
                                        productName: obs.productName,
                                        price: obs.price,
                                        unit: obs.unit,
                                        brandOrGrade: obs.brandOrGrade,
                                        inStock: obs.inStock,
                                        observation: obs,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline, size: 15),
                                    label: const Text(
                                      'Chat & Buy',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                    onPressed: () {
                                      final source = ItemAcquisitionSource(
                                        id: 'src-${obs.sellerName.toLowerCase().replaceAll(' ', '-')}',
                                        itemId: 'item-${widget.product.id}',
                                        commodityName: obs.productName,
                                        quantity: _quantity,
                                        unit: obs.unit,
                                        unitPrice: obs.price,
                                        totalCost: obs.price * _quantity,
                                        outletName: obs.sellerName,
                                        channel: obs.sellerChannel == SellerChannel.onlineRetailer
                                            ? AcquisitionChannel.ecommercePlatform
                                            : AcquisitionChannel.registeredTrader,
                                        marketHubOrLocation: obs.marketLocation,
                                        dynamicDistanceKm: sq.dynamicDistanceKm,
                                        isPlatformRegisteredTrader: obs.isVerified,
                                        inStock: obs.inStock,
                                        brandOrGrade: obs.brandOrGrade,
                                      );
                                      TraderNegotiationSheet.show(context, source: source);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                  style: IconButton.styleFrom(
                                    side: const BorderSide(color: AppColors.primary),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.storefront_outlined, size: 16, color: AppColors.primary),
                                  tooltip: 'Check Seller Catalog',
                                  onPressed: () => SellerCatalogSheet.show(
                                    context,
                                    sellerName: obs.sellerName,
                                    currentCommodityName: obs.productName,
                                    initialMarketLocation: obs.marketLocation,
                                  ),
                                ),
                              ],
                            );
                          }

                          // Community Observation: No formal stall pin; offer directions & contact assistance
                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: const ValueKey('btn_community_help'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                    side: const BorderSide(color: Color(0xFFE65100)),
                                    foregroundColor: const Color(0xFFE65100),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.help_outline_rounded, size: 15, color: Color(0xFFE65100)),
                                  label: const Text(
                                    'Get Stall Help',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: () {
                                    CommunityAssistanceSheet.show(context, observation: obs);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  key: const ValueKey('btn_ask_scout_help'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE65100),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.people_alt_outlined, size: 15),
                                  label: const Text(
                                    'Ask Reporter / Scout',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: () {
                                    CommunityAssistanceSheet.show(context, observation: obs);
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            obs.isFlaggedAnomaly ? Icons.flag_rounded : Icons.flag_outlined,
                            size: 16,
                            color: obs.isFlaggedAnomaly ? const Color(0xFFC62828) : AppColors.textTertiary,
                          ),
                          tooltip: obs.isFlaggedAnomaly ? 'Listing Reported' : 'Report Product or Seller',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => ReportModalSheet.show(context, obs),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No alternative seller quotes in this channel filter.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 14),

            // Price History Section: Only rendered when genuine historical observations exist across time
            if (hasHistoricalTrend) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Price History Trend',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Based on verified reports',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _PriceHistoryLinePainter(
                          prices: historyQuotes.map((q) => q.price).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.query_stats_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Price history hidden: requires at least 3 confirmed observations across time.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Quantity Selection & Total Outlay Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantity to Compare:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _quantity > 1.0
                                ? () => setState(
                                    () => _quantity = (_quantity - 1.0).clamp(
                                      1.0,
                                      100.0,
                                    ),
                                  )
                                : null,
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 20,
                            ),
                            color: AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${_quantity.toInt()} ${widget.product.standardUnit}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(
                              () => _quantity = (_quantity + 1.0).clamp(
                                1.0,
                                100.0,
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 20,
                            ),
                            color: AppColors.primary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Quantity quick preset chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [1.0, 2.0, 5.0, 10.0, 25.0].map((qty) {
                        final isSelected = _quantity == qty;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              '${qty.toInt()} ${widget.product.standardUnit}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primaryTint,
                            onSelected: (val) {
                              if (val) setState(() => _quantity = qty);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated Basket Outlay:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _formatAmount(estimatedBasketTotal),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CTAs: Add to Comparison Basket & Report Stale Observation
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final item = ShoppingItem(
                          id: 'item-${widget.product.id}-${DateTime.now().millisecondsSinceEpoch}',
                          productId: widget.product.id,
                          productName: widget.product.name,
                          quantity: _quantity,
                          unit: widget.product.standardUnit,
                          estimatedUnitPrice: lowestQuotePrice,
                          priority: CommodityPriority.essential,
                          brandOrGrade:
                              widget.product.brandOrGrade ?? 'Standard Grade',
                          standardizedUnit: widget.product.baseUnit,
                          specification:
                              'Added from Discover catalog comparison',
                        );
                        ref
                            .read(decisionLabProvider.notifier)
                            .addShoppingItem(item);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.primary,
                            content: Text(
                              'Added ${_quantity.toInt()} ${widget.product.standardUnit} of ${widget.product.name} to Comparison Basket!',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 18,
                      ),
                      label: Text(
                        'Add to Comparison Basket (${_formatAmount(estimatedBasketTotal)})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showReportStaleDialog(context),
                  tooltip: 'Report Stale or Suspicious Observation',
                  icon: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.badgeWarningText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildChannelFilterChip({
    required String label,
    required String? channel,
  }) {
    final isSelected = _selectedChannelFilter == channel;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: AppColors.primaryTint,
      onSelected: (val) {
        setState(() {
          _selectedChannelFilter = channel;
        });
      },
    );
  }

  Widget _buildChannelBadge(SellerChannel channel) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (channel) {
      case SellerChannel.onlineRetailer:
        bg = const Color(0xFFE8EAF6);
        fg = const Color(0xFF283593);
        icon = Icons.language_rounded;
        label = 'Online Retailer';
        break;
      case SellerChannel.smbStore:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        icon = Icons.local_convenience_store_rounded;
        label = 'SMB Store';
        break;
      case SellerChannel.localMarket:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.storefront_rounded;
        label = 'Local Market';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

}

class _PriceHistoryLinePainter extends CustomPainter {
  final List<double> prices;

  const _PriceHistoryLinePainter({required this.prices});

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 3) return;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    final path = Path();
    for (int i = 0; i < prices.length; i++) {
      final x = (i / (prices.length - 1)) * (size.width - 8) + 4;
      final normalized = priceRange > 0
          ? (prices[i] - minPrice) / priceRange
          : 0.5;
      final y = size.height - (normalized * (size.height - 12) + 6);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PriceHistoryLinePainter oldDelegate) =>
      oldDelegate.prices != prices;
}

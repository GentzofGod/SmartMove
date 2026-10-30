import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/product.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/commodity_item.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/meta_ai_service.dart';
import '../../../core/services/commodity_comparison_service.dart';
import '../../../core/state/app_state.dart';

class ProductDetailSheet extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailSheet({super.key, required this.product});

  @override
  ConsumerState<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<ProductDetailSheet> {
  double _quantity = 1.0;
  String? _selectedChannelFilter;
  ComparisonSortPreference _sortPreference = ComparisonSortPreference.cheapestUnitPrice;
  bool _showAiAnalysis = false;
  UserDecisionPriority _decisionPriority = UserDecisionPriority.balancedValue;
  bool _showExpandedCriteria = false;
  final MetaAiService _metaAiService = const MetaAiService();

  String _formatAmount(double amount) {
    return '₦${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  void _showReportStaleDialog(BuildContext context) {
    String selectedReason = 'Price is higher in market';
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Report Price Observation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Help the community keep commodity price intelligence honest and up to date.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Reason choices
                  ...['Price is higher in market', 'Seller is out of stock', 'Suspicious / inaccurate report']
                      .map((reason) {
                        final isSelected = selectedReason == reason;
                        return InkWell(
                          onTap: () => setModalState(() => selectedReason = reason),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryTint : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  size: 16,
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'Optional notes (e.g. Current price seen is ₦1,850)',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report submitted. Thank you for keeping local commodity prices verified!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.badgeWarningText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit Observation Flag',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<PriceObservation> _getComparisonQuotes(List<PriceObservation> communityObs) {
    final matching = communityObs
        .where((o) =>
            o.productId == widget.product.id ||
            o.productName.toLowerCase() == widget.product.name.toLowerCase() ||
            o.productName.toLowerCase().contains(widget.product.name.toLowerCase()) ||
            widget.product.name.toLowerCase().contains(o.productName.toLowerCase()))
        .toList();

    final basePrice = widget.product.lowestPrice;

    // Genuine product listing observation from catalog
    final productQuote = PriceObservation(
      id: 'listing-${widget.product.id}',
      productId: widget.product.id,
      productName: widget.product.name,
      sellerName: widget.product.bestSeller,
      marketLocation: '${widget.product.bestSeller} (Open Market)',
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
      notes: 'Direct listing price.',
    );

    final quotes = <PriceObservation>[productQuote];
    for (final obs in matching) {
      final isDuplicate = quotes.any((q) =>
          q.id == obs.id ||
          (q.sellerName.toLowerCase() == obs.sellerName.toLowerCase() &&
              (q.price - obs.price).abs() < 0.01));
      if (!isDuplicate) {
        quotes.add(obs);
      }
    }
    return quotes;
  }

  @override
  Widget build(BuildContext context) {
    final observations = ref.watch(communityProvider);
    final comparisonQuotes = _getComparisonQuotes(observations);
    final currentLocation = ref.watch(locationProvider);

    final standardizedQuotes = CommodityComparisonService.standardizeQuotes(
      quotes: comparisonQuotes,
      userLocation: currentLocation,
      commodityName: widget.product.name,
    );

    final comparisonSummary = CommodityComparisonService.generateSummary(
      quotes: standardizedQuotes,
      commodityName: widget.product.name,
    );

    var filteredQuotes = _selectedChannelFilter == null
        ? standardizedQuotes
        : standardizedQuotes
            .where((q) => q.observation.channel.toLowerCase() == _selectedChannelFilter!.toLowerCase())
            .toList();

    filteredQuotes = CommodityComparisonService.rankQuotes(
      quotes: filteredQuotes,
      preference: _sortPreference,
    );

    final lowestQuotePrice = comparisonQuotes.isNotEmpty
        ? comparisonQuotes.map((q) => q.price).reduce((a, b) => a < b ? a : b)
        : widget.product.lowestPrice;

    final estimatedBasketTotal = lowestQuotePrice * _quantity;

    final multiCriteriaResult = _metaAiService.analyzeAvailableOptions(
      product: widget.product,
      observations: comparisonQuotes,
      requestedQuantity: _quantity,
      priority: _decisionPriority,
      userLocation: currentLocation,
    );

    // Price History Trend: Only when genuine historical observations exist across time
    final historyQuotes = observations
        .where((o) =>
            (o.productId == widget.product.id ||
                o.productName.toLowerCase() == widget.product.name.toLowerCase() ||
                widget.product.name.toLowerCase().contains(o.productName.toLowerCase())) &&
            o.isVerified)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final hasHistoricalTrend = historyQuotes.length >= 3;

    return Container(
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
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
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
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Builder(
                          builder: (context) {
                            final currentLocation = ref.watch(locationProvider);
                            final marketCoord = LocationService.knownMarketCoordinates[widget.product.bestSeller];
                            final dynamicDistance = (currentLocation.isSet && marketCoord != null)
                                ? LocationService.calculateDistanceKm(
                                    lat1: currentLocation.latitude,
                                    lon1: currentLocation.longitude,
                                    lat2: marketCoord.latitude,
                                    lon2: marketCoord.longitude,
                                  )
                                : (currentLocation.isSet ? widget.product.distanceKm : null);

                            return Row(
                              children: [
                                const Icon(Icons.store_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    dynamicDistance != null
                                        ? '${widget.product.bestSeller} • $dynamicDistance km away'
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    color: widget.product.sourceType == ObservationSource.simulatedDemo
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
                  '${comparisonQuotes.length} quotes',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Prices standardized per unit to ensure fair comparison across channels.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            // Comparison Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      height: 1.35,
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
                          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE65100)),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
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
                            label: Text(pref.label, style: const TextStyle(fontSize: 11)),
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
                  _buildChannelFilterChip(label: 'Local Market', channel: 'Local Market'),
                  const SizedBox(width: 6),
                  _buildChannelFilterChip(label: 'SMB Store', channel: 'SMB Store'),
                  const SizedBox(width: 6),
                  _buildChannelFilterChip(label: 'Online Retailer', channel: 'Online Retailer'),
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
                      color: isLowest ? AppColors.primary.withValues(alpha: 0.4) : AppColors.cardBorder,
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
                                  color: obs.inStock ? AppColors.badgeSuccessText : AppColors.errorText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                obs.inStock ? 'In Stock' : 'Out of Stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: obs.inStock ? AppColors.badgeSuccessText : AppColors.errorText,
                                ),
                              ),
                              if (obs.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, size: 14, color: AppColors.primary),
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
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${obs.marketLocation} • ${sq.dynamicDistanceKm.toStringAsFixed(1)} km away • ${obs.sourceType.displayLabel}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                if (obs.brandOrGrade != null && obs.brandOrGrade!.isNotEmpty) ...[
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
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 2),
                              if (isLowest)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Outlay for ${_quantity.toInt()} ${widget.product.standardUnit}:',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            Text(
                              '₦${(obs.price * _quantity).toStringAsFixed(0).replaceAllMapped(
                                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                    (Match m) => '${m[1]},',
                                  )}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
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
                  'No seller reports logged in this channel yet. Submit yours in Community tab!',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Meta AI Muse Spark Multi-Criteria Options Analysis
            _buildMultiCriteriaAnalysisSection(multiCriteriaResult),
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Based on verified reports',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.query_stats_rounded, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Price history hidden: requires at least 3 confirmed observations across time.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _quantity > 1.0
                                ? () => setState(() => _quantity = (_quantity - 1.0).clamp(1.0, 100.0))
                                : null,
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            color: AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${_quantity.toInt()} ${widget.product.standardUnit}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _quantity = (_quantity + 1.0).clamp(1.0, 100.0)),
                            icon: const Icon(Icons.add_circle_outline, size: 20),
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
                  Row(
                    children: [1.0, 2.0, 5.0, 10.0, 25.0].map((qty) {
                      final isSelected = _quantity == qty;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('${qty.toInt()} ${widget.product.standardUnit}', style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          selectedColor: AppColors.primaryTint,
                          onSelected: (val) {
                            if (val) setState(() => _quantity = qty);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated Basket Outlay:',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                          brandOrGrade: widget.product.brandOrGrade ?? 'Standard Grade',
                          standardizedUnit: widget.product.baseUnit,
                          specification: 'Added from Discover catalog comparison',
                        );
                        ref.read(decisionLabProvider.notifier).addShoppingItem(item);
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
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: Text(
                        'Add to Comparison Basket (${_formatAmount(estimatedBasketTotal)})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showReportStaleDialog(context),
                  tooltip: 'Report Stale or Suspicious Observation',
                  icon: const Icon(Icons.flag_outlined, color: AppColors.badgeWarningText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelFilterChip({required String label, required String? channel}) {
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

  Widget _buildMultiCriteriaAnalysisSection(MultiCriteriaAnalysisResult result) {
    final rec = result.recommendedOption;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible Header
          InkWell(
            onTap: () => setState(() => _showAiAnalysis = !_showAiAnalysis),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Meta AI Multi-Criteria Options Matrix',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Evaluated on Distance, Price, Quality, Delivery, Trust & Support',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showAiAnalysis ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primaryDark,
                  ),
                ],
              ),
            ),
          ),

          if (_showAiAnalysis) ...[
            const Divider(height: 1, color: Color(0xFFC8E6C9)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Priority Selection Header & Chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Buyer Priority Preference:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Text(
                          '${result.evaluatedOptions.length} Options Evaluated',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: UserDecisionPriority.values.map((p) {
                        final isSel = _decisionPriority == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              p.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: AppColors.primaryTint,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isSel ? AppColors.primary : AppColors.cardBorder,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _decisionPriority = p);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _decisionPriority.description,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Top Recommendation Highlight Card
                  if (rec != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF81C784), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFD54F)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFF57F17)),
                                    const SizedBox(width: 4),
                                    Text(
                                      rec.recommendationBadge ?? 'Top Recommendation',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${rec.compositeScore}/100 Match',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rec.observation.sellerName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${rec.channel.displayName} • ${rec.formattedStandardizedRate}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    rec.formattedTotalLandedCost,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'Landed Outlay',
                                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 6 Multi-Criteria Badges Matrix
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildCriteriaPill(
                                Icons.near_me_outlined,
                                'Distance',
                                rec.distanceKm == 0 ? 'Doorstep' : '${rec.distanceKm.toStringAsFixed(1)} km',
                                const Color(0xFF1976D2),
                              ),
                              _buildCriteriaPill(
                                Icons.local_shipping_outlined,
                                'Delivery Fee',
                                rec.formattedDeliveryFee,
                                const Color(0xFF388E3C),
                              ),
                              _buildCriteriaPill(
                                Icons.verified_outlined,
                                'Quality',
                                '${rec.qualityScore.toStringAsFixed(1)} ★ (${rec.qualityGrade.split(' ').first})',
                                const Color(0xFF7B1FA2),
                              ),
                              _buildCriteriaPill(
                                Icons.timer_outlined,
                                'Transit',
                                rec.transitWindow,
                                const Color(0xFFF57C00),
                              ),
                              _buildCriteriaPill(
                                Icons.support_agent_outlined,
                                'Support',
                                rec.customerSupportPolicy.split(' ').take(3).join(' '),
                                const Color(0xFF00796B),
                              ),
                              _buildCriteriaPill(
                                Icons.shield_outlined,
                                'Reputation',
                                '${rec.reputationScore.toStringAsFixed(1)} ★',
                                const Color(0xFF455A64),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // AI Pros & Cons
                          if (rec.aiPros.isNotEmpty) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: rec.aiPros.take(2).map((pro) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF2E7D32)),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          pro,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Grounded Executive Narrative
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology_outlined, size: 15, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Meta Muse Spark Rationale',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          result.executiveSummary,
                          style: const TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Toggle to view all options side by side
                  InkWell(
                    onTap: () => setState(() => _showExpandedCriteria = !_showExpandedCriteria),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _showExpandedCriteria
                                ? 'Hide Comparison Matrix'
                                : 'Compare All ${result.evaluatedOptions.length} Options by Criteria',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                          Icon(
                            _showExpandedCriteria ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_showExpandedCriteria) ...[
                    const SizedBox(height: 10),
                    for (int i = 0; i < result.evaluatedOptions.length; i++)
                      _buildOptionCard(result.evaluatedOptions[i], i == 0),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriteriaPill(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$title: ',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(EvaluatedSellerOption opt, bool isTop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop ? AppColors.primary : AppColors.cardBorder,
          width: isTop ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildChannelBadge(opt.channel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        opt.observation.sellerName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isTop ? AppColors.primaryTint : AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${opt.compositeScore}% Match',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isTop ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Product Subtotal: ${opt.formattedSubtotal}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text('Delivery Fee: ${opt.formattedDeliveryFee}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    opt.formattedTotalLandedCost,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const Text('Total Landed', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            'Distance: ${opt.distanceKm == 0 ? "Doorstep" : "${opt.distanceKm.toStringAsFixed(1)} km"} • Quality: ${opt.qualityGrade} • Support: ${opt.customerSupportPolicy}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
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

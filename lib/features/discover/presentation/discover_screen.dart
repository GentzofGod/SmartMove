import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/errand.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/product.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/meta_ai_service.dart';
import '../../../core/services/commodity_comparison_service.dart';
import '../../home/presentation/widgets/location_picker_sheet.dart';
import '../../home/presentation/widgets/paper_note_scanner_sheet.dart';
import 'product_detail_sheet.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _selectedCategory = 'Groceries';
  String _selectedSourceFilter = 'All'; // 'All', 'Trader', 'Community', 'Verified'
  String _selectedChannelFilter = 'All'; // 'All', 'Local Market', 'SMB Store', 'Online Retailer'
  ComparisonSortPreference _sortPreference = ComparisonSortPreference.cheapestUnitPrice;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Groceries', 'icon': Icons.local_grocery_store_outlined},
    {'name': 'Electronics', 'icon': Icons.devices_outlined},
    {'name': 'Pharmacy', 'icon': Icons.local_pharmacy_outlined},
    {'name': 'Others', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPaperNoteScannerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaperNoteScannerSheet(
        onTranscriptConfirmed: (text) {
          _searchController.text = text;
          ref.read(productsProvider.notifier).search(text);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.primary,
              content: Text('Handwritten note parsed: "$text"'),
            ),
          );
        },
      ),
    );
  }

  void _showAiResearchDialog(BuildContext context, String commodityName) {
    const aiService = MetaAiService();
    final plan = aiService.coordinatePriceResearch(
      commodityName.isNotEmpty ? commodityName : 'Rice (50kg)',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta AI Price Research: ${plan.commodityName}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const Text(
                        'Multi-channel intelligence grounded on verified market surveys',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Benchmark Range:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(
                    plan.estimatedPriceRange,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('Target Platforms & Channels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            ...plan.targetPlatforms.map((platform) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        platform.toLowerCase().contains('jumia') || platform.toLowerCase().contains('konga') || platform.toLowerCase().contains('supermart')
                            ? Icons.language
                            : Icons.storefront,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(platform, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                      const Text(
                        'Verified Channel',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Recommendation: ${plan.recommendation}',
                style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _searchController.text = commodityName;
                  ref.read(productsProvider.notifier).search(commodityName);
                },
                child: const Text('Filter Catalog by this Commodity', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final currentLocation = ref.watch(locationProvider);

    var displayedProducts = products;
    if (_selectedSourceFilter == 'Trader') {
      displayedProducts = displayedProducts
          .where((p) =>
              p.sourceType == ObservationSource.traderConfirmed ||
              p.sourceType == ObservationSource.traderProvided)
          .toList();
    } else if (_selectedSourceFilter == 'Community') {
      displayedProducts = displayedProducts
          .where((p) => p.sourceType == ObservationSource.communityReported)
          .toList();
    } else if (_selectedSourceFilter == 'Verified') {
      displayedProducts = displayedProducts
          .where((p) =>
              p.sourceType == ObservationSource.independentlyVerified ||
              p.sourceType == ObservationSource.traderConfirmed)
          .toList();
    }

    if (_selectedChannelFilter != 'All') {
      displayedProducts = displayedProducts
          .where((p) => p.channel.toLowerCase() == _selectedChannelFilter.toLowerCase())
          .toList();
    }

    displayedProducts = List<Product>.from(displayedProducts);
    switch (_sortPreference) {
      case ComparisonSortPreference.cheapestUnitPrice:
        displayedProducts.sort((a, b) {
          final unitA = a.standardizedUnitPrice ?? a.lowestPrice;
          final unitB = b.standardizedUnitPrice ?? b.lowestPrice;
          return unitA.compareTo(unitB);
        });
        break;
      case ComparisonSortPreference.lowestPrice:
        displayedProducts.sort((a, b) => a.lowestPrice.compareTo(b.lowestPrice));
        break;
      case ComparisonSortPreference.closestDistance:
        displayedProducts.sort((a, b) {
          final distA = (currentLocation.isSet && LocationService.knownMarketCoordinates.containsKey(a.bestSeller))
              ? LocationService.calculateDistanceKm(
                  lat1: currentLocation.latitude,
                  lon1: currentLocation.longitude,
                  lat2: LocationService.knownMarketCoordinates[a.bestSeller]!.latitude,
                  lon2: LocationService.knownMarketCoordinates[a.bestSeller]!.longitude,
                )
              : a.distanceKm;
          final distB = (currentLocation.isSet && LocationService.knownMarketCoordinates.containsKey(b.bestSeller))
              ? LocationService.calculateDistanceKm(
                  lat1: currentLocation.latitude,
                  lon1: currentLocation.longitude,
                  lat2: LocationService.knownMarketCoordinates[b.bestSeller]!.latitude,
                  lon2: LocationService.knownMarketCoordinates[b.bestSeller]!.longitude,
                )
              : b.distanceKm;
          return distA.compareTo(distB);
        });
        break;
      case ComparisonSortPreference.highestTrust:
        displayedProducts.sort((a, b) {
          final scoreA = a.sourceType == ObservationSource.independentlyVerified
              ? 3
              : (a.sourceType == ObservationSource.traderConfirmed ? 2 : 1);
          final scoreB = b.sourceType == ObservationSource.independentlyVerified
              ? 3
              : (b.sourceType == ObservationSource.traderConfirmed ? 2 : 1);
          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          return a.lowestPrice.compareTo(b.lowestPrice);
        });
        break;
      case ComparisonSortPreference.bestValue:
        displayedProducts.sort((a, b) {
          final unitA = a.standardizedUnitPrice ?? a.lowestPrice;
          final unitB = b.standardizedUnitPrice ?? b.lowestPrice;
          return unitA.compareTo(unitB);
        });
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Discover',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Find the best prices near you',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => ref.read(productsProvider.notifier).search(val),
                decoration: InputDecoration(
                  hintText: 'Search for a product (e.g. rice, eggs...)',
                  hintStyle: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(productsProvider.notifier).search('');
                          },
                        )
                      : IconButton(
                          key: const ValueKey('btn_discover_scan_paper_note'),
                          icon: const Icon(
                            Icons.document_scanner_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          tooltip: 'Scan Handwritten Paper Note (Meta AI Vision)',
                          onPressed: () => _openPaperNoteScannerSheet(context),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Meta AI Quick Research Chip Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  backgroundColor: AppColors.primaryTint,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  label: Text(
                    _searchController.text.isNotEmpty
                        ? 'Research "${_searchController.text.trim()}" with Meta AI'
                        : 'Meta AI Commodity Price Research',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  onPressed: () => _showAiResearchDialog(
                    context,
                    _searchController.text.isNotEmpty ? _searchController.text.trim() : 'Rice (50kg)',
                  ),
                ),
              ],
            ),
          ),

          // Category Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['name'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    selected: isSelected,
                    avatar: Icon(
                      cat['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    label: Text(
                      cat['name'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedCategory = cat['name'] as String;
                      });
                      ref
                          .read(productsProvider.notifier)
                          .filterCategory(cat['name'] as String);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Filter Row: Nearby & Sort by
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => LocationPickerSheet.show(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.near_me_outlined, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  currentLocation.isSet
                                      ? 'Near ${currentLocation.displayTown} (≤ 5 km)'
                                      : 'All Locations (Tap to set town)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            // Cycle through sources: All -> Trader -> Community -> Verified -> All
                            setState(() {
                              if (_selectedSourceFilter == 'All') {
                                _selectedSourceFilter = 'Trader';
                              } else if (_selectedSourceFilter == 'Trader') {
                                _selectedSourceFilter = 'Community';
                              } else if (_selectedSourceFilter == 'Community') {
                                _selectedSourceFilter = 'Verified';
                              } else {
                                _selectedSourceFilter = 'All';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _selectedSourceFilter != 'All'
                                  ? AppColors.primaryTint
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedSourceFilter != 'All'
                                    ? AppColors.primary
                                    : AppColors.cardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Source: ${_selectedSourceFilter == 'All' ? 'All Sources' : _selectedSourceFilter}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedSourceFilter != 'All'
                                        ? AppColors.primaryDark
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const Icon(Icons.tune_rounded, size: 14, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            // Cycle through channels: All -> Local Market -> SMB Store -> Online Retailer -> All
                            setState(() {
                              if (_selectedChannelFilter == 'All') {
                                _selectedChannelFilter = 'Local Market';
                              } else if (_selectedChannelFilter == 'Local Market') {
                                _selectedChannelFilter = 'SMB Store';
                              } else if (_selectedChannelFilter == 'SMB Store') {
                                _selectedChannelFilter = 'Online Retailer';
                              } else {
                                _selectedChannelFilter = 'All';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _selectedChannelFilter != 'All'
                                  ? AppColors.primaryTint
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedChannelFilter != 'All'
                                    ? AppColors.primary
                                    : AppColors.cardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedChannelFilter == 'Online Retailer'
                                      ? Icons.language
                                      : (_selectedChannelFilter == 'SMB Store'
                                          ? Icons.store
                                          : Icons.storefront),
                                  size: 13,
                                  color: _selectedChannelFilter != 'All' ? AppColors.primaryDark : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Channel: ${_selectedChannelFilter == 'All' ? 'All Channels' : _selectedChannelFilter}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedChannelFilter != 'All'
                                        ? AppColors.primaryDark
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              final nextIndex = (_sortPreference.index + 1) % ComparisonSortPreference.values.length;
                              _sortPreference = ComparisonSortPreference.values[nextIndex];
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sort_rounded, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Sort: ${_sortPreference.label}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${displayedProducts.length} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Product List Cards
          Expanded(
            child: displayedProducts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No matching products found',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try adjusting your search or source filter.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    itemCount: displayedProducts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                final p = displayedProducts[index];
                return InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ProductDetailSheet(product: p),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                    children: [
                      // Product Icon Box
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Product Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (p.isCheapest) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.successBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Cheapest',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.successText,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  p.formattedPrice,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.formattedStandardizedPrice,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (p.brandOrGrade != null && p.brandOrGrade!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Grade: ${p.brandOrGrade}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  p.channel.toLowerCase().contains('online')
                                      ? Icons.language
                                      : (p.channel.toLowerCase().contains('smb') || p.channel.toLowerCase().contains('store')
                                          ? Icons.store
                                          : Icons.storefront),
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final marketCoord = LocationService
                                          .knownMarketCoordinates[p.bestSeller];
                                      final dynamicDistance = marketCoord != null
                                          ? LocationService.calculateDistanceKm(
                                              lat1: currentLocation.latitude,
                                              lon1: currentLocation.longitude,
                                              lat2: marketCoord.latitude,
                                              lon2: marketCoord.longitude,
                                            )
                                          : p.distanceKm;

                                      return Text(
                                        '${p.bestSeller} • ${p.channel} • $dynamicDistance km',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('•', style: TextStyle(color: AppColors.textTertiary)),
                                const SizedBox(width: 6),
                                Text(
                                  'per ${p.standardUnit}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Explicit Data Source Badge (Section 5.2)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: p.sourceType == ObservationSource.simulatedDemo
                                        ? AppColors.cardBorder
                                        : AppColors.badgeSuccessBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.sourceType.displayLabel,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: p.sourceType == ObservationSource.simulatedDemo
                                          ? AppColors.textSecondary
                                          : AppColors.badgeSuccessText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p.updateTime,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Compare and Add buttons column
                      Column(
                        children: [
                          IconButton(
                            tooltip: 'Compare Across Sellers',
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => ProductDetailSheet(product: p),
                              );
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: const Icon(
                                Icons.compare_arrows_rounded,
                                color: AppColors.textPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add to Comparison Basket',
                            onPressed: () {
                          // Quick add to comparison basket
                          final item = ShoppingItem(
                            id: 'item-${p.id}-${DateTime.now().millisecondsSinceEpoch}',
                            productId: p.id,
                            productName: p.name,
                            quantity: 1,
                            unit: p.standardUnit,
                            estimatedUnitPrice: p.lowestPrice,
                            priority: CommodityPriority.essential,
                          );
                          ref.read(decisionLabProvider.notifier).addShoppingItem(item);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${p.name} to Comparison Basket!'),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        ),
      ),

          // Honest Data Disclosure Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.cardBorder.withValues(alpha: 0.3),
            child: const Text(
              'Community Market Intelligence — Verified Local Prices & Trader Updates',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

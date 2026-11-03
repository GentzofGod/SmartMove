import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/product.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/seller_application.dart';
import '../../../core/services/meta_ai_service.dart';
import '../../../core/services/commodity_comparison_service.dart';
import '../../../core/services/safe_outlet_launcher.dart';
import '../../../core/presentation/widgets/commodity_image_widget.dart';
import '../../../core/presentation/widgets/seller_location_map_sheet.dart';
import '../../../core/presentation/widgets/community_assistance_sheet.dart';
import '../../discover/presentation/product_detail_sheet.dart';
import '../../home/presentation/widgets/paper_note_scanner_sheet.dart';

/// Unified model representing a single deduplicated commodity across all registered sellers & community reports.
class UnifiedProductItem {
  final String id;
  final String name;
  final String category;
  final String? imageUrl;
  final String baseUnit;
  final double lowestPrice;
  final double highestPrice;
  final double averagePrice;
  final List<PriceObservation> verifiedSellerObservations;
  final List<PriceObservation> communityObservations;
  final String bestSellerLocation;
  final double distanceKm;
  final bool inStock;
  final Product? originalProduct;

  const UnifiedProductItem({
    required this.id,
    required this.name,
    required this.category,
    this.imageUrl,
    required this.baseUnit,
    required this.lowestPrice,
    required this.highestPrice,
    required this.averagePrice,
    required this.verifiedSellerObservations,
    required this.communityObservations,
    required this.bestSellerLocation,
    required this.distanceKm,
    required this.inStock,
    this.originalProduct,
  });

  bool get hasVerifiedSellers => verifiedSellerObservations.isNotEmpty;
  bool get hasCommunityQuotes => communityObservations.isNotEmpty;
  int get totalStallQuotes =>
      verifiedSellerObservations.length + communityObservations.length;

  Product toProduct() {
    if (originalProduct != null) return originalProduct!;
    return Product(
      id: id,
      name: name,
      category: category,
      lowestPrice: lowestPrice,
      standardUnit: baseUnit,
      bestSeller: bestSellerLocation,
      channel: hasVerifiedSellers ? 'Local Market' : 'Community',
      sourceType: hasVerifiedSellers
          ? ObservationSource.traderConfirmed
          : ObservationSource.communityReported,
      distanceKm: distanceKm,
      updateTime: 'Recently',
      imageUrl: imageUrl,
    );
  }
}

/// Unified Products Screen combining catalog discovery and verified community price feeds without duplicates.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _selectedCategory = 'All';
  String _selectedSourceFilter = 'All'; // 'All', 'Verified Sellers', 'Community Quotes'
  ComparisonSortPreference _sortPreference = ComparisonSortPreference.lowestPrice;
  final TextEditingController _searchController = TextEditingController();

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
          setState(() {});
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

  void _promptForCommodityResearch(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Meta AI Price Research',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a commodity or product to research current prices across open markets, neighborhood stores, and online platforms.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Electric Cooker 2-Burner, Lathe Chuck',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (val) {
                  Navigator.pop(dialogCtx);
                  if (val.trim().isNotEmpty) {
                    _executeResearch(context, val.trim());
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Research Price'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final query = textController.text.trim();
                Navigator.pop(dialogCtx);
                if (query.isNotEmpty) {
                  _executeResearch(context, query);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeResearch(BuildContext context, String query) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Researching live market prices for "$query"...',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    const aiService = MetaAiService();
    final loc = ref.read(locationProvider);
    final userCity = loc.city.isNotEmpty ? loc.city : (loc.town.isNotEmpty ? loc.town : null);
    final inAppObs = ref.read(communityProvider);

    final plan = await aiService.queryAiPriceResearch(
      query,
      city: userCity,
      inAppObservations: inAppObs,
    );

    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();

    if (plan == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No response from Meta AI for "$query". Live AI research is unavailable.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final comparison = LiveAiMultiVendorComparison(
      commodityName: plan.commodityName,
      summary: plan.aiComparisonInsight ??
          'Discovered ${plan.liveVendors.length} live vendor alternatives across web and local outlets.',
      lowestPrice: plan.estimatedBenchmarkMin,
      highestPrice: plan.estimatedBenchmarkMax,
      priceSpreadDisplay: plan.estimatedPriceRange,
      aiRecommendation: plan.customRecommendation ?? plan.recommendation,
      vendors: plan.liveVendors,
    );

    await SafeOutletLauncher.showMultiVendorComparisonSheet(context, comparison: comparison);
  }

  void _showAddObservationDialog(BuildContext context) {
    final userSession = ref.read(authProvider);
    final applications = ref.read(sellerApplicationsProvider);

    if (userSession.isGuest) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sign In Required'),
          content: const Text(
            'Guest users can explore market prices. To publish price observations, please sign in or create an account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                context.push('/auth');
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
      return;
    }

    // Verified sellers manage inventory in Seller Portal
    final isVerifiedSeller = userSession.isApprovedSeller ||
        userSession.role == 'Trader' ||
        applications.any((a) =>
            (!userSession.isGuest &&
                userSession.email.isNotEmpty &&
                a.applicantEmail.trim().toLowerCase() ==
                    userSession.email.trim().toLowerCase() &&
                a.status == SellerApplicationStatus.approved));

    if (isVerifiedSeller) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.storefront_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verified Seller Portal Notice',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: const Text(
            'Verified sellers manage official inventory, pricing, stock levels, and stall coordinates directly in the Seller Portal.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.storefront_rounded, size: 16),
              label: const Text('Go to Seller Portal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                context.push('/seller-portal');
              },
            ),
          ],
        ),
      );
      return;
    }

    final posterNameController = TextEditingController(
      text: userSession.displayName.isNotEmpty ? userSession.displayName : '',
    );
    final productController = TextEditingController();
    final sellerController = TextEditingController();
    final priceController = TextEditingController();
    final unitController = TextEditingController(text: '1kg');
    final contactController = TextEditingController(
      text: userSession.phone ?? '',
    );
    final brandController = TextEditingController();
    final notesController = TextEditingController();
    String channel = 'Local Market';
    String category = 'Food';
    String selectedUnitOption = '1kg';
    bool isCustomUnit = false;
    bool inStock = true;

    final availableCategories = ref.read(categoriesProvider).map((c) => c.name).toList();
    if (availableCategories.isEmpty) {
      availableCategories.addAll([
        'Food',
        'Electronics',
        'Pharmacy',
        'Fashion & Clothing',
        'Beauty & Personal Care',
        'Home & Kitchen',
        'Hardware & Tools',
        'Baby & Kids',
        'Books & Stationery',
        'Agro & Farm Produce',
        'Auto Spares',
        'Others',
      ]);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Report Market Price Observation',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Help your community by recording real prices seen in local stalls or markets.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: productController,
                      decoration: InputDecoration(
                        labelText: 'Commodity / Product Name *',
                        hintText: 'e.g. White Garri, Parboiled Rice',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Price (₦) *',
                              prefixText: '₦ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedUnitOption,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Unit / Measure *',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: [
                              '1kg',
                              '50kg bag',
                              '25kg bag',
                              '10kg bag',
                              '5kg bag',
                              'paint rubber / 4kg',
                              'congo / 1.5kg',
                              'derica',
                              '1L bottle',
                              '2L bottle',
                              '5L gallon',
                              '25L jerrycan',
                              'crate of 30',
                              'tuber',
                              'heap',
                              'piece / unit',
                              'pair',
                              'pack / packet',
                              'carton',
                              'roll',
                              'bundle',
                              'set',
                              'sachet',
                              'can / tin',
                              'yard',
                              'meter',
                              'Custom unit...',
                            ].map((u) {
                              return DropdownMenuItem(
                                value: u,
                                child: Text(u, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedUnitOption = val;
                                  if (val == 'Custom unit...') {
                                    isCustomUnit = true;
                                    if (unitController.text.trim() == '1kg') {
                                      unitController.clear();
                                    }
                                  } else {
                                    isCustomUnit = false;
                                    unitController.text = val;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (isCustomUnit) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: unitController,
                        decoration: InputDecoration(
                          labelText: 'Enter Custom Unit *',
                          hintText: 'e.g. 75cl bottle, paint bucket, pack of 6',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    TextField(
                      controller: sellerController,
                      decoration: InputDecoration(
                        labelText: 'Market Area or Stall Landmark (Optional)',
                        hintText: 'e.g. Bodija Market open section, Dugbe, or leave blank',
                        helperText: 'Optional: Anonymous open-air vendor price sightings welcome',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Submitter contact (optional)
                    TextField(
                      controller: contactController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Your Phone or WhatsApp (Optional)',
                        hintText: 'e.g. +2348012345678 (to help shoppers find stall)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category Selector
                    const Text(
                      'Category:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: availableCategories.map((cat) {
                          final isSel = category == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSel,
                              selectedColor: AppColors.primaryTint,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? AppColors.primary : AppColors.textSecondary,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => category = cat);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Stall Notes & Landmark Directions (Optional)',
                        hintText: 'e.g. Second lane behind agro depot, brown wooden table',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Currently In Stock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      value: inStock,
                      onChanged: (val) => setModalState(() => inStock = val),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final price = double.tryParse(priceController.text.trim());
                          final unit = unitController.text.trim().isNotEmpty
                              ? unitController.text.trim()
                              : selectedUnitOption;
                          if (productController.text.trim().isNotEmpty && price != null) {
                            final posterName = posterNameController.text.trim().isNotEmpty
                                ? posterNameController.text.trim()
                                : (userSession.displayName.trim().isNotEmpty
                                    ? userSession.displayName.trim()
                                    : 'Community Shopper');

                            final sName = sellerController.text.trim().isNotEmpty
                                ? sellerController.text.trim()
                                : 'Open Market Vendor';

                            ref.read(communityProvider.notifier).addObservation(
                                  productName: productController.text.trim(),
                                  sellerName: sName,
                                  price: price,
                                  unit: unit,
                                  submitterName: posterName,
                                  submitterRole: 'Customer',
                                  channel: channel,
                                  category: category,
                                  brandOrGrade: brandController.text.trim().isNotEmpty
                                      ? brandController.text.trim()
                                      : null,
                                  inStock: inStock,
                                  notes: notesController.text.trim().isNotEmpty
                                      ? notesController.text.trim()
                                      : null,
                                  submitterContact: contactController.text.trim().isNotEmpty
                                      ? contactController.text.trim()
                                      : null,
                                );
                            Navigator.pop(bottomCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Price observation submitted successfully!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        },
                        child: const Text('Submit Observation', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        );
      },
    );
  }

  /// Builds a unified, deduplicated list of products merging productsProvider and communityProvider
  List<UnifiedProductItem> _buildUnifiedCatalog({
    required List<Product> products,
    required List<PriceObservation> observations,
    required dynamic currentLocation,
  }) {
    final Map<String, _UnifiedProductBuilder> map = {};

    // 1. Ingest base products
    for (final p in products) {
      final key = p.name.trim().toLowerCase();
      map[key] = _UnifiedProductBuilder(
        id: p.id,
        name: p.name,
        category: p.category,
        imageUrl: p.imageUrl,
        baseUnit: p.standardUnit,
        lowestPrice: p.lowestPrice,
        highestPrice: p.lowestPrice,
        bestSellerLocation: p.bestSeller,
        distanceKm: p.distanceKm,
        inStock: true,
        originalProduct: p,
      );
    }

    // 2. Associate and unify observations
    for (final obs in observations) {
      final key = obs.productName.trim().toLowerCase();
      final isVerified = obs.isVerified ||
          obs.sourceType == ObservationSource.traderConfirmed ||
          obs.sourceType == ObservationSource.traderProvided ||
          obs.sourceType == ObservationSource.independentlyVerified ||
          obs.submitterRole == 'Trader' ||
          obs.submitterRole == 'Seller';

      final existing = map[key];
      if (existing != null) {
        if (isVerified) {
          existing.verifiedObs.add(obs);
        } else {
          existing.communityObs.add(obs);
        }
        if (obs.price > 0) {
          if (obs.price < existing.lowestPrice || existing.lowestPrice <= 0) {
            existing.lowestPrice = obs.price;
          }
          if (obs.price > existing.highestPrice) {
            existing.highestPrice = obs.price;
          }
        }
        if (obs.inStock) {
          existing.inStock = true;
        }
      } else {
        // Create an uncataloged unified item from observation
        final builder = _UnifiedProductBuilder(
          id: obs.productId.isNotEmpty ? obs.productId : 'prod-unified-${obs.id}',
          name: obs.productName,
          category: obs.category.isNotEmpty ? obs.category : 'Food',
          imageUrl: obs.imageUrl,
          baseUnit: obs.unit,
          lowestPrice: obs.price,
          highestPrice: obs.price,
          bestSellerLocation: obs.marketLocation,
          distanceKm: 1.5,
          inStock: obs.inStock,
          originalProduct: null,
        );
        if (isVerified) {
          builder.verifiedObs.add(obs);
        } else {
          builder.communityObs.add(obs);
        }
        map[key] = builder;
      }
    }

    return map.values.map((b) => b.build()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final observations = ref.watch(communityProvider);
    final applications = ref.watch(sellerApplicationsProvider);
    final rawUserSession = ref.watch(authProvider);
    final currentLocation = ref.watch(locationProvider);

    final matchingApp = applications.cast<SellerApplication?>().firstWhere(
          (a) =>
              a != null &&
              (a.userId == rawUserSession.id ||
                  (!rawUserSession.isGuest &&
                      rawUserSession.email.isNotEmpty &&
                      a.applicantEmail.trim().toLowerCase() ==
                          rawUserSession.email.trim().toLowerCase())),
          orElse: () => null,
        );

    final userSession = (matchingApp != null &&
            matchingApp.status == SellerApplicationStatus.approved &&
            !rawUserSession.isApprovedSeller)
        ? rawUserSession.copyWith(
            role: 'Trader',
            sellerApplicationStatus: SellerApplicationStatus.approved,
            businessName: rawUserSession.businessName ?? matchingApp.businessName,
          )
        : rawUserSession;

    final pendingAppsCount = applications
        .where((a) => a.status == SellerApplicationStatus.pending)
        .length;

    // Build deduplicated unified catalog
    final allUnified = _buildUnifiedCatalog(
      products: products,
      observations: observations,
      currentLocation: currentLocation,
    );

    // Apply Category Filter
    var filtered = allUnified;
    if (_selectedCategory != 'All') {
      final sCat = _selectedCategory.toLowerCase();
      filtered = filtered.where((p) {
        final pCat = p.category.toLowerCase();
        if (sCat == 'food' || sCat == 'groceries') {
          return pCat == 'food' ||
              pCat == 'groceries' ||
              pCat.contains('grain') ||
              pCat.contains('tuber') ||
              pCat.contains('oil');
        }
        return pCat == sCat;
      }).toList();
    }

    // Apply Source Filter
    if (_selectedSourceFilter == 'Verified Sellers') {
      filtered = filtered.where((p) => p.hasVerifiedSellers).toList();
    } else if (_selectedSourceFilter == 'Community Quotes') {
      filtered = filtered.where((p) => p.hasCommunityQuotes).toList();
    }

    // Apply Search Query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }

    // Apply Sorting
    filtered = List<UnifiedProductItem>.from(filtered);
    switch (_sortPreference) {
      case ComparisonSortPreference.lowestPrice:
      case ComparisonSortPreference.cheapestUnitPrice:
        filtered.sort((a, b) => a.lowestPrice.compareTo(b.lowestPrice));
        break;
      case ComparisonSortPreference.closestDistance:
        filtered.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case ComparisonSortPreference.highestTrust:
        filtered.sort((a, b) {
          if (a.hasVerifiedSellers && !b.hasVerifiedSellers) return -1;
          if (!a.hasVerifiedSellers && b.hasVerifiedSellers) return 1;
          return a.lowestPrice.compareTo(b.lowestPrice);
        });
        break;
      case ComparisonSortPreference.bestValue:
        filtered.sort((a, b) => a.lowestPrice.compareTo(b.lowestPrice));
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Products',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Verified local stall prices & community quotes',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (userSession.canModerate)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                key: const ValueKey('btn_open_superadmin_panel'),
                avatar: const Icon(Icons.shield_rounded, size: 15, color: Colors.white),
                label: Text(
                  pendingAppsCount > 0
                      ? 'SuperAdmin ($pendingAppsCount)'
                      : 'SuperAdmin Panel',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                backgroundColor: const Color(0xFF673AB7),
                onPressed: () => context.push('/superadmin'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar with Paper Note Scanner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search commodities & live prices...',
                  hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : IconButton(
                          key: const ValueKey('btn_discover_scan_paper_note'),
                          icon: const Icon(Icons.document_scanner_rounded, size: 20, color: AppColors.primary),
                          tooltip: 'Scan Handwritten Shopping Note',
                          onPressed: () => _openPaperNoteScannerSheet(context),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // 2. Meta AI Commodity Price Research Action Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: InkWell(
              onTap: () => _promptForCommodityResearch(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      const Color(0xFF57D9A3).withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Meta AI Commodity Price Research',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),

          // 3. Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: ['All', 'Food', 'Electronics', 'Pharmacy', 'Others'].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.cardBorder,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 4. Source Filter & Sort Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: [
                // Source Filter Segment
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Verified Sellers', 'Community Quotes'].map((source) {
                        final isSel = _selectedSourceFilter == source;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: FilterChip(
                            label: Text(
                              source,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: AppColors.primaryTint,
                            backgroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSel ? AppColors.primary : AppColors.cardBorder,
                              ),
                            ),
                            onSelected: (val) {
                              setState(() => _selectedSourceFilter = val ? source : 'All');
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Sort Dropdown
                PopupMenuButton<ComparisonSortPreference>(
                  initialValue: _sortPreference,
                  icon: const Icon(Icons.sort_rounded, size: 20, color: AppColors.textSecondary),
                  tooltip: 'Sort Products',
                  onSelected: (pref) => setState(() => _sortPreference = pref),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: ComparisonSortPreference.lowestPrice,
                      child: Text('Lowest Price', style: TextStyle(fontSize: 12.5)),
                    ),
                    const PopupMenuItem(
                      value: ComparisonSortPreference.cheapestUnitPrice,
                      child: Text('Cheapest Unit Price', style: TextStyle(fontSize: 12.5)),
                    ),
                    const PopupMenuItem(
                      value: ComparisonSortPreference.closestDistance,
                      child: Text('Closest Stall', style: TextStyle(fontSize: 12.5)),
                    ),
                    const PopupMenuItem(
                      value: ComparisonSortPreference.highestTrust,
                      child: Text('Highest Trust (Verified First)', style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5. Unified Deduplicated Product Cards
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'No products found matching filters',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap + below to report a market price quote.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildUnifiedProductCard(context, item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('btn_add_product_observation'),
        onPressed: () => _showAddObservationDialog(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Report Price',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildUnifiedProductCard(BuildContext context, UnifiedProductItem item) {
    final priceDisplay = item.lowestPrice == item.highestPrice
        ? '₦${item.lowestPrice.toStringAsFixed(0)} / ${item.baseUnit}'
        : '₦${item.lowestPrice.toStringAsFixed(0)} – ₦${item.highestPrice.toStringAsFixed(0)} / ${item.baseUnit}';

    // Best verified observation with coordinates for map navigation
    final mapObs = item.verifiedSellerObservations.firstWhere(
      (o) => o.latitude != null && o.longitude != null,
      orElse: () => item.verifiedSellerObservations.isNotEmpty
          ? item.verifiedSellerObservations.first
          : (item.communityObservations.isNotEmpty
              ? item.communityObservations.first
              : PriceObservation(
                  id: item.id,
                  productId: item.id,
                  productName: item.name,
                  sellerName: item.bestSellerLocation,
                  marketLocation: item.bestSellerLocation,
                  price: item.lowestPrice,
                  unit: item.baseUnit,
                  timestamp: DateTime.now(),
                  sourceType: ObservationSource.traderConfirmed,
                  submitterName: 'Verified Seller',
                  submitterRole: 'Trader',
                  channel: 'Local Market',
                  category: item.category,
                )),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => ProductDetailSheet(product: item.toProduct()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CommodityImageWidget(
                        commodityName: item.name,
                        imageUrl: item.imageUrl,
                        size: 72,
                        borderRadius: 12,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: Text(
                                  item.category,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Price spread
                          Text(
                            priceDisplay,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Location & Stalls Info
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${item.bestSellerLocation} • ${item.distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 8),

                // Footer Badges & Actions
                Row(
                  children: [
                    Expanded(
                      child: item.hasVerifiedSellers
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${item.verifiedSellerObservations.length} Verified Stall(s)',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              item.hasCommunityQuotes
                                  ? '${item.communityObservations.length} Community Quote(s)'
                                  : 'Catalog Price',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const SizedBox(width: 6),

                    // Locate on Map Action or Community Help Action
                    if (item.hasVerifiedSellers) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.location_on_outlined, size: 12, color: AppColors.primary),
                        label: const Text('Map', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          SellerLocationMapSheet.show(
                            context,
                            sellerName: mapObs.sellerName,
                            marketLocation: mapObs.marketLocation,
                            observation: mapObs,
                            productName: mapObs.productName,
                            price: mapObs.price,
                            unit: mapObs.unit,
                            sellerLat: mapObs.latitude,
                            sellerLng: mapObs.longitude,
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                    ] else if (item.hasCommunityQuotes) ...[
                      OutlinedButton.icon(
                        key: const ValueKey('btn_unified_get_help'),
                        icon: const Icon(Icons.help_outline_rounded, size: 12, color: Color(0xFFE65100)),
                        label: const Text('Help', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          side: const BorderSide(color: Color(0xFFFFB74D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          CommunityAssistanceSheet.show(context, observation: mapObs);
                        },
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Compare & Buy Action
                    ElevatedButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 12),
                      label: const Text('Compare', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => ProductDetailSheet(product: item.toProduct()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnifiedProductBuilder {
  final String id;
  final String name;
  final String category;
  final String? imageUrl;
  final String baseUnit;
  double lowestPrice;
  double highestPrice;
  String bestSellerLocation;
  double distanceKm;
  bool inStock;
  final Product? originalProduct;
  final List<PriceObservation> verifiedObs = [];
  final List<PriceObservation> communityObs = [];

  _UnifiedProductBuilder({
    required this.id,
    required this.name,
    required this.category,
    this.imageUrl,
    required this.baseUnit,
    required this.lowestPrice,
    required this.highestPrice,
    required this.bestSellerLocation,
    required this.distanceKm,
    required this.inStock,
    this.originalProduct,
  });

  UnifiedProductItem build() {
    return UnifiedProductItem(
      id: id,
      name: name,
      category: category,
      imageUrl: imageUrl,
      baseUnit: baseUnit,
      lowestPrice: lowestPrice,
      highestPrice: highestPrice,
      averagePrice: (lowestPrice + highestPrice) / 2,
      verifiedSellerObservations: verifiedObs,
      communityObservations: communityObs,
      bestSellerLocation: bestSellerLocation,
      distanceKm: distanceKm,
      inStock: inStock,
      originalProduct: originalProduct,
    );
  }
}

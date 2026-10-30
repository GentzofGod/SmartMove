import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/product.dart';
import '../../../core/models/seller_application.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/meta_ai_service.dart';
import '../../../core/services/commodity_comparison_service.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedChannelFilter = 'All';
  String _selectedSourceFilter = 'All';
  String _moderationFilter = 'All';

  static const List<String> _commodityPresets = [
    'Parboiled Rice',
    'Brown Beans',
    'White Garri',
    'Palm Oil',
    'Benue Yam',
    'Groundnut Oil',
    'Tomatoes',
    'Onions',
  ];

  static const List<String> _commonUnits = [
    '1kg',
    '5kg',
    '25kg',
    '50kg bag',
    '75cl bottle',
    '25L jerrycan',
    'paint rubber',
    'tuber',
    'crate',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddObservationDialog(BuildContext context, {bool isSellerDirect = false}) {
    final userSession = ref.read(authProvider);
    final productController = TextEditingController();
    final sellerController = TextEditingController(
      text: isSellerDirect && userSession.businessName != null ? userSession.businessName! : '',
    );
    final priceController = TextEditingController();
    final unitController = TextEditingController(text: '1kg');
    final brandController = TextEditingController();
    final notesController = TextEditingController();
    String submitterRole = isSellerDirect ? 'Trader' : userSession.role;
    String channel = isSellerDirect && userSession.sellerChannel != null
        ? userSession.sellerChannel!
        : 'Local Market';
    bool inStock = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final parsedPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
            final mult = CommodityComparisonService.calculateUnitMultiplier(
              unitController.text.trim(),
              commodityName: productController.text.trim(),
            );
            final previewStandardized = mult > 0 ? (parsedPrice / mult) : parsedPrice;
            final baseUnit = CommodityComparisonService.resolveBaseUnit(
              unitController.text.trim(),
              commodityName: productController.text.trim(),
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isSellerDirect ? 'Submit Seller Price Listing' : 'Report Price Observation',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick commodity presets
                    const Text(
                      'Quick Commodity Presets:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _commodityPresets.map((preset) {
                          final isSelected = productController.text == preset;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(preset),
                              selected: isSelected,
                              selectedColor: AppColors.primaryTint,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setModalState(() {
                                    productController.text = preset;
                                    if (preset.contains('Rice') || preset.contains('Beans')) {
                                      unitController.text = '50kg bag';
                                    } else if (preset.contains('Oil')) {
                                      unitController.text = '25L jerrycan';
                                    } else if (preset.contains('Garri')) {
                                      unitController.text = 'paint rubber';
                                    }
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: productController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Commodity Name',
                        hintText: 'e.g. Parboiled Rice, Brown Beans, Palm Oil',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: brandController,
                      decoration: InputDecoration(
                        labelText: 'Brand or Quality Grade (Optional)',
                        hintText: 'e.g. Mama Gold Grade A, Royal Stallion, Oloyin',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sellerController,
                      decoration: InputDecoration(
                        labelText: isSellerDirect ? 'Business / Stall Name' : 'Market / Store Name',
                        hintText: 'e.g. Bodija Market Stall 14, Jumia, Dugbe Mart',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Unit Presets
                    const Text(
                      'Common Package Units:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _commonUnits.map((u) {
                        final isSel = unitController.text == u;
                        return ChoiceChip(
                          label: Text(u),
                          selected: isSel,
                          selectedColor: AppColors.primaryTint,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSel ? AppColors.primary : AppColors.textSecondary,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => unitController.text = u);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Price (₦)',
                              prefixText: '₦ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: unitController,
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Package Unit',
                              hintText: '1kg, 50kg bag',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (parsedPrice > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calculate_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Standardized Unit Price: ₦${previewStandardized.toStringAsFixed(0)} / $baseUnit',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Channel Selection
                    const Text(
                      'Seller Channel Type:',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Local Market'),
                          selected: channel == 'Local Market',
                          onSelected: (val) {
                            if (val) setModalState(() => channel = 'Local Market');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('SMB Merchant'),
                          selected: channel == 'SMB Store',
                          onSelected: (val) {
                            if (val) setModalState(() => channel = 'SMB Store');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Online Retailer'),
                          selected: channel == 'Online Retailer',
                          onSelected: (val) {
                            if (val) setModalState(() => channel = 'Online Retailer');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Stall / Location Notes (Optional)',
                        hintText: 'e.g. Section B Stall 14, wholesale discount for 3+ bags',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // In Stock Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Currently In Stock',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      value: inStock,
                      onChanged: (val) => setModalState(() => inStock = val),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final price = double.tryParse(priceController.text.trim());
                          if (productController.text.trim().isNotEmpty && price != null) {
                            ref.read(communityProvider.notifier).addObservation(
                                  productName: productController.text.trim(),
                                  sellerName: sellerController.text.trim().isNotEmpty
                                      ? sellerController.text.trim()
                                      : (isSellerDirect && userSession.businessName != null
                                          ? userSession.businessName!
                                          : 'Local Market'),
                                  price: price,
                                  unit: unitController.text.trim(),
                                  submitterName: isSellerDirect ? 'You (Verified Seller)' : userSession.displayName,
                                  submitterRole: submitterRole,
                                  channel: channel,
                                  brandOrGrade: brandController.text.trim().isNotEmpty
                                      ? brandController.text.trim()
                                      : null,
                                  inStock: inStock,
                                  notes: notesController.text.trim().isNotEmpty
                                      ? notesController.text.trim()
                                      : null,
                                );
                            Navigator.pop(bottomCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isSellerDirect
                                    ? 'Commodity listing published to SmartMove!'
                                    : 'Price observation submitted to community!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        },
                        child: Text(isSellerDirect ? 'Publish Listing' : 'Submit Observation'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDuplicateScanDialog(BuildContext context, List<PriceObservation> observations) {
    const aiService = MetaAiService();
    final products = ref.read(productsProvider);

    final allMatches = <Map<String, dynamic>>[];
    for (final prod in products) {
      final matches = aiService.detectDuplicateListings(product: prod, candidates: observations);
      for (final m in matches) {
        if (m.isProbableDuplicate) {
          allMatches.add({
            'product': prod,
            'match': m,
          });
        }
      }
    }

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
                      const Text(
                        'Meta AI Duplicate Detection Audit',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        'Detected ${allMatches.length} cross-seller matching commodity listings',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
            if (allMatches.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.badgeSuccessText, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No conflicting duplicate listings found across current seller reports.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...allMatches.take(5).map((item) {
                final prod = item['product'] as Product;
                final m = item['match'] as DuplicateMatchResult;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${prod.name} ↔ ${m.observation.productName}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(m.similarityScore * 100).toInt()}% Match',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${m.reason}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Seller: ${m.observation.sellerName} (${m.observation.channel}) • ${m.observation.formattedPrice}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Audit', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _moderationSubTab = 'Observations'; // 'Observations' or 'Applications'

  @override
  Widget build(BuildContext context) {
    final observations = ref.watch(communityProvider);
    final applications = ref.watch(sellerApplicationsProvider);
    final userSession = ref.watch(authProvider);

    final pendingAppsCount = applications
        .where((a) => a.status == SellerApplicationStatus.pending)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Community & Sellers',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Verified commodity prices across online & local markets.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            const Tab(text: 'Price Feed'),
            const Tab(text: 'Seller Portal'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Moderation'),
                  if (pendingAppsCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingAppsCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Filterable Price Feed
          _buildPriceFeedTab(observations),

          // Tab 2: Seller Portal
          _buildSellerPortalTab(observations, userSession),

          // Tab 3: Moderation & Admin
          _buildModerationTab(observations, applications, userSession),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddObservationDialog(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildPriceFeedTab(List<PriceObservation> observations) {
    var filtered = observations;
    if (_selectedChannelFilter != 'All') {
      filtered = filtered.where((o) => o.channel == _selectedChannelFilter).toList();
    }
    if (_selectedSourceFilter == 'Trader Confirmed') {
      filtered = filtered
          .where((o) => o.sourceType == ObservationSource.traderConfirmed)
          .toList();
    } else if (_selectedSourceFilter == 'Independently Verified') {
      filtered = filtered
          .where((o) => o.sourceType == ObservationSource.independentlyVerified)
          .toList();
    } else if (_selectedSourceFilter == 'Community') {
      filtered = filtered
          .where((o) => o.sourceType == ObservationSource.communityReported)
          .toList();
    } else if (_selectedSourceFilter == 'Online Verified') {
      filtered = filtered
          .where((o) => o.sourceType == ObservationSource.onlineGrounded)
          .toList();
    }

    return Column(
      children: [
        // Filter bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChannelFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildChannelFilterChip('Local Market'),
                    const SizedBox(width: 8),
                    _buildChannelFilterChip('SMB Store'),
                    const SizedBox(width: 8),
                    _buildChannelFilterChip('Online Retailer'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    'Trader Confirmed',
                    'Independently Verified',
                    'Community',
                    'Online Verified',
                  ].map((src) {
                    final isSel = _selectedSourceFilter == src;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(src),
                        selected: isSel,
                        selectedColor: AppColors.primaryTint,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? AppColors.primary : AppColors.textSecondary,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedSourceFilter = src);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildObservationsList(filtered),
        ),
      ],
    );
  }

  Widget _buildChannelFilterChip(String label) {
    final isSelected = _selectedChannelFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryTint,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedChannelFilter = label);
      },
    );
  }

  Widget _buildSellerPortalTab(
    List<PriceObservation> observations,
    UserSession userSession,
  ) {
    if (!userSession.isSeller) {
      if (userSession.isPendingSeller) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.pending_actions_rounded, color: Color(0xFFE65100), size: 26),
                      SizedBox(width: 10),
                      Text(
                        'Application Pending Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFBF360C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your verification application for "${userSession.businessName ?? "Your Store"}" at ${userSession.marketHub ?? "Bodija Market"} has been submitted.\n\nMarket hub administrators review physical stall location and seller contact before granting price publication permissions.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF795548), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Store: ${userSession.businessName ?? "Not specified"}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Market Hub: ${userSession.marketHub ?? "Bodija Market"}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Channel: ${userSession.sellerChannel ?? "Local Market"}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (userSession.phone != null) ...[
                          const SizedBox(height: 4),
                          Text('Contact: ${userSession.phone!}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      // Customer view - prompt to apply
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00875A), Color(0xFF0052CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'SmartMove Seller Hub',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reach thousands of shoppers looking for the best commodity prices in Bodija, Dugbe, Oje, and across open markets.\n\nAll sellers first submit a verification application with their stall location, subject to administrative approval.',
                  style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showApplyToBecomeSeller(context, userSession),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
                    label: Text(
                      userSession.isRejectedSeller
                          ? 'Reapply as Verified Seller'
                          : 'Apply to Become a Verified Seller',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Demo toggle helper for evaluator
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Evaluator Quick Toggle: Test seller features directly.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).updateRole('Trader');
                  },
                  child: const Text('Try Seller', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Trader / Seller view
    final sellerListings = observations
        .where((o) =>
            o.submitterRole == 'Trader' ||
            o.submitterName.contains('Verified') ||
            o.submitterName == 'You' ||
            (userSession.businessName != null &&
                o.sellerName.toLowerCase().contains(userSession.businessName!.toLowerCase())))
        .toList();

    final inStockCount = sellerListings.where((o) => o.inStock).length;
    final outOfStockCount = sellerListings.where((o) => !o.inStock).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Seller Banner Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00875A), Color(0xFF0052CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        userSession.businessName ?? 'Verified Trader Store',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      userSession.marketHub ?? 'Bodija Market',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Publish and update commodity prices in real time. Direct quotes are badged as "Trader Confirmed" and featured in consumer comparisons.',
                style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _showAddObservationDialog(context, isSellerDirect: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_business_rounded, size: 16),
                label: const Text('Add New Commodity Price', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // KPI Row
        Row(
          children: [
            _buildKpiCard('Total Listings', '${sellerListings.length}', AppColors.primary),
            const SizedBox(width: 8),
            _buildKpiCard('In Stock', '$inStockCount', const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            _buildKpiCard('Out of Stock', '$outOfStockCount', AppColors.errorText),
            const SizedBox(width: 8),
            _buildKpiCard('Status', 'Verified', const Color(0xFF0052CC)),
          ],
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Store Catalog',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(
              '${sellerListings.length} Active',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (sellerListings.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Center(
              child: Text(
                'No seller listings published yet.\nTap "Add New Commodity Price" to reach buyers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          for (final obs in sellerListings)
            _buildSellerListingCard(obs),
      ],
    );
  }

  Widget _buildSellerListingCard(PriceObservation obs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  obs.productName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                obs.formattedPrice,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (obs.brandOrGrade != null)
            Text(
              'Grade: ${obs.brandOrGrade}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${obs.sellerName}  •  ${obs.unit}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (obs.standardizedUnitPrice != null) ...[
                const SizedBox(width: 8),
                Text(
                  '(₦${obs.standardizedUnitPrice!.toStringAsFixed(0)} / ${obs.baseUnit})',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ChoiceChip(
                label: Text(obs.inStock ? 'In Stock' : 'Out of Stock'),
                selected: obs.inStock,
                selectedColor: AppColors.badgeSuccessBg,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: obs.inStock ? AppColors.primary : AppColors.errorText,
                ),
                onSelected: (_) {
                  ref.read(communityProvider.notifier).toggleListingStock(obs.id);
                },
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _showQuickPriceUpdateDialog(context, obs),
                    icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                    label: const Text('Update Price', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                    tooltip: 'Edit details',
                    onPressed: () => _showEditListingDetailsDialog(context, obs),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.errorText),
                    tooltip: 'Delete listing',
                    onPressed: () => _showDeleteListingConfirmation(context, obs),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModerationTab(
    List<PriceObservation> observations,
    List<SellerApplication> applications,
    UserSession userSession,
  ) {
    final isAdmin = userSession.isAdmin;
    final pendingApps = applications
        .where((a) => a.status == SellerApplicationStatus.pending)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Admin Status Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isAdmin ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAdmin ? const Color(0xFFA5D6A7) : const Color(0xFFFFE082),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAdmin ? Icons.admin_panel_settings_rounded : Icons.info_outline_rounded,
                color: isAdmin ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAdmin
                          ? 'Platform Administrator Mode Active'
                          : 'Moderation Console (Read Only)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isAdmin ? const Color(0xFF1B5E20) : const Color(0xFFBF360C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAdmin
                          ? 'Full administrative authority: approve seller applications, verify price quotes, and reject anomalies.'
                          : 'You are viewing moderation in Customer mode. Switch to Administrator to test approval actions.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isAdmin ? const Color(0xFF2E7D32) : const Color(0xFF795548),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAdmin) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).updateRole('Admin');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Switched to Platform Administrator mode'),
                        backgroundColor: AppColors.primary,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Try Admin', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Sub-tab selector: Observations vs Seller Applications
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _moderationSubTab = 'Observations'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _moderationSubTab == 'Observations' ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Price Quotes (${observations.length})',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _moderationSubTab == 'Observations' ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _moderationSubTab = 'Applications'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _moderationSubTab == 'Applications' ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Seller Approvals',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _moderationSubTab == 'Applications' ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                        if (pendingApps.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _moderationSubTab == 'Applications' ? Colors.white : const Color(0xFFE65100),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${pendingApps.length}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _moderationSubTab == 'Applications' ? AppColors.primary : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_moderationSubTab == 'Applications') ...[
          // Seller Applications View
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Seller Registration Applications',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              Text(
                '${pendingApps.length} Pending Review',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (applications.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Center(
                child: Text('No seller applications submitted yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            )
          else
            for (final app in applications)
              _buildSellerApplicationCard(app, isAdmin),
        ] else ...[
          // Price Observations View
          Row(
            children: [
              _buildKpiCard('Total Quotes', '${observations.length}', AppColors.primary),
              const SizedBox(width: 8),
              _buildKpiCard('Verified', '${observations.where((o) => o.isVerified).length}', const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              _buildKpiCard('Pending', '${observations.where((o) => !o.isVerified).length}', const Color(0xFFE65100)),
              const SizedBox(width: 8),
              _buildKpiCard('Anomalies', '${observations.where((o) => o.isFlaggedAnomaly).length}', const Color(0xFFC62828)),
            ],
          ),
          const SizedBox(height: 14),

          // Meta AI Tools Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDuplicateScanDialog(context, observations),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('AI Duplicate Audit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showPriceAnomalyScanDialog(context, observations),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7)),
                  icon: const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                  label: const Text('AI Anomaly Scan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Pending', 'Flagged', 'Verified'].map((f) {
                final isSel = _moderationFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(f == 'All'
                        ? 'All (${observations.length})'
                        : f == 'Pending'
                            ? 'Pending (${observations.where((o) => !o.isVerified).length})'
                            : f == 'Flagged'
                                ? 'Anomalies (${observations.where((o) => o.isFlaggedAnomaly).length})'
                                : 'Verified (${observations.where((o) => o.isVerified).length})'),
                    selected: isSel,
                    selectedColor: AppColors.primaryTint,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? AppColors.primary : AppColors.textSecondary,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _moderationFilter = f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          for (final obs in _getFilteredModerationObservations(observations))
            _buildModerationObservationCard(obs, isAdmin),
        ],
      ],
    );
  }

  List<PriceObservation> _getFilteredModerationObservations(List<PriceObservation> list) {
    if (_moderationFilter == 'Pending') {
      return list.where((o) => !o.isVerified).toList();
    }
    if (_moderationFilter == 'Flagged') {
      return list.where((o) => o.isFlaggedAnomaly).toList();
    }
    if (_moderationFilter == 'Verified') {
      return list.where((o) => o.isVerified).toList();
    }
    return list;
  }

  Widget _buildSellerApplicationCard(SellerApplication app, bool isAdmin) {
    final isPending = app.status == SellerApplicationStatus.pending;
    final isApproved = app.status == SellerApplicationStatus.approved;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending ? const Color(0xFFFFE082) : isApproved ? const Color(0xFFA5D6A7) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  app.businessName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFFF8E1)
                      : isApproved
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  app.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPending
                        ? const Color(0xFFE65100)
                        : isApproved
                            ? const Color(0xFF2E7D32)
                            : AppColors.errorText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Applicant: ${app.applicantName}  •  ${app.marketHub}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Channel: ${app.sellerChannel}  •  Phone: ${app.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (app.stallLocation != null && app.stallLocation!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Stall: ${app.stallLocation!}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
          if (app.rejectionReason != null && app.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reason: ${app.rejectionReason!}', style: const TextStyle(fontSize: 11, color: AppColors.errorText)),
          ],
          if (isPending) ...[
            const Divider(height: 16, color: AppColors.divider),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isAdmin) ...[
                  OutlinedButton.icon(
                    onPressed: () => _showRejectApplicationDialog(context, app),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.errorText),
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(sellerApplicationsProvider.notifier).approveApplication(app.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${app.businessName} approved as verified seller!'),
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                    icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    label: const Text('Approve Seller', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ] else ...[
                  const Text('Admin approval required to activate seller account.', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModerationObservationCard(PriceObservation obs, bool isAdmin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: obs.isFlaggedAnomaly ? const Color(0xFFFFCDD2) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${obs.productName} — ${obs.formattedPrice}/${obs.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: obs.isFlaggedAnomaly
                      ? const Color(0xFFFFEBEE)
                      : obs.isVerified
                          ? AppColors.badgeSuccessBg
                          : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  obs.verificationBadgeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: obs.isFlaggedAnomaly
                        ? const Color(0xFFC62828)
                        : obs.isVerified
                            ? AppColors.badgeSuccessText
                            : const Color(0xFFB78103),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${obs.sellerName}  •  ${obs.channel}  •  Submitted by ${obs.submitterName} (${obs.submitterRole})',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          if (obs.isFlaggedAnomaly) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFC62828)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      obs.anomalyReason ?? 'Extreme price variance detected by Meta AI',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFFC62828), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isAdmin) ...[
            const Divider(height: 14, color: AppColors.divider),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    obs.isVerified ? Icons.verified_rounded : Icons.check_circle_outline,
                    color: obs.isVerified ? AppColors.primary : AppColors.textTertiary,
                    size: 20,
                  ),
                  tooltip: obs.isVerified ? 'Mark Unverified' : 'Verify Observation',
                  onPressed: () {
                    ref.read(communityProvider.notifier).verifyObservation(obs.id, !obs.isVerified);
                  },
                ),
                IconButton(
                  icon: Icon(
                    obs.isFlaggedAnomaly ? Icons.flag : Icons.flag_outlined,
                    color: obs.isFlaggedAnomaly ? const Color(0xFFC62828) : AppColors.textTertiary,
                    size: 20,
                  ),
                  tooltip: 'Flag / Unflag Anomaly',
                  onPressed: () => _showFlagAnomalyDialog(context, obs),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorText, size: 20),
                  tooltip: 'Reject & Remove',
                  onPressed: () => _showDeleteListingConfirmation(context, obs),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickPriceUpdateDialog(BuildContext context, PriceObservation obs) {
    final priceController = TextEditingController(text: obs.price.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.price_change_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Update Price: ${obs.productName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Package unit: ${obs.unit}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'New Price (₦)',
                prefixText: '₦ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(priceController.text.trim());
              if (newPrice != null && newPrice > 0) {
                ref.read(communityProvider.notifier).updateListingPrice(obs.id, newPrice);
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Price updated to ₦${newPrice.toStringAsFixed(0)}'),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditListingDetailsDialog(BuildContext context, PriceObservation obs) {
    final priceController = TextEditingController(text: obs.price.toStringAsFixed(0));
    final unitController = TextEditingController(text: obs.unit);
    final brandController = TextEditingController(text: obs.brandOrGrade ?? '');
    final notesController = TextEditingController(text: obs.notes ?? '');
    bool inStock = obs.inStock;
    String channel = obs.channel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit ${obs.productName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(bottomCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: brandController,
                  decoration: const InputDecoration(labelText: 'Brand or Grade', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (₦)',
                          prefixText: '₦ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: unitController,
                        decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Stall / Location Notes', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Currently In Stock', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: inStock,
                  onChanged: (val) => setModalState(() => inStock = val),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final newPrice = double.tryParse(priceController.text.trim());
                      if (newPrice != null && newPrice > 0) {
                        ref.read(communityProvider.notifier).updateListingDetails(
                              id: obs.id,
                              price: newPrice,
                              unit: unitController.text.trim(),
                              brandOrGrade: brandController.text.trim().isNotEmpty
                                  ? brandController.text.trim()
                                  : null,
                              inStock: inStock,
                              notes: notesController.text.trim().isNotEmpty
                                  ? notesController.text.trim()
                                  : null,
                              channel: channel,
                            );
                        Navigator.pop(bottomCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Listing updated successfully!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteListingConfirmation(BuildContext context, PriceObservation obs) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: Text('Are you sure you want to remove the listing for "${obs.productName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorText),
            onPressed: () {
              ref.read(communityProvider.notifier).deleteListing(obs.id);
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed listing for ${obs.productName}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFlagAnomalyDialog(BuildContext context, PriceObservation obs) {
    final reasonController = TextEditingController(
      text: obs.isFlaggedAnomaly ? (obs.anomalyReason ?? '') : 'Suspicious deviation from market average',
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              obs.isFlaggedAnomaly ? Icons.check_circle_outline : Icons.flag_outlined,
              color: obs.isFlaggedAnomaly ? AppColors.primary : const Color(0xFFC62828),
            ),
            const SizedBox(width: 8),
            Text(obs.isFlaggedAnomaly ? 'Clear Anomaly Flag' : 'Flag Price Anomaly'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item: ${obs.productName} (${obs.formattedPrice}/${obs.unit})'),
            const SizedBox(height: 8),
            if (!obs.isFlaggedAnomaly)
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Flagging',
                  hintText: 'e.g. Price too low for Grade A rice',
                  border: OutlineInputBorder(),
                ),
              )
            else
              const Text('Remove the anomaly warning and restore normal listing status?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: obs.isFlaggedAnomaly ? AppColors.primary : const Color(0xFFC62828),
            ),
            onPressed: () {
              ref.read(communityProvider.notifier).flagListingAnomaly(
                    obs.id,
                    isAnomalous: !obs.isFlaggedAnomaly,
                    reason: !obs.isFlaggedAnomaly ? reasonController.text.trim() : null,
                  );
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(obs.isFlaggedAnomaly
                      ? 'Anomaly flag cleared'
                      : 'Listing flagged as price anomaly'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Text(
              obs.isFlaggedAnomaly ? 'Restore Listing' : 'Flag as Anomaly',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectApplicationDialog(BuildContext context, SellerApplication app) {
    final reasonController = TextEditingController(text: 'Stall credentials could not be verified in market hub');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject Seller Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applicant: ${app.applicantName} (${app.businessName})'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Rejection',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorText),
            onPressed: () {
              ref.read(sellerApplicationsProvider.notifier).rejectApplication(
                    app.id,
                    reason: reasonController.text.trim(),
                  );
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Application for ${app.businessName} rejected.'),
                  backgroundColor: AppColors.errorText,
                ),
              );
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPriceAnomalyScanDialog(BuildContext context, List<PriceObservation> observations) {
    const aiService = MetaAiService();
    final result = aiService.auditPriceAnomalies(candidates: observations);

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFFC62828), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Meta AI Price Anomaly Audit',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          result.hasAnomaly
                              ? 'Found ${result.anomalousItems.length} price outlier(s) exceeding normal variance'
                              : 'All active listings fall within acceptable market bounds',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

              // KPI Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Market Average', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          '₦${result.averageMarketPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    Container(height: 24, width: 1, color: AppColors.divider),
                    Column(
                      children: [
                        const Text('Price Spread', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          '${result.priceSpreadPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: result.priceSpreadPercent > 50 ? const Color(0xFFC62828) : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 24, width: 1, color: AppColors.divider),
                    Column(
                      children: [
                        const Text('Outliers Flagged', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          '${result.anomalousItems.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: result.anomalousItems.isNotEmpty ? const Color(0xFFC62828) : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (result.explanation.isNotEmpty) ...[
                Text(
                  result.explanation,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 12),
              ],

              if (result.anomalousItems.isNotEmpty) ...[
                const Text(
                  'Flagged Outlier Listings',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                for (final item in result.anomalousItems)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.observation.productName} — ${item.observation.formattedPrice}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                '${item.observation.sellerName}  •  ${item.deviationPercent > 0 ? "+${item.deviationPercent.toStringAsFixed(0)}%" : "${item.deviationPercent.toStringAsFixed(0)}%"} vs average',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFB78103)),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(communityProvider.notifier).flagListingAnomaly(
                                  item.observation.id,
                                  isAnomalous: true,
                                  reason: item.anomalyType,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Flagged ${item.observation.productName} as anomaly'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Flag', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close Audit', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApplyToBecomeSeller(BuildContext context, UserSession session) {
    final bizController = TextEditingController(text: session.businessName ?? '');
    final phoneController = TextEditingController(text: session.phone ?? '');
    final stallController = TextEditingController(text: session.stallLocation ?? '');
    String selectedHub = session.marketHub ?? 'Bodija Market';
    String selectedChannel = session.sellerChannel ?? 'Local Market';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Seller Verification Application',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Register your store or stall. All applications undergo review and physical stall check by market hub administrators.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 14),
                    const Text('Business / Stall Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bizController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Alhaja Kudirat Grains & Oils',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Market Hub Base', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedHub,
                      items: const [
                        'Bodija Market',
                        'Dugbe Market',
                        'Oje Market',
                        'Oja Oba Market',
                        'Gbagi Market',
                        'Online Store',
                      ].map((hub) => DropdownMenuItem(value: hub, child: Text(hub))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedHub = val);
                      },
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 14),
                    const Text('Channel Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['Local Market', 'SMB Store', 'Online Retailer'].map((ch) {
                        final isSel = selectedChannel == ch;
                        return ChoiceChip(
                          label: Text(ch),
                          selected: isSel,
                          selectedColor: AppColors.badgeSuccessBg,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSel ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedChannel = ch);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text('Stall / Shop Location Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: stallController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Stall B44, Main Grain Section, Bodija',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('WhatsApp / Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. +234 803 123 4567',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (bizController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please provide your business name and contact phone.'),
                                backgroundColor: AppColors.badgeErrorText,
                              ),
                            );
                            return;
                          }

                          ref.read(sellerApplicationsProvider.notifier).submitApplication(
                                user: session,
                                businessName: bizController.text.trim(),
                                marketHub: selectedHub,
                                sellerChannel: selectedChannel,
                                stallLocation: stallController.text.trim().isNotEmpty
                                    ? stallController.text.trim()
                                    : null,
                                phone: phoneController.text.trim(),
                              );

                          Navigator.pop(bottomSheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Seller application submitted! Awaiting administrator approval.'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        child: const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildObservationsList(List<PriceObservation> list) {
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No price observations found for this filter.',
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final obs = list[index];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: obs.isFlaggedAnomaly ? const Color(0xFFFFCDD2) : AppColors.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obs.productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (obs.brandOrGrade != null)
                          Text(
                            obs.brandOrGrade!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        obs.formattedPrice,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '/${obs.unit}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    obs.channel == 'Online Retailer'
                        ? Icons.laptop_mac_rounded
                        : obs.channel == 'SMB Store'
                            ? Icons.storefront_rounded
                            : Icons.shopping_basket_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${obs.sellerName}  •  ${obs.channel}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  if (obs.standardizedUnitPrice != null) ...[
                    const Spacer(),
                    Text(
                      '₦${obs.standardizedUnitPrice!.toStringAsFixed(0)} / ${obs.baseUnit}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: obs.isFlaggedAnomaly
                          ? const Color(0xFFFFEBEE)
                          : obs.isVerified
                              ? AppColors.badgeSuccessBg
                              : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      obs.verificationBadgeLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: obs.isFlaggedAnomaly
                            ? const Color(0xFFC62828)
                            : obs.isVerified
                                ? AppColors.badgeSuccessText
                                : const Color(0xFFB78103),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    obs.timeAgo,
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const Spacer(),
                  // In stock indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: obs.inStock ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      obs.inStock ? 'In Stock' : 'Out of Stock',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: obs.inStock ? const Color(0xFF2E7D32) : AppColors.errorText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

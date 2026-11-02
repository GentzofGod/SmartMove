import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/seller_application.dart';
import '../../../core/models/item_acquisition_source.dart';
import '../../../core/presentation/widgets/commodity_image_widget.dart';
import '../../../core/presentation/widgets/seller_location_map_sheet.dart';
import '../../../core/presentation/widgets/report_modal_sheet.dart';
import '../../decision_lab/presentation/widgets/trader_negotiation_sheet.dart';
import '../../../core/services/commodity_comparison_service.dart';
import '../../../core/localization/app_language.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const CommunityScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  late int _selectedTab; // 0: Verified Seller Added Products, 1: Community Added Products
  String _selectedCategory = 'All'; // 'All', 'Food', 'Electronics', 'Pharmacy', 'Others'
  bool _userExplicitlySelectedTab = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1);
  }

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

  void _showAddObservationDialog(BuildContext context) {
    final userSession = ref.read(authProvider);
    final applications = ref.read(sellerApplicationsProvider);

    if (userSession.isGuest) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text(
            'Guest users can explore market prices. To publish community price quotes, please sign in or create an account.',
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

    // Check if user is a verified seller. Verified sellers cannot post through community channels.
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Verified sellers cannot post listings through general community channels.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Please publish and manage your official inventory, pricing, stock levels, and stall location directly in your dedicated Seller Portal to maintain verified merchant status and stall geolocation.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Dismiss',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.storefront_rounded, size: 16),
              label: const Text('Go to Seller Portal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
    final brandController = TextEditingController();
    final notesController = TextEditingController();
    String channel = 'Local Market';
    String category = 'Food';
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
                        const Expanded(
                          child: Text(
                            'Report Price Observation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
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

                    // Poster Name Attribution
                    TextField(
                      controller: posterNameController,
                      decoration: InputDecoration(
                        labelText: 'Your Name (Poster Name)',
                        hintText: 'e.g. Aisha B., Chidi K., Mama Tolu',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        helperText: 'Your name will be displayed on this community price contribution',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

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
                        labelText: 'Market / Store Name',
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
                            Expanded(
                              child: Text(
                                'Standardized Unit Price: ₦${previewStandardized.toStringAsFixed(0)} / $baseUnit',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
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

                    // Category Selector
                    const Text(
                      'Category:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: (ref.read(categoriesProvider).isNotEmpty
                              ? ref.read(categoriesProvider).map((c) => c.name).toList()
                              : ['Food', 'Electronics', 'Pharmacy', 'Others'])
                          .map((cat) {
                        final isSel = category == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSel,
                          selectedColor: AppColors.primaryTint,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? AppColors.primary : AppColors.textSecondary,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => category = cat);
                          },
                        );
                      }).toList(),
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
                            final posterName = posterNameController.text.trim().isNotEmpty
                                ? posterNameController.text.trim()
                                : (userSession.displayName.trim().isNotEmpty
                                    ? userSession.displayName.trim()
                                    : 'Community Shopper');

                            ref.read(communityProvider.notifier).addObservation(
                                  productName: productController.text.trim(),
                                  sellerName: sellerController.text.trim().isNotEmpty
                                      ? sellerController.text.trim()
                                      : 'Local Market',
                                  price: price,
                                  unit: unitController.text.trim(),
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
                                );
                            Navigator.pop(bottomCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Price observation submitted to community!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        },
                        child: const Text('Submit Observation'),
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

  @override
  Widget build(BuildContext context) {
    final observations = ref.watch(communityProvider);
    final applications = ref.watch(sellerApplicationsProvider);
    final rawUserSession = ref.watch(authProvider);

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
            businessName:
                rawUserSession.businessName ?? matchingApp.businessName,
            marketHub: rawUserSession.marketHub ?? matchingApp.marketHub,
            sellerChannel:
                rawUserSession.sellerChannel ?? matchingApp.sellerChannel,
            phone: rawUserSession.phone ?? matchingApp.phone,
            stallLocation:
                rawUserSession.stallLocation ?? matchingApp.stallLocation,
            latitude: rawUserSession.latitude ?? matchingApp.latitude,
            longitude: rawUserSession.longitude ?? matchingApp.longitude,
          )
        : (matchingApp != null &&
                matchingApp.status == SellerApplicationStatus.pending &&
                !rawUserSession.isApprovedSeller &&
                !rawUserSession.isPendingSeller)
            ? rawUserSession.copyWith(
                sellerApplicationStatus: SellerApplicationStatus.pending,
                businessName:
                    rawUserSession.businessName ?? matchingApp.businessName,
                marketHub: rawUserSession.marketHub ?? matchingApp.marketHub,
                phone: rawUserSession.phone ?? matchingApp.phone,
              )
            : rawUserSession;

    final pendingAppsCount = applications
        .where((a) => a.status == SellerApplicationStatus.pending)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr(ref, 'navCommunity'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Verified commodity prices across online & local markets.',
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
                avatar: const Icon(Icons.shield_rounded,
                    size: 15, color: Colors.white),
                label: Text(
                  pendingAppsCount > 0
                      ? 'SuperAdmin ($pendingAppsCount)'
                      : 'SuperAdmin Panel',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: const Color(0xFF673AB7),
                onPressed: () => context.push('/superadmin'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(observations),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddObservationDialog(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  bool _isVerifiedSellerObs(PriceObservation o) {
    return o.isVerified ||
        o.sourceType == ObservationSource.traderProvided ||
        o.sourceType == ObservationSource.traderConfirmed ||
        o.sourceType == ObservationSource.independentlyVerified ||
        o.submitterRole == 'Trader' ||
        o.submitterRole == 'Seller';
  }

  Widget _buildBody(List<PriceObservation> observations) {
    final verifiedSellerList = observations.where(_isVerifiedSellerObs).toList();
    final communityList = observations.where((o) => !_isVerifiedSellerObs(o)).toList();

    int effectiveTab = _selectedTab;
    if (!_userExplicitlySelectedTab) {
      if (effectiveTab == 0 && verifiedSellerList.isEmpty && communityList.isNotEmpty) {
        effectiveTab = 1;
      } else if (effectiveTab == 1 && communityList.isEmpty && verifiedSellerList.isNotEmpty) {
        effectiveTab = 0;
      }
    }

    var activeList = effectiveTab == 0 ? verifiedSellerList : communityList;

    if (_selectedCategory != 'All') {
      activeList = activeList.where((o) {
        final oCat = o.category.toLowerCase();
        final sCat = _selectedCategory.toLowerCase();
        if (sCat == 'food') {
          return oCat == 'food' ||
              oCat == 'groceries' ||
              oCat.contains('grain') ||
              oCat.contains('tuber') ||
              oCat.contains('oil');
        }
        return oCat == sCat;
      }).toList();
    }

    return Column(
      children: [
        // 1. Two-tab segmented switcher: Verified Seller Added Products vs Community Added Products
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('tab_verified_sellers'),
                    onTap: () => setState(() {
                      _selectedTab = 0;
                      _userExplicitlySelectedTab = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: effectiveTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: effectiveTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: effectiveTab == 0 ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Verified Sellers (${verifiedSellerList.length})',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: effectiveTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                color: effectiveTab == 0 ? AppColors.primary : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('tab_community_reports'),
                    onTap: () => setState(() {
                      _selectedTab = 1;
                      _userExplicitlySelectedTab = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: effectiveTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: effectiveTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 16,
                            color: effectiveTab == 1 ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Community Reports (${communityList.length})',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: effectiveTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                color: effectiveTab == 1 ? AppColors.primary : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Single-line Category Filter Chips (powered dynamically by categoriesProvider)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('All', Icons.grid_view_rounded),
                for (final cat in ref.watch(categoriesProvider)) ...[
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    cat.name,
                    (cat.slug == 'food' || cat.slug == 'groceries')
                        ? Icons.restaurant_outlined
                        : (cat.slug == 'electronics'
                            ? Icons.devices_rounded
                            : (cat.slug == 'pharmacy'
                                ? Icons.medical_services_outlined
                                : Icons.category_outlined)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.cardBorder),

        // 3. Observations List
        Expanded(
          child: _buildObservationsList(activeList),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, IconData icon) {
    final isSelected = _selectedCategory == label;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryTint,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.cardBorder,
        ),
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedCategory = label);
      },
    );
  }

  Widget _buildObservationsList(List<PriceObservation> list) {
    if (list.isEmpty) {
      final isOverallEmpty = ref.watch(communityProvider).isEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 52,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 14),
              Text(
                isOverallEmpty ? 'No Community Price Quotes Yet' : 'No Listings in this Section',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isOverallEmpty
                    ? 'No observations have been reported yet for this filter. Tap the + button to contribute verified market prices.'
                    : 'Switch tabs or adjust category filters above, or tap the + button to contribute market prices.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
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
              // Product details row with CommodityImageWidget
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommodityImageWidget(
                    imageUrl: obs.imageUrl,
                    commodityName: obs.productName,
                    size: 52,
                    borderRadius: 10,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                obs.productName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                obs.category,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (obs.brandOrGrade != null) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  obs.brandOrGrade!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (obs.standardizedUnitPrice != null) ...[
                              const Spacer(),
                              Text(
                                '₦${obs.standardizedUnitPrice!.toStringAsFixed(0)} / ${obs.baseUnit}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Seller and Location Info
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
                  Expanded(
                    child: Text(
                      '${obs.sellerName}  •  ${obs.marketLocation}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: obs.inStock
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      obs.inStock ? 'In Stock' : 'Out of Stock',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: obs.inStock
                            ? const Color(0xFF2E7D32)
                            : AppColors.errorText,
                      ),
                    ),
                  ),
                ],
              ),
              // Submitter / Poster Name attribution
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    _isVerifiedSellerObs(obs)
                        ? Icons.verified_user_outlined
                        : Icons.person_pin_circle_outlined,
                    size: 13,
                    color: _isVerifiedSellerObs(obs)
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _isVerifiedSellerObs(obs)
                          ? 'Verified Seller: ${obs.sellerName}'
                          : 'Posted by: ${obs.submitterName.trim().isNotEmpty ? obs.submitterName : 'Community Contributor'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isVerifiedSellerObs(obs)
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Verification badge, time, and Report button
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
                  Expanded(
                    child: Text(
                      obs.timeAgo,
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    key: ValueKey('btn_report_obs_${obs.id}'),
                    onTap: () => ReportModalSheet.show(context, obs),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: obs.isFlaggedAnomaly
                            ? const Color(0xFFFFEBEE)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: obs.isFlaggedAnomaly
                              ? const Color(0xFFE57373)
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            obs.isFlaggedAnomaly ? Icons.flag_rounded : Icons.flag_outlined,
                            size: 13,
                            color: obs.isFlaggedAnomaly
                                ? const Color(0xFFC62828)
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            obs.isFlaggedAnomaly ? 'Reported' : 'Report',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: obs.isFlaggedAnomaly
                                  ? const Color(0xFFC62828)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (obs.isFlaggedAnomaly && obs.anomalyReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFC62828)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Flagged for Moderation: ${obs.anomalyReason}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC62828),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Action Buttons: Locate on Map & Chat & Buy
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.location_on_outlined, size: 14),
                      label: const Text(
                        'Locate on Map',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                      label: const Text(
                        'Chat & Buy',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final source = ItemAcquisitionSource.fromObservation(obs);
                        TraderNegotiationSheet.show(context, source: source);
                      },
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

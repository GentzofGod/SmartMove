import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/seller_application.dart';
import '../../../core/services/commodity_comparison_service.dart';
import '../../../core/localization/app_language.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const CommunityScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _selectedChannelFilter = 'All';
  String _selectedSourceFilter = 'All';

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

  void _showAddObservationDialog(BuildContext context, {bool isSellerDirect = false}) {
    final userSession = ref.read(authProvider);
    if (userSession.isGuest) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text(
            'Guest users can explore market prices. To publish community price quotes or manage commodity listings, please sign in or create an account.',
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
        child: _buildPriceFeedTab(observations),
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

  Widget _buildObservationsList(List<PriceObservation> list) {
    if (list.isEmpty) {
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
              const Text(
                'No Community Price Quotes Yet',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No observations have been reported yet for this filter. Tap the + button to contribute verified market prices.',
                textAlign: TextAlign.center,
                style: TextStyle(
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
                  Expanded(
                    child: Text(
                      '${obs.sellerName}  •  ${obs.channel}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (obs.standardizedUnitPrice != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '₦${obs.standardizedUnitPrice!.toStringAsFixed(0)} / ${obs.baseUnit}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      obs.timeAgo,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // In stock indicator
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
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/product.dart';
import '../../../core/services/meta_ai_service.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedChannelFilter = 'All';

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
    final productController = TextEditingController();
    final sellerController = TextEditingController();
    final priceController = TextEditingController();
    final unitController = TextEditingController(text: '1kg');
    final brandController = TextEditingController();
    final userSession = ref.read(authProvider);
    String submitterRole = isSellerDirect ? 'Trader' : userSession.role;
    String channel = 'Local Market';
    bool inStock = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: productController,
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
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
                            decoration: InputDecoration(
                              labelText: 'Package Unit',
                              hintText: '1kg, 50kg, 1L, crate',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    const SizedBox(height: 14),

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
                                      : 'Local Market',
                                  price: price,
                                  unit: unitController.text.trim(),
                                  submitterName: isSellerDirect ? 'You (Verified Seller)' : userSession.displayName,
                                  submitterRole: submitterRole,
                                  channel: channel,
                                  brandOrGrade: brandController.text.trim().isNotEmpty
                                      ? brandController.text.trim()
                                      : null,
                                  inStock: inStock,
                                );
                            Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final observations = ref.watch(communityProvider);
    final userSession = ref.watch(authProvider);

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
          tabs: const [
            Tab(text: 'Price Feed'),
            Tab(text: 'Seller Portal'),
            Tab(text: 'Moderation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Filterable Price Feed
          _buildPriceFeedTab(observations),

          // Tab 2: Seller Portal
          _buildSellerPortalTab(observations, userSession.role),

          // Tab 3: Moderation & Admin
          _buildModerationTab(observations, userSession.role),
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
      filtered = observations.where((o) => o.channel == _selectedChannelFilter).toList();
    }

    return Column(
      children: [
        // Channel filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
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

  Widget _buildSellerPortalTab(List<PriceObservation> observations, String role) {
    final sellerListings = observations
        .where((o) => o.submitterRole == 'Trader' || o.submitterName.contains('Verified') || o.submitterName == 'You')
        .toList();

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
                children: const [
                  Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Trader & Seller Hub',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Publish verified wholesale or retail commodity prices directly to consumers in your regional market hub.',
                style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
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
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Business Listings',
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
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                obs.formattedPrice,
                style: const TextStyle(
                  fontSize: 15,
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${obs.sellerName}  •  ${obs.unit}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Row(
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
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModerationTab(List<PriceObservation> observations, String role) {
    final isAdmin = role == 'Trader' || role == 'Admin';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAdmin
                      ? 'Administrator Mode Active: Review and verify community commodity price submissions.'
                      : 'Community reports undergo independent verification by market administrators.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAdmin ? const Color(0xFF1B5E20) : const Color(0xFFBF360C),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Meta AI Duplicate Detection Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Meta AI Duplicate Listing Audit',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Uses Muse Spark to scan seller price submissions for duplicate commodity listings across online and open markets.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _showDuplicateScanDialog(context, observations),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.manage_search_rounded, size: 16),
                label: const Text('Run Duplicate Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Pending Verification Feed',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),

        for (final obs in observations)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${obs.productName} — ${obs.formattedPrice}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        '${obs.sellerName}  •  ${obs.channel}  •  Reported by ${obs.submitterName}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  IconButton(
                    icon: Icon(
                      obs.isVerified ? Icons.verified_rounded : Icons.check_circle_outline,
                      color: obs.isVerified ? AppColors.primary : AppColors.textTertiary,
                    ),
                    tooltip: obs.isVerified ? 'Verified' : 'Verify this observation',
                    onPressed: () {
                      ref.read(communityProvider.notifier).verifyObservation(obs.id, !obs.isVerified);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(obs.isVerified
                              ? 'Marked as unverified'
                              : 'Observation confirmed as verified!'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
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
            border: Border.all(color: AppColors.cardBorder),
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
                ],
              ),
              const SizedBox(height: 8),

              // Badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: obs.isVerified ? AppColors.badgeSuccessBg : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      obs.isVerified ? '✓ Verified Source' : 'Community Observation',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: obs.isVerified ? AppColors.badgeSuccessText : const Color(0xFFB78103),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    obs.timeAgo,
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const Spacer(),
                  // Confirm price action
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you! Price confirmation recorded.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: const [
                          Icon(Icons.thumb_up_alt_outlined, size: 13, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Confirm', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ],
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

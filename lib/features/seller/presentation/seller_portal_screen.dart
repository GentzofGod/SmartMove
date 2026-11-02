import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/seller_application.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/commodity_comparison_service.dart';
import '../../../core/services/meta_ai_service.dart';
import '../../../core/presentation/widgets/commodity_image_widget.dart';

class SellerPortalScreen extends ConsumerStatefulWidget {
  const SellerPortalScreen({super.key});

  @override
  ConsumerState<SellerPortalScreen> createState() => _SellerPortalScreenState();
}

class _SellerPortalScreenState extends ConsumerState<SellerPortalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(authProvider);
      final sellerName = session.businessName ?? session.displayName;
      if (sellerName.isNotEmpty) {
        ref.read(traderChatProvider.notifier).syncSellerInquiries(sellerName);
      }
      ref.read(communityProvider.notifier).fetchLive();
      ref.read(storeEditRequestsProvider.notifier).fetchLive();
      ref.read(sellerApplicationsProvider.notifier).fetchLive();
    });
  }

  void _showAddObservationDialog(BuildContext context, UserSession userSession) {
    final productController = TextEditingController();
    final sellerController = TextEditingController(
      text: userSession.businessName ?? userSession.displayName,
    );
    final priceController = TextEditingController();
    final unitController = TextEditingController(text: '1kg');
    final brandController = TextEditingController();
    final notesController = TextEditingController();
    String channel = userSession.sellerChannel ?? 'Local Market';
    final categories = ref.read(categoriesProvider).map((c) => c.name).toList();
    if (categories.isEmpty) {
      categories.addAll(['Food', 'Electronics', 'Pharmacy', 'Others']);
    }
    String selectedCategory = categories.first;
    bool inStock = true;
    String? modalErrorMessage;
    bool isGeneratingDescription = false;

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
            final parsedPrice =
                double.tryParse(priceController.text.trim()) ?? 0.0;
            final mult = CommodityComparisonService.calculateUnitMultiplier(
              unitController.text.trim(),
              commodityName: productController.text.trim(),
            );
            final previewStandardized =
                mult > 0 ? (parsedPrice / mult) : parsedPrice;
            final baseUnit = CommodityComparisonService.resolveBaseUnit(
              unitController.text.trim(),
              commodityName: productController.text.trim(),
            );

            return SafeArea(
              top: false,
              child: Padding(
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
                            'Publish Seller Price Listing',
                            style: TextStyle(
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
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.badgeSuccessBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Publishing as verified trader: ${userSession.businessName ?? userSession.displayName}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Commodity / Product Name *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: productController,
                        onChanged: (_) {
                          if (modalErrorMessage != null) {
                            setModalState(() => modalErrorMessage = null);
                          } else {
                            setModalState(() {});
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g. White Garri, Brown Beans, Palm Oil',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Category *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedCategory = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Price (₦) *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: priceController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: InputDecoration(
                                    prefixText: '₦ ',
                                    hintText: '3500',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Unit *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: unitController,
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: InputDecoration(
                                    hintText: '1kg / paint',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (parsedPrice > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate_outlined,
                                  size: 14, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 6),
                              Text(
                                'Normalized unit price: ₦${previewStandardized.toStringAsFixed(0)} / $baseUnit',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Brand (Optional)',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: brandController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Mama Gold, Golden Penny',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('In Stock',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Switch(
                                value: inStock,
                                activeThumbColor: AppColors.primary,
                                onChanged: (val) =>
                                    setModalState(() => inStock = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Notes / Description',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          TextButton.icon(
                            key: const ValueKey('btn_ai_generate_description'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                            ),
                            icon: isGeneratingDescription
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF673AB7),
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome,
                                    size: 14, color: Color(0xFF673AB7)),
                            label: Text(
                              isGeneratingDescription
                                  ? 'Generating...'
                                  : 'AI Generate Description',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF673AB7),
                              ),
                            ),
                            onPressed: isGeneratingDescription
                                ? null
                                : () async {
                                    final prodName = productController.text.trim();
                                    if (prodName.isEmpty) {
                                      setModalState(() {
                                        modalErrorMessage =
                                            'Please enter a Commodity / Product Name first so AI has context to generate the description.';
                                      });
                                      return;
                                    }
                                    if (selectedCategory.trim().isEmpty) {
                                      setModalState(() {
                                        modalErrorMessage =
                                            'Please select a Category first so AI has context to generate the description.';
                                      });
                                      return;
                                    }

                                    setModalState(() {
                                      modalErrorMessage = null;
                                      isGeneratingDescription = true;
                                    });

                                    final desc = await const MetaAiService()
                                        .generateProductDescription(
                                      productName: prodName,
                                      category: selectedCategory,
                                      brand: brandController.text.trim().isNotEmpty
                                          ? brandController.text.trim()
                                          : null,
                                      unit: unitController.text.trim().isNotEmpty
                                          ? unitController.text.trim()
                                          : null,
                                      price: double.tryParse(priceController.text.trim()),
                                      currentNotes: notesController.text.trim().isNotEmpty
                                          ? notesController.text.trim()
                                          : null,
                                    );

                                    setModalState(() {
                                      isGeneratingDescription = false;
                                      notesController.text = desc;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Fresh batch from market warehouse, discount on bulk bags.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (modalErrorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          key: const ValueKey('dialog_error_banner'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF9A9A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 16, color: Color(0xFFC62828)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalErrorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setModalState(() => modalErrorMessage = null),
                                child: const Icon(Icons.close, size: 14, color: Color(0xFFC62828)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final name = productController.text.trim();
                            final pStr = priceController.text.trim();
                            if (name.isEmpty) {
                              setModalState(() {
                                modalErrorMessage =
                                    'Product name is required. Please enter a commodity or product name.';
                              });
                              return;
                            }
                            if (pStr.isEmpty) {
                              setModalState(() {
                                modalErrorMessage =
                                    'Price is required. Please enter the listing price in ₦.';
                              });
                              return;
                            }
                            final price = double.tryParse(pStr) ?? 0.0;
                            if (price <= 0) {
                              setModalState(() {
                                modalErrorMessage =
                                    'Please enter a valid price amount greater than ₦0.';
                              });
                              return;
                            }
                            if (unitController.text.trim().isEmpty) {
                              setModalState(() {
                                modalErrorMessage =
                                    'Unit is required (e.g. 1kg, paint rubber, bag).';
                              });
                              return;
                            }

                            final unit = unitController.text.trim().isNotEmpty
                                ? unitController.text.trim()
                                : '1kg';
                            final finalBrand = brandController.text.trim().isNotEmpty
                                ? brandController.text.trim()
                                : null;
                            final finalNotes = notesController.text.trim().isNotEmpty
                                ? notesController.text.trim()
                                : null;

                            ref
                                .read(communityProvider.notifier)
                                .addObservation(
                                  productName: name,
                                  sellerName: sellerController.text.trim().isNotEmpty
                                      ? sellerController.text.trim()
                                      : (userSession.businessName ?? 'Verified Trader'),
                                  price: price,
                                  unit: unit,
                                  category: selectedCategory,
                                  submitterName: 'You (Verified Seller)',
                                  submitterRole: 'Trader',
                                  channel: channel,
                                  brandOrGrade: finalBrand,
                                  notes: finalNotes ?? userSession.stallLocation,
                                  marketLocation: userSession.marketHub ?? userSession.stallLocation ?? 'Local Store',
                                  latitude: userSession.latitude,
                                  longitude: userSession.longitude,
                                  inStock: inStock,
                                );
                            Navigator.pop(bottomCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Price quote published for "$name"!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          child: const Text(
                            'Publish Price Quote',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
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

  void _confirmDeleteObservation(BuildContext context, PriceObservation obs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Are you sure you want to remove "${obs.productName}" from your active store listings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.badgeErrorText,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(communityProvider.notifier).deleteListing(obs.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('"${obs.productName}" removed from your listings.'),
                  backgroundColor: AppColors.textPrimary,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditObservationDialog(BuildContext context, PriceObservation obs) {
    final userSession = ref.read(authProvider);
    final productController = TextEditingController(text: obs.productName);
    final priceController =
        TextEditingController(text: obs.price.toStringAsFixed(0));
    final unitController = TextEditingController(text: obs.unit);
    final brandController = TextEditingController(text: obs.brandOrGrade ?? '');
    final notesController = TextEditingController(text: obs.notes ?? '');
    final categories = ref.read(categoriesProvider).map((c) => c.name).toList();
    if (categories.isEmpty) {
      categories.addAll(['Food', 'Electronics', 'Pharmacy', 'Others']);
    }
    String selectedCategory = categories.contains(obs.category)
        ? obs.category
        : (categories.isNotEmpty ? categories.first : 'Food');
    bool inStock = obs.inStock;
    String? modalErrorMessage;
    bool isGeneratingDescription = false;

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
            final parsedPrice =
                double.tryParse(priceController.text.trim()) ?? 0.0;
            final mult = CommodityComparisonService.calculateUnitMultiplier(
              unitController.text.trim(),
              commodityName: productController.text.trim(),
            );
            final previewStandardized =
                mult > 0 ? (parsedPrice / mult) : parsedPrice;
            final baseUnit = CommodityComparisonService.resolveBaseUnit(
              unitController.text.trim(),
              commodityName: productController.text.trim(),
            );

            return SafeArea(
              top: false,
              child: Padding(
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
                            'Modify Price Listing',
                            style: TextStyle(
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
                      const Text(
                        'Commodity / Product Name *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: productController,
                        onChanged: (_) {
                          if (modalErrorMessage != null) {
                            setModalState(() => modalErrorMessage = null);
                          } else {
                            setModalState(() {});
                          }
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Category *',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedCategory = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Price (₦) *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: priceController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: InputDecoration(
                                    prefixText: '₦ ',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Unit *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: unitController,
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (parsedPrice > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate_outlined,
                                  size: 14, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 6),
                              Text(
                                'Normalized unit price: ₦${previewStandardized.toStringAsFixed(0)} / $baseUnit',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Brand (Optional)',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: brandController,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('In Stock',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Switch(
                                value: inStock,
                                activeThumbColor: AppColors.primary,
                                onChanged: (val) =>
                                    setModalState(() => inStock = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Notes / Description',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          TextButton.icon(
                            key: const ValueKey('btn_ai_generate_description_edit'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                            ),
                            icon: isGeneratingDescription
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF673AB7),
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome,
                                    size: 14, color: Color(0xFF673AB7)),
                            label: Text(
                              isGeneratingDescription
                                  ? 'Generating...'
                                  : 'AI Generate Description',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF673AB7),
                              ),
                            ),
                            onPressed: isGeneratingDescription
                                ? null
                                : () async {
                                    final prodName = productController.text.trim();
                                    if (prodName.isEmpty) {
                                      setModalState(() {
                                        modalErrorMessage =
                                            'Please enter a Commodity / Product Name first so AI has context to generate the description.';
                                      });
                                      return;
                                    }
                                    if (selectedCategory.trim().isEmpty) {
                                      setModalState(() {
                                        modalErrorMessage =
                                            'Please select a Category first so AI has context to generate the description.';
                                      });
                                      return;
                                    }

                                    setModalState(() {
                                      modalErrorMessage = null;
                                      isGeneratingDescription = true;
                                    });

                                    final desc = await const MetaAiService()
                                        .generateProductDescription(
                                      productName: prodName,
                                      category: selectedCategory,
                                      brand: brandController.text.trim().isNotEmpty
                                          ? brandController.text.trim()
                                          : null,
                                      unit: unitController.text.trim().isNotEmpty
                                          ? unitController.text.trim()
                                          : null,
                                      price: double.tryParse(priceController.text.trim()),
                                      currentNotes: notesController.text.trim().isNotEmpty
                                          ? notesController.text.trim()
                                          : null,
                                    );

                                    setModalState(() {
                                      isGeneratingDescription = false;
                                      notesController.text = desc;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (modalErrorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          key: const ValueKey('dialog_error_banner_edit'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF9A9A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 16, color: Color(0xFFC62828)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalErrorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setModalState(() => modalErrorMessage = null),
                                child: const Icon(Icons.close, size: 14, color: Color(0xFFC62828)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final name = productController.text.trim();
                            final pStr = priceController.text.trim();
                            if (name.isEmpty) {
                              setModalState(() {
                                modalErrorMessage =
                                    'Product name is required. Please enter a commodity or product name.';
                              });
                              return;
                            }
                            if (pStr.isEmpty) {
                              setModalState(() {
                                modalErrorMessage =
                                    'Price is required. Please enter the listing price in ₦.';
                              });
                              return;
                            }
                            final price = double.tryParse(pStr) ?? 0.0;
                            if (price <= 0) {
                              setModalState(() {
                                modalErrorMessage =
                                    'Please enter a valid price amount greater than ₦0.';
                              });
                              return;
                            }
                            if (unitController.text.trim().isNotEmpty == false) {
                              setModalState(() {
                                modalErrorMessage =
                                    'Unit is required (e.g. 1kg, paint rubber, bag).';
                              });
                              return;
                            }

                            final unit = unitController.text.trim().isNotEmpty
                                ? unitController.text.trim()
                                : '1kg';
                            final finalBrand =
                                brandController.text.trim().isNotEmpty
                                    ? brandController.text.trim()
                                    : null;
                            final finalNotes =
                                notesController.text.trim().isNotEmpty
                                    ? notesController.text.trim()
                                    : null;

                            ref
                                .read(communityProvider.notifier)
                                .updateListingDetails(
                                  id: obs.id,
                                  productName: name,
                                  price: price,
                                  unit: unit,
                                  category: selectedCategory,
                                  brandOrGrade: finalBrand,
                                  notes: finalNotes ?? obs.notes,
                                  inStock: inStock,
                                  marketLocation: userSession.marketHub ?? obs.marketLocation,
                                  latitude: userSession.latitude ?? obs.latitude,
                                  longitude: userSession.longitude ?? obs.longitude,
                                );
                            Navigator.pop(bottomCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Listing "$name" updated successfully!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
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

  void _showEditBusinessProfile(BuildContext context, UserSession session) {
    final bizController =
        TextEditingController(text: session.businessName ?? '');
    final phoneController =
        TextEditingController(text: session.phone ?? '');
    final stallController =
        TextEditingController(text: session.stallLocation ?? session.marketHub ?? '');
    double? scannedLat = session.latitude;
    double? scannedLon = session.longitude;
    bool isScanningLocation = false;
    final userLoc = ref.read(locationProvider);
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
            return SafeArea(
              top: false,
              child: Padding(
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
                            'Update Store Profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                Navigator.pop(bottomSheetContext),
                          ),
                        ],
                      ),
                      if (session.isApprovedSeller) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: const Color(0xFFFFE082)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.shield_outlined,
                                  color: Color(0xFFE65100), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Market Credibility Verification: Changes to verified seller store details are submitted to administrators for verification before taking effect.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF795548),
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Business / Stall Name',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: bizController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Mama Bello Provisions & Grains',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Physical Store / Stall Address',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          if (scannedLat != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.badgeSuccessBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.check_circle_rounded,
                                      size: 12, color: AppColors.primary),
                                  SizedBox(width: 3),
                                  Text(
                                    'GPS Verified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: stallController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Shop 14, Commercial District, Abeokuta',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: isScanningLocation
                            ? null
                            : () async {
                                setModalState(() => isScanningLocation = true);
                                try {
                                  final activeLoc = ref.read(locationProvider);
                                  final result =
                                      await LocationService.scanDetailedStallLocation(
                                    fallback:
                                        activeLoc.isSet ? activeLoc : null,
                                  );
                                  if (result != null) {
                                    final prefix = stallController.text.trim();
                                    final detailed = result.formatStallAddress(
                                      prefix: prefix.isNotEmpty &&
                                              !prefix.contains('Lat:')
                                          ? prefix
                                          : null,
                                    );
                                    stallController.text = detailed;
                                    scannedLat = result.latitude;
                                    scannedLon = result.longitude;
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'GPS location locked: ${result.town}, ${result.city} (Verified)'),
                                          backgroundColor: AppColors.primary,
                                        ),
                                      );
                                    }
                                  }
                                } catch (_) {
                                } finally {
                                  setModalState(() => isScanningLocation = false);
                                }
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scannedLat != null
                                ? AppColors.badgeSuccessBg
                                : AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: scannedLat != null
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                scannedLat != null
                                    ? Icons.gps_fixed_rounded
                                    : Icons.my_location_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isScanningLocation
                                      ? 'Scanning GPS location...'
                                      : (scannedLat != null
                                          ? 'GPS Location Locked (Accurate Plain-Text Address)'
                                          : '📍 Scan Current GPS Location'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Channel Type',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: ['Local Market', 'SMB Store', 'Online Retailer']
                            .map((ch) {
                          final isSel = selectedChannel == ch;
                          return ChoiceChip(
                            label: Text(ch),
                            selected: isSel,
                            selectedColor: AppColors.badgeSuccessBg,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isSel
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() => selectedChannel = ch);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Phone / WhatsApp',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. +234 803 123 4567',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final chosenStall = stallController.text.trim();
                            final hubLocation = chosenStall.isNotEmpty
                                ? chosenStall
                                : (session.marketHub ?? (userLoc.isSet ? userLoc.displayLocation : 'Local Store'));
                            if (session.isApprovedSeller) {
                              ref
                                  .read(storeEditRequestsProvider.notifier)
                                  .submitRequest(
                                    seller: session,
                                    proposedBusinessName: bizController.text
                                            .trim()
                                            .isNotEmpty
                                        ? bizController.text.trim()
                                        : (session.businessName ?? ''),
                                    proposedMarketHub: hubLocation,
                                    proposedStallLocation: chosenStall.isNotEmpty
                                        ? chosenStall
                                        : session.stallLocation,
                                    proposedPhone: phoneController.text
                                            .trim()
                                            .isNotEmpty
                                        ? phoneController.text.trim()
                                        : (session.phone ?? ''),
                                    proposedSellerChannel: selectedChannel,
                                  );
                              Navigator.pop(bottomSheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Store modifications submitted for admin review!'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            } else {
                              ref
                                  .read(authProvider.notifier)
                                  .updateSellerProfile(
                                    businessName: bizController.text
                                            .trim()
                                            .isNotEmpty
                                        ? bizController.text.trim()
                                        : null,
                                    marketHub: hubLocation,
                                    stallLocation: chosenStall.isNotEmpty ? chosenStall : null,
                                    latitude: scannedLat,
                                    longitude: scannedLon,
                                    sellerChannel: selectedChannel,
                                    phone: phoneController.text
                                            .trim()
                                            .isNotEmpty
                                        ? phoneController.text.trim()
                                        : null,
                                  );
                              Navigator.pop(bottomSheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Store profile updated successfully!'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          },
                          child: Text(
                            session.isApprovedSeller
                                ? 'Submit Changes for Admin Review'
                                : 'Save Store Profile',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
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

  void _showApplyToBecomeSeller(BuildContext context, UserSession session) {
    final bizController =
        TextEditingController(text: session.businessName ?? '');
    final phoneController =
        TextEditingController(text: session.phone ?? '');
    final stallController =
        TextEditingController(text: session.stallLocation ?? '');
    double? scannedLat = session.latitude;
    double? scannedLon = session.longitude;
    bool isScanningLocation = false;
    final userLoc = ref.read(locationProvider);
    String selectedHub = session.marketHub ?? (userLoc.isSet ? userLoc.displayLocation : '');
    String selectedChannel = session.sellerChannel ?? 'Local Market';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeLoc = ref.watch(locationProvider);

            return SafeArea(
              top: false,
              child: Padding(
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
                            'Apply for Seller Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Submit your business details and physical stall GPS location for administrative verification.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.3),
                      ),
                      const SizedBox(height: 16),
                      const Text('Business Name *',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: bizController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Sunrise Farm Produce & Oils',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Phone / WhatsApp *',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. +234 803 123 4567',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Physical Stall Address / Line *',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: stallController,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Shop 14, Commercial District, Abeokuta',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: isScanningLocation
                            ? null
                            : () async {
                                setModalState(() => isScanningLocation = true);
                                try {
                                  final result =
                                      await LocationService.scanDetailedStallLocation(
                                    fallback:
                                        activeLoc.isSet ? activeLoc : null,
                                  );
                                  if (result != null) {
                                    final prefix =
                                        stallController.text.trim();
                                    final detailed =
                                        result.formatStallAddress(
                                      prefix: prefix.isNotEmpty &&
                                              !prefix.contains('Lat:')
                                          ? prefix
                                          : null,
                                    );
                                    stallController.text = detailed;
                                    scannedLat = result.latitude;
                                    scannedLon = result.longitude;
                                    selectedHub = result.closestHub.isNotEmpty
                                        ? result.closestHub
                                        : (result.town.isNotEmpty ? result.town : detailed);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Accurate GPS location locked: ${result.town}, ${result.city} (GPS Verified)'),
                                          backgroundColor: AppColors.primary,
                                        ),
                                      );
                                    }
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not acquire your GPS location. Please check location permissions or enter stall address manually.'),
                                          backgroundColor: AppColors.badgeErrorText,
                                        ),
                                      );
                                    }
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Location scan encountered an issue. Please enter your stall address manually.'),
                                        backgroundColor:
                                            AppColors.badgeErrorText,
                                      ),
                                    );
                                  }
                                } finally {
                                  setModalState(() => isScanningLocation = false);
                                }
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scannedLat != null
                                ? AppColors.badgeSuccessBg
                                : AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scannedLat != null
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (isScanningLocation)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary),
                                )
                              else
                                Icon(
                                  scannedLat != null
                                      ? Icons.gps_fixed_rounded
                                      : Icons.my_location_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isScanningLocation
                                          ? 'Scanning high-accuracy GPS location...'
                                          : (scannedLat != null
                                              ? 'Physical Stall GPS Locked & Verified'
                                              : 'Scan Precise Stall GPS Location'),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      scannedLat != null
                                          ? 'High-accuracy coordinates locked for buyer map navigation'
                                          : 'Auto-detect your stall address & GPS so buyers can navigate to you',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final bName = bizController.text.trim();
                            final phone = phoneController.text.trim();
                            final stall = stallController.text.trim();

                            if (bName.isEmpty ||
                                phone.isEmpty ||
                                stall.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please fill in all required fields including physical stall address.'),
                                  backgroundColor: AppColors.badgeErrorText,
                                ),
                              );
                              return;
                            }

                            final hubToSave = selectedHub.isNotEmpty
                                ? selectedHub
                                : (stall.isNotEmpty
                                    ? stall
                                    : (activeLoc.isSet ? activeLoc.displayLocation : 'Local Market'));

                            ref
                                .read(sellerApplicationsProvider.notifier)
                                .submitApplication(
                                  user: session,
                                  businessName: bName,
                                  marketHub: hubToSave,
                                  sellerChannel: selectedChannel,
                                  phone: phone,
                                  stallLocation: stall,
                                  latitude: scannedLat,
                                  longitude: scannedLon,
                                );

                            Navigator.pop(modalCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Seller verification application submitted successfully!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          child: const Text(
                            'Submit Application',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
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

  @override
  Widget build(BuildContext context) {
    final rawUserSession = ref.watch(authProvider);
    final applications = ref.watch(sellerApplicationsProvider);
    final observations = ref.watch(communityProvider);

    // Resolve matching seller application to guarantee approved state
    SellerApplication? matchingApp;
    for (final app in applications) {
      if (app.userId == rawUserSession.id ||
          (rawUserSession.email.isNotEmpty &&
              app.applicantEmail.trim().toLowerCase() ==
                  rawUserSession.email.trim().toLowerCase())) {
        matchingApp = app;
        break;
      }
    }

    final userSession = (matchingApp != null &&
            matchingApp.status == SellerApplicationStatus.approved)
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

    // Filter price listings published by this seller
    final myStoreName =
        (userSession.businessName ?? userSession.displayName).toLowerCase();
    final myObservations = observations.where((o) {
      final sName = o.sellerName.toLowerCase();
      return sName == myStoreName ||
          sName.contains(myStoreName) ||
          myStoreName.contains(sName);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Seller Hub & Store Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync Database',
            icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
            onPressed: () async {
              ref.read(communityProvider.notifier).fetchLive();
              ref.read(storeEditRequestsProvider.notifier).fetchLive();
              ref.read(sellerApplicationsProvider.notifier).fetchLive();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshed seller listings and profile from database!'),
                  duration: Duration(seconds: 1),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
          if (userSession.canModerate)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 14),
                label: const Text(
                  'SuperAdmin',
                  style: TextStyle(
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
        child: userSession.isApprovedSeller
            ? _buildApprovedSellerView(userSession, myObservations)
            : (userSession.isPendingSeller
                ? _buildPendingSellerView(userSession)
                : _buildCustomerApplyView(userSession)),
      ),
      floatingActionButton: userSession.isApprovedSeller
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _showAddObservationDialog(context, userSession),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Publish Price',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  void _showSellerReplySheet(
    BuildContext context,
    UserSession userSession,
    String conversationKey,
    List<TraderChatMessage> initialMessages,
  ) {
    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return Consumer(
          builder: (context, ref, _) {
            final chats = ref.watch(traderChatProvider);
            final messages = chats[conversationKey] ?? initialMessages;
            final commodityName = messages.isNotEmpty ? messages.first.commodityName : null;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.chat_rounded, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    commodityName != null ? 'Inquiry: $commodityName' : 'Customer Inquiry',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Text(
                                    'Live Trader Negotiation & Direct Messaging',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(modalCtx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: messages.isEmpty
                            ? const Center(
                                child: Text('No messages in this conversation yet.'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (ctx, i) {
                                  final msg = messages[i];
                                  final isFromSeller = msg.isTrader;

                                  return Align(
                                    alignment: isFromSeller
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isFromSeller
                                            ? AppColors.primary
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isFromSeller
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isFromSeller ? 'You (${msg.senderName})' : msg.senderName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isFromSeller
                                                  ? Colors.white70
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            msg.text,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              color: isFromSeller ? Colors.white : AppColors.textPrimary,
                                            ),
                                          ),
                                          if (msg.proposedPrice != null) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isFromSeller
                                                    ? Colors.white.withValues(alpha: 0.2)
                                                    : AppColors.primaryTint,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Offer: ₦${msg.proposedPrice!.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isFromSeller ? Colors.white : AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: replyController,
                                decoration: InputDecoration(
                                  hintText: 'Type your reply or counter-offer...',
                                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(color: AppColors.primary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              onPressed: () {
                                final text = replyController.text.trim();
                                if (text.isEmpty) return;
                                replyController.clear();
                                ref.read(traderChatProvider.notifier).sendTraderReply(
                                      traderName: userSession.businessName ?? userSession.displayName,
                                      replyText: text,
                                      commodityName: commodityName,
                                    );
                              },
                            ),
                          ],
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

  Widget _buildApprovedSellerView(
      UserSession userSession, List<PriceObservation> myObservations) {
    final allChats = ref.watch(traderChatProvider);
    final myStoreName = (userSession.businessName ?? userSession.displayName).toLowerCase().trim();
    final storeInquiries = allChats.entries.where((e) {
      final key = e.key.toLowerCase().trim();
      return key == myStoreName || key.contains(myStoreName) || myStoreName.contains(key);
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Store Details Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.badgeSuccessBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.verified_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userSession.businessName ??
                                    '${userSession.displayName}\'s Store',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'Verified Physical Merchant',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showEditBusinessProfile(context, userSession),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.divider),
              Row(
                children: [
                  const Text('Market Hub: ',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Expanded(
                    child: Text(
                      userSession.marketHub ?? (userSession.stallLocation ?? 'Local Store'),
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  const Text('Channel: ',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text(
                    userSession.sellerChannel ?? 'Local Market',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ],
              ),
              if (userSession.stallLocation != null &&
                  userSession.stallLocation!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stall Location: ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Expanded(
                      child: Text(
                        userSession.stallLocation!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ],
              if (userSession.phone != null &&
                  userSession.phone!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('Contact: ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      userSession.phone!,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
              if (userSession.hasPendingStoreEdit) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions_rounded,
                          color: Color(0xFFE65100), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userSession.pendingStoreEditSummary != null
                              ? 'Store Edit Pending Verification: ${userSession.pendingStoreEditSummary!}'
                              : 'Store Edit Pending Admin Verification',
                          style: const TextStyle(
                            fontSize: 11.5,
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
        const SizedBox(height: 16),

        // Quick Stats
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Published Quotes',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${myObservations.length}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trust Standing',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.shield_rounded,
                            color: Color(0xFF2E7D32), size: 18),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text('100% Verified',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Customer Inquiries & Live Chat Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Customer Inquiries (${storeInquiries.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (storeInquiries.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.badgeSuccessBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Live Supabase Synced',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (storeInquiries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.mark_chat_read_outlined,
                          color: AppColors.textTertiary, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No customer messages yet. Price inquiries and direct buyer negotiations sent to your stall will appear here.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: storeInquiries.map((entry) {
                    final lastMsg = entry.value.isNotEmpty ? entry.value.last : null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryTint,
                            child: Icon(Icons.person, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      lastMsg?.senderName ?? 'Customer',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    if (lastMsg?.commodityName != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardBorder,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          lastMsg!.commodityName!,
                                          style: const TextStyle(
                                              fontSize: 9.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lastMsg?.text ?? 'New conversation',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showSellerReplySheet(
                                context, userSession, entry.key, entry.value),
                            child: const Text('Reply',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // My Store Price Listings Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'My Commodity Listings (${myObservations.length})',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () =>
                  _showAddObservationDialog(context, userSession),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Add Listing',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (myObservations.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 42, color: AppColors.textTertiary),
                const SizedBox(height: 10),
                const Text(
                  'No Commodity Listings Yet',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Publish verified prices for commodities in your store so shoppers can discover and navigate directly to your stall.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showAddObservationDialog(context, userSession),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Publish First Price Listing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          )
        else
          ...myObservations.map((obs) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommodityImageWidget(
                        commodityName: obs.productName,
                        imageUrl: obs.imageUrl,
                        size: 48,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    obs.productName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.badgeSuccessBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    obs.category,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${obs.formattedPrice} / ${obs.unit}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            if (obs.brandOrGrade != null &&
                                obs.brandOrGrade!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Brand: ${obs.brandOrGrade}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 1-Tap In Stock / Out of Stock switch/pill
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          ref
                              .read(communityProvider.notifier)
                              .toggleListingStock(obs.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${obs.productName} marked as ${!obs.inStock ? "In Stock" : "Out of Stock"}',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: obs.inStock
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: obs.inStock
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFFE57373),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                obs.inStock
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 14,
                                color: obs.inStock
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                obs.inStock
                                    ? 'In Stock'
                                    : 'Out of Stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: obs.inStock
                                      ? const Color(0xFF1B5E20)
                                      : const Color(0xFFB71C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Edit button
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.primary),
                        tooltip: 'Modify Listing',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _showEditObservationDialog(context, obs),
                      ),
                      // Delete button
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.badgeErrorText),
                        tooltip: 'Delete Listing',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _confirmDeleteObservation(context, obs),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPendingSellerView(UserSession userSession) {
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
                  Icon(Icons.pending_actions_rounded,
                      color: Color(0xFFE65100), size: 26),
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
                'Your verification application for "${userSession.businessName ?? "Your Store"}" at ${userSession.marketHub ?? (userSession.stallLocation ?? "your registered market")} has been submitted.\n\nMarket hub administrators review physical stall location and seller contact before granting price publication permissions.',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF795548), height: 1.4),
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
                    Text(
                        'Store: ${userSession.businessName ?? "Not specified"}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                        'Market Hub: ${userSession.marketHub ?? (userSession.stallLocation ?? "Your Market")}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                        'Channel: ${userSession.sellerChannel ?? "Local Market"}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    if (userSession.phone != null) ...[
                      const SizedBox(height: 4),
                      Text('Contact: ${userSession.phone!}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
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

  Widget _buildCustomerApplyView(UserSession userSession) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (userSession.isRejectedSeller) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF9A9A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFC62828), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Seller Application Not Approved',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC62828),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your previous verification request was not approved. You can review your stall location, market hub, and contact details, and reapply below.',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF424242), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 24),
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
                style:
                    TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _showApplyToBecomeSeller(context, userSession),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.assignment_turned_in_rounded,
                      size: 18),
                  label: Text(
                    userSession.isRejectedSeller
                        ? 'Update Details & Reapply'
                        : 'Apply to Become a Verified Seller',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

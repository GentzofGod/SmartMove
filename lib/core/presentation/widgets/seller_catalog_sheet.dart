import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../models/price_observation.dart';
import '../../models/seller_application.dart';
import 'commodity_image_widget.dart';
import '../../../features/messages/presentation/chat_thread_screen.dart';

class SellerCatalogSheet extends ConsumerStatefulWidget {
  final String sellerName;
  final String? currentCommodityName;
  final String? initialMarketLocation;

  const SellerCatalogSheet({
    super.key,
    required this.sellerName,
    this.currentCommodityName,
    this.initialMarketLocation,
  });

  static Future<void> show(
    BuildContext context, {
    required String sellerName,
    String? currentCommodityName,
    String? initialMarketLocation,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SellerCatalogSheet(
        sellerName: sellerName,
        currentCommodityName: currentCommodityName,
        initialMarketLocation: initialMarketLocation,
      ),
    );
  }

  @override
  ConsumerState<SellerCatalogSheet> createState() => _SellerCatalogSheetState();
}

class _SellerCatalogSheetState extends ConsumerState<SellerCatalogSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone, String stallName) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final msg = Uri.encodeComponent(
      'Hello $stallName, I found your store catalog on SmartMove and would like to inquire about your listings.',
    );
    final uri = Uri.parse('https://wa.me/$clean?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _startChatForProduct(PriceObservation obs) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversationKey: obs.sellerName,
          initialPartnerName: obs.sellerName,
          initialCommodityName: obs.productName,
          initialPrice: obs.price,
          initialUnit: obs.unit,
          outletLocation: obs.marketLocation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allObservations = ref.watch(communityProvider);
    final allApplications = ref.watch(sellerApplicationsProvider);

    final cleanSeller = widget.sellerName.trim().toLowerCase();

    // Match all listings by this seller
    final sellerObservations = allObservations.where((obs) {
      final s = obs.sellerName.trim().toLowerCase();
      return s == cleanSeller || s.contains(cleanSeller) || cleanSeller.contains(s);
    }).toList();

    // Resolve seller application metadata if approved
    final app = allApplications.cast<SellerApplication?>().firstWhere(
          (a) =>
              a != null &&
              (a.businessName.trim().toLowerCase() == cleanSeller ||
                  cleanSeller.contains(a.businessName.trim().toLowerCase())),
          orElse: () => null,
        );

    final isVerified = (app?.status == SellerApplicationStatus.approved) ||
        (sellerObservations.isNotEmpty && sellerObservations.any((o) => o.isVerified));
    final resolvedLocation = app?.marketHub ??
        widget.initialMarketLocation ??
        (sellerObservations.isNotEmpty ? sellerObservations.first.marketLocation : 'Local Market Stall');
    final stallNumber = app?.stallLocation;
    final phone = app?.phone;

    // Filter by catalog search query
    final query = _searchController.text.trim().toLowerCase();
    final displayedList = sellerObservations.where((obs) {
      if (query.isEmpty) return true;
      return obs.productName.toLowerCase().contains(query) ||
          obs.category.toLowerCase().contains(query) ||
          (obs.brandOrGrade != null && obs.brandOrGrade!.toLowerCase().contains(query));
    }).toList();

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Store Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.sellerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.badgeSuccessBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified, size: 11, color: AppColors.badgeSuccessText),
                                  SizedBox(width: 2),
                                  Text(
                                    'Verified Seller',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.badgeSuccessText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              stallNumber != null && stallNumber.isNotEmpty
                                  ? '$resolvedLocation • Stall $stallNumber'
                                  : resolvedLocation,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${sellerObservations.length} ${sellerObservations.length == 1 ? "Product" : "Products"} in Seller Catalog',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blueDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (phone != null && phone.isNotEmpty) ...[
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.primary),
                        tooltip: 'Call Seller',
                        onPressed: () => _launchCall(phone),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(Icons.chat_outlined, size: 20, color: Color(0xFF25D366)),
                        tooltip: 'WhatsApp',
                        onPressed: () => _launchWhatsApp(phone, widget.sellerName),
                      ),
                    ],
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search bar within Catalog
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search within ${widget.sellerName}\'s catalog...',
                hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ),

          // Catalog Items List
          Expanded(
            child: displayedList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            sellerObservations.isEmpty
                                ? 'No public catalog items found for ${widget.sellerName}.'
                                : 'No matching catalog items for "${_searchController.text}".',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    itemCount: displayedList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final obs = displayedList[index];
                      final isCurrentInquiry = widget.currentCommodityName != null &&
                          obs.productName.trim().toLowerCase() ==
                              widget.currentCommodityName!.trim().toLowerCase();

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrentInquiry ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrentInquiry ? AppColors.primary : AppColors.cardBorder,
                            width: isCurrentInquiry ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image / Thumbnail
                            CommodityImageWidget(
                              commodityName: obs.productName,
                              size: 56,
                              borderRadius: 10,
                            ),
                            const SizedBox(width: 12),

                            // Product Details
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCurrentInquiry) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD1FAE5),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Current Chat',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF065F46),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        obs.formattedPrice,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: obs.inStock
                                              ? const Color(0xFFECFDF5)
                                              : const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          obs.inStock ? 'In Stock' : 'Out of Stock',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: obs.inStock
                                                ? const Color(0xFF059669)
                                                : AppColors.accentRed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (obs.notes != null && obs.notes!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      obs.notes!.trim(),
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Inquire / Chat Action Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCurrentInquiry ? const Color(0xFF059669) : AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.chat_bubble_outline, size: 13),
                              label: Text(
                                isCurrentInquiry ? 'In Chat' : 'Inquire',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                              onPressed: () => _startChatForProduct(obs),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

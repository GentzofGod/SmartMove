import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/item_acquisition_source.dart';
import '../../../../core/services/safe_outlet_launcher.dart';
import '../../../../core/state/app_state.dart';

class TraderNegotiationSheet extends ConsumerStatefulWidget {
  final ItemAcquisitionSource source;

  const TraderNegotiationSheet({
    super.key,
    required this.source,
  });

  static Future<void> show(BuildContext context, {required ItemAcquisitionSource source}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TraderNegotiationSheet(source: source),
    );
  }

  @override
  ConsumerState<TraderNegotiationSheet> createState() => _TraderNegotiationSheetState();
}

class _TraderNegotiationSheetState extends ConsumerState<TraderNegotiationSheet> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _quickNegotiationChips = [
    'Can you do a discount for bulk purchase?',
    'Is this Grade A premium quality?',
    'Can you hold this for pickup in 45 minutes?',
    'Do you deliver around this area?',
    'Is the price negotiable for cash on pickup?',
  ];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text, {double? proposedPrice}) {
    if (text.trim().isEmpty) return;
    final traderKey = widget.source.outletName;
    ref.read(traderChatProvider.notifier).sendCustomerMessage(
          traderName: traderKey,
          commodityName: widget.source.commodityName,
          quantity: widget.source.quantity,
          unit: widget.source.unit,
          listedPrice: widget.source.unitPrice,
          messageText: text.trim(),
          proposedPrice: proposedPrice,
        );
    _msgController.clear();
    _scrollToBottom();
  }

  void _showMakeOfferDialog() {
    final offerCtrl = TextEditingController(
      text: (widget.source.totalCost * 0.9).toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.handshake_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Make Counter-Offer',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Listed Total: ₦${widget.source.totalCost.toStringAsFixed(0)} (${widget.source.quantity % 1 == 0 ? widget.source.quantity.toInt() : widget.source.quantity} ${widget.source.unit} of ${widget.source.commodityName})',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: offerCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Your Proposed Total (₦)',
                prefixText: '₦ ',
                isDense: true,
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final val = double.tryParse(offerCtrl.text.replaceAll(',', '').trim());
              Navigator.pop(dialogCtx);
              if (val != null && val > 0) {
                final qtyStr = widget.source.quantity % 1 == 0
                    ? widget.source.quantity.toInt().toString()
                    : widget.source.quantity.toString();
                _sendMessage(
                  'I would like to offer ₦${val.toStringAsFixed(0)} for $qtyStr ${widget.source.unit} of ${widget.source.commodityName}. Can we agree on this price?',
                  proposedPrice: val,
                );
              }
            },
            child: const Text('Send Offer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final traderKey = widget.source.outletName;
    final chatState = ref.watch(traderChatProvider);
    final lowerItem = widget.source.commodityName.toLowerCase();
    final isHardware = lowerItem.contains('lathe') ||
        lowerItem.contains('spare') ||
        lowerItem.contains('tool') ||
        lowerItem.contains('part') ||
        lowerItem.contains('bearing') ||
        lowerItem.contains('machine') ||
        lowerItem.contains('hardware') ||
        lowerItem.contains('cable') ||
        lowerItem.contains('phone');
    final isAppliances = lowerItem.contains('cooker') ||
        lowerItem.contains('kettle') ||
        lowerItem.contains('iron') ||
        lowerItem.contains('blender') ||
        lowerItem.contains('microwave') ||
        lowerItem.contains('appliance') ||
        lowerItem.contains('electronics') ||
        lowerItem.contains('fan') ||
        lowerItem.contains('tv');
    final isProduce = lowerItem.contains('tomato') ||
        lowerItem.contains('pepper') ||
        lowerItem.contains('egg') ||
        lowerItem.contains('yam') ||
        lowerItem.contains('vegetable') ||
        lowerItem.contains('fruit');

    final welcomeText = isHardware
        ? 'Hello! Thank you for inquiring about ${widget.source.commodityName}. We have this item available in stock at ${widget.source.marketHubOrLocation}. Listed at ₦${widget.source.unitPrice.toStringAsFixed(0)} per ${widget.source.unit}. How can we assist you with this specification or order?'
        : (isAppliances
            ? 'Hello! Thank you for inquiring about ${widget.source.commodityName}. We have warrantied stock available at ${widget.source.marketHubOrLocation} (₦${widget.source.unitPrice.toStringAsFixed(0)} per ${widget.source.unit}). Feel free to ask questions or submit an offer.'
            : (isProduce
                ? 'Welcome! We have fresh, genuine harvest of ${widget.source.commodityName} at ${widget.source.marketHubOrLocation}. Listed at ₦${widget.source.unitPrice.toStringAsFixed(0)} per ${widget.source.unit}. How many ${widget.source.unit} are you looking to buy?'
                : 'Welcome! We have quality stock of ${widget.source.commodityName} available at ${widget.source.marketHubOrLocation} (₦${widget.source.unitPrice.toStringAsFixed(0)} per ${widget.source.unit}). Feel free to submit an offer or ask any questions.'));

    final messages = chatState[traderKey] ?? [
      TraderChatMessage(
        id: 'init-msg',
        senderName: widget.source.outletName,
        isTrader: true,
        text: welcomeText,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ];

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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

          // Trader Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
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
                              widget.source.outletName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.source.isPlatformRegisteredTrader) ...[
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
                                    'Verified Trader',
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
                      const SizedBox(height: 2),
                      Text(
                        '${widget.source.marketHubOrLocation} • ${widget.source.dynamicDistanceKm.toStringAsFixed(1)} km away',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Commodity Negotiation Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF1F8E9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Negotiating: ${widget.source.quantity % 1 == 0 ? widget.source.quantity.toInt() : widget.source.quantity} ${widget.source.unit} of ${widget.source.commodityName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Listed: ₦${widget.source.totalCost.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // SafeTrade Guarantee Sub-banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            color: AppColors.surface,
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, size: 13, color: AppColors.primary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SmartMove SafeTrade: Keep communications on-platform for verified price protection.',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Quick Negotiation Chips
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _quickNegotiationChips.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (ctx, idx) {
                final chipText = _quickNegotiationChips[idx];
                return ActionChip(
                  label: Text(chipText, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => _sendMessage(chipText),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (ctx, idx) {
                final msg = messages[idx];
                final isCustomer = !msg.isTrader;

                return Align(
                  alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCustomer ? AppColors.primary : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(isCustomer ? 14 : 2),
                        bottomRight: Radius.circular(isCustomer ? 2 : 14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: isCustomer ? Colors.white : AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isCustomer
                                ? Colors.white.withValues(alpha: 0.75)
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Input & Quick Negotiation Actions Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Make Offer CTA
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _showMakeOfferDialog,
                        icon: const Icon(Icons.handshake_outlined, size: 14, color: AppColors.primary),
                        label: const Text(
                          'Make Offer',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Direct WhatsApp / Call Fallback
                      if (SafeOutletLauncher.isValidPhoneNumber(widget.source.contactPhone)) ...[
                        IconButton(
                          icon: const Icon(Icons.phone_outlined, size: 18, color: AppColors.primary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Call Trader',
                          onPressed: () => SafeOutletLauncher.callSeller(
                            context,
                            phone: widget.source.contactPhone!,
                            sellerName: widget.source.outletName,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.badgeSuccessText),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'WhatsApp Inquiry',
                          onPressed: () => SafeOutletLauncher.openWhatsAppNegotiation(
                            context,
                            phone: widget.source.contactPhone!,
                            sellerName: widget.source.outletName,
                            commodityName: widget.source.commodityName,
                            quantity: widget.source.quantity,
                            unit: widget.source.unit,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Ask ${widget.source.outletName} a question...',
                            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: AppColors.cardBorder),
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (val) => _sendMessage(val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                        ),
                        onPressed: () => _sendMessage(_msgController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

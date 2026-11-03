import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/presentation/widgets/seller_catalog_sheet.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String conversationKey;
  final String? initialPartnerName;
  final String? initialCommodityName;
  final double? initialPrice;
  final String? initialUnit;
  final String? outletLocation;
  final double? outletDistance;

  const ChatThreadScreen({
    super.key,
    required this.conversationKey,
    this.initialPartnerName,
    this.initialCommodityName,
    this.initialPrice,
    this.initialUnit,
    this.outletLocation,
    this.outletDistance,
  });

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _buyerQuickChips = [
    'Is this item currently in stock?',
    'Can you do a discount for bulk purchase?',
    'Can I inspect the commodity before paying?',
    'Can you hold this for pickup today?',
    'Do you deliver around this market hub?',
    'Is the price negotiable for instant transfer?',
  ];

  static const List<String> _sellerQuickChips = [
    'Yes, available for immediate pickup at our stall',
    'Fresh stock arrived this morning, Grade A quality',
    'Our stall is open today until 6:00 PM',
    'We can arrange fast local delivery to your address',
    'Sorry, this item is currently sold out',
    'This is our final wholesale price, cannot go lower',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(traderChatProvider.notifier).loadMessages(widget.conversationKey);
      ref.read(traderChatProvider.notifier).markConversationAsRead(widget.conversationKey);
    });
  }

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
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _launchCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone, {String? defaultMsg}) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final msg = Uri.encodeComponent(
      defaultMsg ?? 'Hello, I am contacting you regarding your listing on SmartMove.',
    );
    final uri = Uri.parse('https://wa.me/$clean?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showGuestAuthPrompt(BuildContext context, {String actionName = 'chat and negotiate'}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sign In to Chat & Negotiate',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'You are currently exploring as a guest. To $actionName with verified traders and track inquiries across devices, please sign in or create a free account.',
          style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Browse as Guest'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.push('/auth');
            },
            child: const Text('Sign In / Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendMessage({String? customText, double? proposedPrice}) {
    final session = ref.read(authProvider);
    if (session.isGuest) {
      _showGuestAuthPrompt(context, actionName: 'send messages');
      return;
    }

    final text = (customText ?? _msgController.text).trim();
    if (text.isEmpty && proposedPrice == null) return;

    final myBusiness = session.businessName?.trim().toLowerCase();
    final myName = session.displayName.trim().toLowerCase();
    final isSellingThread = (myBusiness != null &&
            myBusiness.isNotEmpty &&
            (widget.conversationKey.toLowerCase().contains(myBusiness) ||
                myBusiness.contains(widget.conversationKey.toLowerCase()))) ||
        (session.isSeller &&
            myName.isNotEmpty &&
            (widget.conversationKey.toLowerCase().contains(myName) ||
                myName.contains(widget.conversationKey.toLowerCase())));

    final chats = ref.read(traderChatProvider);
    final currentList = chats[widget.conversationKey] ?? [];

    // Resolve commodity name and unit
    String commName = widget.initialCommodityName ?? 'Commodity';
    String unit = widget.initialUnit ?? 'unit';
    double price = widget.initialPrice ?? 0;
    for (final m in currentList.reversed) {
      if (m.commodityName != null && m.commodityName!.isNotEmpty) {
        commName = m.commodityName!;
        unit = m.unit ?? unit;
        price = m.unitPrice ?? price;
        break;
      }
    }

    if (commName == 'Commodity') {
      try {
        final observations = ref.read(communityProvider);
        final match = observations.cast<PriceObservation?>().firstWhere(
              (o) => o != null && o.sellerName.toLowerCase() == widget.conversationKey.toLowerCase(),
              orElse: () => null,
            );
        if (match != null) {
          commName = match.productName;
          unit = match.unit;
          price = match.price;
        }
      } catch (_) {}
    }

    if (isSellingThread) {
      ref.read(traderChatProvider.notifier).sendTraderReply(
            traderName: session.businessName ?? session.displayName,
            replyText: text.isNotEmpty ? text : 'Offer counter-proposal: ₦${proposedPrice?.toStringAsFixed(0)}',
            commodityName: commName,
            proposedPrice: proposedPrice,
          );
    } else {
      ref.read(traderChatProvider.notifier).sendCustomerMessage(
            traderName: widget.conversationKey,
            commodityName: commName,
            quantity: 1,
            unit: unit,
            listedPrice: price,
            messageText: text.isNotEmpty ? text : 'Offer proposed: ₦${proposedPrice?.toStringAsFixed(0)}',
            proposedPrice: proposedPrice,
            outletLocation: widget.outletLocation,
            outletDistance: widget.outletDistance,
          );
    }

    if (customText == null) {
      _msgController.clear();
    }
    _scrollToBottom();
  }

  void _showMakeOfferDialog(double basePrice, String commodityName, String unit) {
    final session = ref.read(authProvider);
    if (session.isGuest) {
      _showGuestAuthPrompt(context, actionName: 'make price offers');
      return;
    }

    final initialSuggestion = basePrice > 0 ? (basePrice * 0.9).toStringAsFixed(0) : '';
    final offerCtrl = TextEditingController(text: initialSuggestion);

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
              'Item: $commodityName ($unit)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            if (basePrice > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Listed Price: ₦${basePrice.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: offerCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Your Proposed Price (₦)',
                prefixText: '₦ ',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = double.tryParse(offerCtrl.text.replaceAll(',', '').trim());
              Navigator.pop(dialogCtx);
              if (val != null && val > 0) {
                _sendMessage(
                  customText:
                      'I would like to offer ₦${val.toStringAsFixed(0)} for $commodityName ($unit). Can we agree on this price?',
                  proposedPrice: val,
                );
              }
            },
            child: const Text('Send Offer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCounterOfferDialog({
    required double basePrice,
    required double currentOffer,
    required String commodityName,
    required String unit,
    required bool isSellerCountering,
  }) {
    final session = ref.read(authProvider);
    if (session.isGuest) {
      _showGuestAuthPrompt(context, actionName: 'counter price offers');
      return;
    }

    final defaultSuggestion = isSellerCountering
        ? (basePrice > currentOffer
            ? ((basePrice + currentOffer) / 2).roundToDouble().toStringAsFixed(0)
            : basePrice.toStringAsFixed(0))
        : (currentOffer > 0 ? (currentOffer * 0.95).roundToDouble().toStringAsFixed(0) : '');
    final offerCtrl = TextEditingController(text: defaultSuggestion);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isSellerCountering ? Icons.storefront_rounded : Icons.handshake_outlined,
              color: isSellerCountering ? const Color(0xFFD97706) : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isSellerCountering ? 'Propose Counter-Price' : 'Submit Counter-Offer',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commodity: $commodityName ($unit)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            if (basePrice > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Listed Price: ₦${basePrice.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            if (currentOffer > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Current Proposed Offer: ₦${currentOffer.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: offerCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: isSellerCountering ? 'Your Merchant Counter-Price (₦)' : 'Your Proposed Offer (₦)',
                prefixText: '₦ ',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: isSellerCountering ? const Color(0xFFD97706) : AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = double.tryParse(offerCtrl.text.replaceAll(',', '').trim());
              Navigator.pop(dialogCtx);
              if (val != null && val > 0) {
                if (isSellerCountering) {
                  _sendMessage(
                    customText:
                        'I can offer ₦${val.toStringAsFixed(0)} for $commodityName ($unit). Would this work for you?',
                    proposedPrice: val,
                  );
                } else {
                  _sendMessage(
                    customText:
                        'I would like to offer ₦${val.toStringAsFixed(0)} for $commodityName ($unit). Can we agree on this price?',
                    proposedPrice: val,
                  );
                }
              }
            },
            child: Text(
              isSellerCountering ? 'Send Counter-Price' : 'Send Offer',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatMap = ref.watch(traderChatProvider);
    final messages = chatMap[widget.conversationKey] ?? <TraderChatMessage>[];
    final session = ref.watch(authProvider);

    final myBusiness = session.businessName?.trim().toLowerCase();
    final myName = session.displayName.trim().toLowerCase();
    final isSellingThread = (myBusiness != null &&
            myBusiness.isNotEmpty &&
            (widget.conversationKey.toLowerCase().contains(myBusiness) ||
                myBusiness.contains(widget.conversationKey.toLowerCase()))) ||
        (session.isSeller &&
            myName.isNotEmpty &&
            (widget.conversationKey.toLowerCase().contains(myName) ||
                myName.contains(widget.conversationKey.toLowerCase())));

    // Resolve partner details
    String partnerName = widget.initialPartnerName ?? widget.conversationKey;
    bool partnerIsTrader = !isSellingThread;

    if (isSellingThread) {
      final firstCust = messages.cast<TraderChatMessage?>().firstWhere(
            (m) => m != null && !m.isTrader,
            orElse: () => null,
          );
      if (firstCust != null) partnerName = firstCust.senderName;
    }

    // Resolve commodity metadata & latest proposed offer
    String? commodityName = widget.initialCommodityName;
    double? basePrice = widget.initialPrice;
    String unit = widget.initialUnit ?? 'unit';
    String? location = widget.outletLocation;
    double? distance = widget.outletDistance;
    double? latestOffer;

    for (final m in messages.reversed) {
      commodityName ??= m.commodityName;
      basePrice ??= m.unitPrice;
      if (m.unit != null && m.unit!.isNotEmpty) unit = m.unit!;
      location ??= m.outletLocation;
      distance ??= m.outletDistance;
      if (latestOffer == null && m.proposedPrice != null && m.proposedPrice! > 0) {
        latestOffer = m.proposedPrice;
      }
      if (commodityName != null && basePrice != null && latestOffer != null) break;
    }

    if (commodityName == null || commodityName.isEmpty) {
      try {
        final observations = ref.watch(communityProvider);
        final match = observations.cast<PriceObservation?>().firstWhere(
              (o) => o != null && o.sellerName.toLowerCase() == widget.conversationKey.toLowerCase(),
              orElse: () => null,
            );
        if (match != null) {
          commodityName = match.productName;
          basePrice ??= match.price;
          unit = match.unit;
          location ??= match.marketLocation;
        }
      } catch (_) {}
    }

    final hasCommodityContext = commodityName != null && commodityName.isNotEmpty;
    final quickChips = isSellingThread ? _sellerQuickChips : _buyerQuickChips;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: partnerIsTrader ? AppColors.primaryTint : const Color(0xFFE2E8F0),
              child: Icon(
                partnerIsTrader ? Icons.storefront_rounded : Icons.person_rounded,
                color: partnerIsTrader ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          partnerName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (partnerIsTrader) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 14, color: AppColors.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    partnerIsTrader
                        ? (location != null && location.isNotEmpty
                            ? '$location${(distance != null && distance > 0) ? " • ${distance.toStringAsFixed(1)}km" : ""}'
                            : 'Verified Market Stall')
                        : 'Customer Inquiry',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (partnerIsTrader) ...[
            IconButton(
              icon: const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 21),
              tooltip: 'Check Seller Catalog',
              onPressed: () => SellerCatalogSheet.show(
                context,
                sellerName: partnerName,
                currentCommodityName: commodityName,
                initialMarketLocation: location,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 21),
              tooltip: 'Call Trader',
              onPressed: () => _launchCall('08000000000'),
            ),
            IconButton(
              icon: const Icon(Icons.chat_outlined, color: AppColors.primary, size: 21),
              tooltip: 'WhatsApp',
              onPressed: () => _launchWhatsApp(
                '08000000000',
                defaultMsg: 'Hello $partnerName, inquiring about $commodityName on SmartMove.',
              ),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Commodity Context Sticky Banner
          if (hasCommodityContext)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSellingThread ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
                border: Border(
                  bottom: BorderSide(
                    color: isSellingThread
                        ? const Color(0xFFFDE68A)
                        : AppColors.blue.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSellingThread ? Icons.store_mall_directory_outlined : Icons.shopping_bag_outlined,
                    color: isSellingThread ? const Color(0xFFD97706) : AppColors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSellingThread ? 'Customer Inquiry: $commodityName' : 'Negotiating: $commodityName',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (basePrice != null && basePrice > 0)
                          Text(
                            isSellingThread
                                ? 'Your Listed Price: ₦${basePrice.toStringAsFixed(0)} / $unit'
                                : 'Listed: ₦${basePrice.toStringAsFixed(0)} / $unit',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSellingThread ? const Color(0xFF92400E) : AppColors.blueDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // For Buyer: "Make Counter-Offer" button
                  // For Seller: NEVER a "Make Offer" button; if customer made offer, show it!
                  if (!isSellingThread) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.handshake_outlined, size: 14, color: AppColors.primary),
                      label: const Text('Make Offer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showMakeOfferDialog(
                        basePrice ?? 0,
                        commodityName ?? 'Commodity',
                        unit,
                      ),
                    ),
                  ] else if (latestOffer != null && latestOffer > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        'Offer: ₦${latestOffer.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: const EdgeInsets.all(4),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primary),
                    tooltip: 'Check Seller Catalog',
                    onPressed: () => SellerCatalogSheet.show(
                      context,
                      sellerName: partnerName,
                      currentCommodityName: commodityName,
                      initialMarketLocation: location,
                    ),
                  ),
                ],
              ),
            ),

          // Messages View
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyChatView(partnerName, commodityName, isSellingThread)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = isSellingThread ? msg.isTrader : !msg.isTrader;
                      return _buildMessageBubble(
                        msg: msg,
                        isMe: isMe,
                        isSellingThread: isSellingThread,
                        basePrice: basePrice,
                        commodityName: commodityName,
                        unit: unit,
                      );
                    },
                  ),
          ),

          // Guest Mode Warning Banner if unauthenticated
          if (session.isGuest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Guest Mode: Sign in to send messages and negotiate prices with verified traders.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/auth'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Quick Chips & Input Dock
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.8))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick suggestion chips (differentiated by Buyer vs Seller)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      scrollDirection: Axis.horizontal,
                      itemCount: quickChips.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final chipText = quickChips[i];
                        return InkWell(
                          onTap: () {
                            if (session.isGuest) {
                              _showGuestAuthPrompt(context, actionName: 'send quick inquiries');
                              return;
                            }
                            _sendMessage(customText: chipText);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSellingThread ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSellingThread ? const Color(0xFFFDE68A) : AppColors.cardBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              chipText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSellingThread ? const Color(0xFF92400E) : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Input row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      children: [
                        // For Buyer: Handshake "Make Offer" button
                        // For Seller: NO Handshake button (Sellers do not make offers on their own listings!)
                        if (!isSellingThread)
                          IconButton(
                            icon: const Icon(Icons.handshake_outlined, color: AppColors.primary, size: 22),
                            tooltip: 'Make Price Offer',
                            onPressed: () => _showMakeOfferDialog(
                              basePrice ?? 0,
                              commodityName ?? 'Commodity',
                              unit,
                            ),
                          ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _msgController,
                              textCapitalization: TextCapitalization.sentences,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: isSellingThread
                                    ? 'Reply to customer inquiry...'
                                    : 'Type message or negotiation inquiry...',
                                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            onPressed: () => _sendMessage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatView(String partner, String? commodity, bool isSelling) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isSelling ? const Color(0xFFFFFBEB) : AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelling ? Icons.storefront_rounded : Icons.chat_bubble_outline_rounded,
                color: isSelling ? const Color(0xFFD97706) : AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSelling ? 'Customer Inquiry from $partner' : 'Start Chat with $partner',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isSelling
                  ? (commodity != null
                      ? 'The customer is inquiring about $commodity. Tap a quick merchant reply or send a message.'
                      : 'Send a reply to assist this customer with their market inquiry.')
                  : (commodity != null
                      ? 'Ask questions about $commodity, confirm available quantity, or send a counter-offer.'
                      : 'Send a message or propose a negotiated price to start bargaining.'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (commodity != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelling ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelling ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (commodity.toLowerCase().contains('camry') ||
                              commodity.toLowerCase().contains('car') ||
                              commodity.toLowerCase().contains('corolla'))
                          ? Icons.directions_car_rounded
                          : Icons.shopping_bag_outlined,
                      size: 15,
                      color: isSelling ? const Color(0xFF92400E) : AppColors.blueDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Product Inquiry: $commodity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isSelling ? const Color(0xFF92400E) : AppColors.blueDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfferBox({
    required TraderChatMessage msg,
    required bool isMe,
    required bool isSellingThread,
    required double? basePrice,
    required String? commodityName,
    required String unit,
  }) {
    final proposedPrice = msg.proposedPrice ?? 0;
    final isOfferFromTrader = msg.isTrader;
    final isAccepted = msg.isOfferAccepted == true;
    final isDeclined = msg.isOfferDeclined == true;
    final isResolved = isAccepted || isDeclined;

    // Check if current user can act on this offer:
    // - If from customer (!isTrader), seller can act if isSellingThread and not yet resolved
    // - If from trader (isTrader), buyer can act if !isSellingThread and not yet resolved
    final canAct = !isResolved &&
        ((isSellingThread && !isOfferFromTrader) || (!isSellingThread && isOfferFromTrader));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isAccepted
            ? const Color(0xFFECFDF5)
            : (isDeclined
                ? const Color(0xFFFEF2F2)
                : (isMe ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFFEF3C7))),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAccepted
              ? const Color(0xFFA7F3D0)
              : (isDeclined
                  ? const Color(0xFFFECACA)
                  : (isMe ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFFDE68A))),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAccepted
                    ? Icons.check_circle_rounded
                    : (isDeclined
                        ? Icons.cancel_rounded
                        : (isOfferFromTrader ? Icons.storefront_rounded : Icons.handshake_rounded)),
                size: 18,
                color: isAccepted
                    ? const Color(0xFF059669)
                    : (isDeclined
                        ? AppColors.accentRed
                        : (isMe ? Colors.white : const Color(0xFFB45309))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAccepted
                          ? 'Offer Accepted & Agreed'
                          : (isDeclined
                              ? 'Offer Declined'
                              : (isOfferFromTrader
                                  ? (isSellingThread
                                      ? 'Your Merchant Counter-Price'
                                      : 'Trader Counter-Proposal')
                                  : (isSellingThread
                                      ? 'Customer Counter-Offer'
                                      : 'Your Proposed Counter-Offer'))),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isAccepted
                            ? const Color(0xFF065F46)
                            : (isDeclined
                                ? AppColors.accentRed
                                : (isMe ? Colors.white70 : const Color(0xFF92400E))),
                      ),
                    ),
                    Text(
                      '₦${proposedPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isAccepted
                            ? const Color(0xFF047857)
                            : (isDeclined
                                ? AppColors.accentRed
                                : (isMe ? Colors.white : const Color(0xFF78350F))),
                      ),
                    ),
                  ],
                ),
              ),
              if (isAccepted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Agreed ✓',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                )
              else if (isDeclined)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Declined ✕',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentRed,
                    ),
                  ),
                )
              else if (!canAct)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFFDE68A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Awaiting reply...',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isMe ? Colors.white : const Color(0xFF92400E),
                    ),
                  ),
                ),
            ],
          ),

          // Action Buttons for Recipient of Pending Offer
          if (canAct) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFFDE68A)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // 1. Accept Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check, size: 14),
                  label: Text(
                    'Accept (₦${proposedPrice.toStringAsFixed(0)})',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () {
                    ref.read(traderChatProvider.notifier).acceptOffer(
                          conversationKey: widget.conversationKey,
                          offerMessageId: msg.id,
                          acceptedPrice: proposedPrice,
                          commodityName: commodityName,
                          isSellerActing: isSellingThread,
                        );
                    _scrollToBottom();
                  },
                ),

                // 2. Decline Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: const BorderSide(color: AppColors.accentRed),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text(
                    'Decline',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    ref.read(traderChatProvider.notifier).declineOffer(
                          conversationKey: widget.conversationKey,
                          offerMessageId: msg.id,
                          declinedPrice: proposedPrice,
                          commodityName: commodityName,
                          isSellerActing: isSellingThread,
                        );
                    _scrollToBottom();
                  },
                ),

                // 3. Counter Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    side: const BorderSide(color: Color(0xFFD97706)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                  label: Text(
                    isSellingThread ? 'Counter' : 'Counter Again',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    _showCounterOfferDialog(
                      basePrice: basePrice ?? 0,
                      currentOffer: proposedPrice,
                      commodityName: commodityName ?? 'Commodity',
                      unit: unit,
                      isSellerCountering: isSellingThread,
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required TraderChatMessage msg,
    required bool isMe,
    required bool isSellingThread,
    required double? basePrice,
    required String? commodityName,
    required String unit,
  }) {
    final hasOffer = msg.proposedPrice != null && msg.proposedPrice! > 0;
    final timeStr =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 13,
                  backgroundColor: msg.isTrader ? AppColors.primaryTint : const Color(0xFFE2E8F0),
                  child: Icon(
                    msg.isTrader ? Icons.storefront : Icons.person,
                    size: 14,
                    color: msg.isTrader ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(3),
                      bottomRight: isMe ? const Radius.circular(3) : const Radius.circular(16),
                    ),
                    border: isMe ? null : Border.all(color: AppColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Explicit Product Context Tag on message
                      if (msg.commodityName != null && msg.commodityName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (msg.commodityName?.toLowerCase().contains('camry') ?? false) ||
                                          (msg.commodityName?.toLowerCase().contains('car') ?? false)
                                      ? Icons.directions_car_rounded
                                      : Icons.shopping_bag_outlined,
                                  size: 11,
                                  color: isMe ? Colors.white : AppColors.blueDark,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Inquiry: ${msg.commodityName}${msg.unitPrice != null && msg.unitPrice! > 0 ? " • ₦${msg.unitPrice!.toStringAsFixed(0)}${msg.unit != null ? "/${msg.unit}" : ""}" : ""}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isMe ? Colors.white : AppColors.blueDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Counter-Offer Box if attached to this message
                      if (hasOffer)
                        _buildOfferBox(
                          msg: msg,
                          isMe: isMe,
                          isSellingThread: isSellingThread,
                          basePrice: basePrice,
                          commodityName: commodityName,
                          unit: unit,
                        ),

                      Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textTertiary,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              msg.isRead ? Icons.done_all_rounded : Icons.check_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

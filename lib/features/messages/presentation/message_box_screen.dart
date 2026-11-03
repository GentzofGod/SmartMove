import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/presentation/widgets/seller_catalog_sheet.dart';
import 'chat_thread_screen.dart';

class MessageBoxScreen extends ConsumerStatefulWidget {
  final String? initialConversationKey;

  const MessageBoxScreen({
    super.key,
    this.initialConversationKey,
  });

  @override
  ConsumerState<MessageBoxScreen> createState() => _MessageBoxScreenState();
}

class _MessageBoxScreenState extends ConsumerState<MessageBoxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'All'; // 'All', 'Buying', 'Selling', 'Unread'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(authProvider);
      final sellerName = session.businessName ?? session.displayName;
      if (sellerName.isNotEmpty) {
        ref.read(traderChatProvider.notifier).syncSellerInquiries(sellerName);
      }
      if (widget.initialConversationKey != null && widget.initialConversationKey!.isNotEmpty) {
        _openThreadByKey(widget.initialConversationKey!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openThread(ConversationSummary conv) {
    ref.read(traderChatProvider.notifier).markConversationAsRead(conv.conversationKey);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversationKey: conv.conversationKey,
          initialPartnerName: conv.partnerName,
          initialCommodityName: conv.commodityName,
          initialPrice: conv.lastProposedPrice ?? conv.unitPrice ?? conv.lastMessage.unitPrice,
          initialUnit: conv.unit ?? conv.lastMessage.unit,
          outletLocation: conv.outletLocation,
          outletDistance: conv.outletDistance,
        ),
      ),
    );
  }

  void _openThreadByKey(String conversationKey) {
    ref.read(traderChatProvider.notifier).markConversationAsRead(conversationKey);
    final allConv = ref.read(activeConversationsProvider);
    final matching = allConv.cast<ConversationSummary?>().firstWhere(
          (c) => c?.conversationKey == conversationKey,
          orElse: () => null,
        );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversationKey: conversationKey,
          initialPartnerName: matching?.partnerName,
          initialCommodityName: matching?.commodityName,
          initialPrice: matching?.lastProposedPrice ?? matching?.unitPrice ?? matching?.lastMessage.unitPrice,
          initialUnit: matching?.unit ?? matching?.lastMessage.unit,
          outletLocation: matching?.outletLocation,
          outletDistance: matching?.outletDistance,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final allConversations = ref.watch(activeConversationsProvider);
    final totalUnread = ref.watch(unreadMessageCountProvider);
    final session = ref.watch(authProvider);
    final searchQuery = _searchController.text.trim().toLowerCase();

    // Filter conversations
    final filtered = allConversations.where((conv) {
      // Tab filter
      if (_activeFilter == 'Buying' && !conv.isTraderPartner) return false;
      if (_activeFilter == 'Selling' && conv.isTraderPartner) return false;
      if (_activeFilter == 'Unread' && conv.unreadCount == 0) return false;

      // Search query
      if (searchQuery.isNotEmpty) {
        final matchesPartner = conv.partnerName.toLowerCase().contains(searchQuery);
        final matchesKey = conv.conversationKey.toLowerCase().contains(searchQuery);
        final matchesCommodity =
            conv.commodityName != null && conv.commodityName!.toLowerCase().contains(searchQuery);
        final matchesText = conv.lastMessage.text.toLowerCase().contains(searchQuery);
        if (!matchesPartner && !matchesKey && !matchesCommodity && !matchesText) {
          return false;
        }
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Text(
              'Message Box',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalUnread new',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (allConversations.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (val) {
                if (val == 'read_all') {
                  for (final c in allConversations) {
                    if (c.unreadCount > 0) {
                      ref.read(traderChatProvider.notifier).markConversationAsRead(c.conversationKey);
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All conversations marked as read'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Mark all as read', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Guest Notice Card if unauthenticated
          if (session.isGuest)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_circle_outlined, color: AppColors.blueDark, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sign in to Message Sellers & Save History',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'You are exploring as a Guest. Sign in or create an account to negotiate prices with verified traders and track all conversations.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.login_rounded, size: 14),
                          label: const Text(
                            'Sign In / Register',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () => context.push('/auth'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search chats, sellers, or products...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'All (${allConversations.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Buying', 'Buying / Sellers'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Selling', 'Customer Inquiries'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Unread',
                        totalUnread > 0 ? 'Unread ($totalUnread)' : 'Unread',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Conversation List
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(_activeFilter, searchQuery.isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      return _buildConversationCard(conv);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _activeFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(ConversationSummary conv) {
    final hasUnread = conv.unreadCount > 0;
    final timeStr = _formatTimestamp(conv.lastTimestamp);
    final hasOffer = conv.lastProposedPrice != null && conv.lastProposedPrice! > 0;

    return Dismissible(
      key: ValueKey(conv.conversationKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.accentRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Conversation?'),
                content: Text(
                  'Are you sure you want to delete your chat history with "${conv.partnerName}"? This action cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        ref.read(traderChatProvider.notifier).deleteConversation(conv.conversationKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation with ${conv.partnerName} deleted'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openThread(conv),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasUnread ? AppColors.primary.withValues(alpha: 0.3) : AppColors.cardBorder,
                width: hasUnread ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with unread indicator dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InkWell(
                      onTap: conv.isTraderPartner
                          ? () => SellerCatalogSheet.show(
                                context,
                                sellerName: conv.partnerName,
                                currentCommodityName: conv.commodityName,
                                initialMarketLocation: conv.outletLocation,
                              )
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            conv.isTraderPartner ? AppColors.primaryTint : const Color(0xFFEFF6FF),
                        child: Icon(
                          conv.isTraderPartner ? Icons.storefront_rounded : Icons.person_rounded,
                          color: conv.isTraderPartner ? AppColors.primary : AppColors.blue,
                          size: 24,
                        ),
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.accentRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Partner Name & Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    conv.partnerName,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w700,
                                      color: hasUnread ? AppColors.textPrimary : AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (conv.isTraderPartner) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, size: 14, color: AppColors.primary),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                              color: hasUnread ? AppColors.primary : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Commodity product badge if present
                      if (conv.commodityName != null && conv.commodityName!.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 2, bottom: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: conv.isTraderPartner ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: conv.isTraderPartner
                                  ? const Color(0xFFBBF7D0)
                                  : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (conv.commodityName?.toLowerCase().contains('camry') ?? false) ||
                                        (conv.commodityName?.toLowerCase().contains('car') ?? false)
                                    ? Icons.directions_car_rounded
                                    : Icons.shopping_bag_outlined,
                                size: 12,
                                color: conv.isTraderPartner ? AppColors.primary : AppColors.blue,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  conv.commodityName!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: conv.isTraderPartner ? const Color(0xFF166534) : AppColors.blueDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (conv.unitPrice != null && conv.unitPrice! > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '₦${conv.unitPrice!.toStringAsFixed(0)}${conv.unit != null ? "/${conv.unit}" : ""}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: conv.isTraderPartner ? AppColors.primary : AppColors.blueDark,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Message snippet & Unread count
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conv.lastMessage.text,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                                color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasOffer) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '₦${conv.lastProposedPrice!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: const BoxDecoration(
                                color: AppColors.accentRed,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${conv.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String filter, bool isSearching) {
    if (isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
              SizedBox(height: 12),
              Text(
                'No conversations found',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              SizedBox(height: 4),
              Text(
                'Try searching with a different seller name or commodity keyword.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    String title = 'No Messages Yet';
    String desc =
        'Start bargaining with verified market traders or ask stall inquiries directly from product listings.';
    IconData icon = Icons.chat_bubble_outline_rounded;

    if (filter == 'Buying') {
      title = 'No Trader Inquiries';
      desc = 'You haven\'t started bargaining with any market sellers yet. Explore products to contact traders.';
      icon = Icons.storefront_outlined;
    } else if (filter == 'Selling') {
      title = 'No Customer Inquiries';
      desc = 'Customer inquiries and counter-offers regarding your store listings will appear here.';
      icon = Icons.support_agent_rounded;
    } else if (filter == 'Unread') {
      title = 'All Caught Up!';
      desc = 'You have read all messages in your inbox. No pending unread negotiations.';
      icon = Icons.mark_chat_read_outlined;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (ref.watch(authProvider).isGuest)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => context.push('/auth'),
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.storefront_outlined, size: 16, color: Colors.white),
                  label: const Text('Explore Market Products', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go('/products'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../messages/presentation/chat_thread_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  void _handleNotificationTap(BuildContext context, WidgetRef ref, NotificationItem item) {
    ref.read(notificationsProvider.notifier).markAsRead(item.id);

    if (item.type == 'Messages' && item.conversationKey != null && item.conversationKey!.isNotEmpty) {
      ref.read(traderChatProvider.notifier).markConversationAsRead(item.conversationKey!);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            conversationKey: item.conversationKey!,
          ),
        ),
      );
    } else if (item.route != null && item.route!.isNotEmpty) {
      context.push(item.route!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadMessagesCount = notifications
        .where((n) => n.type == 'Messages' && !n.isRead)
        .length;
    final totalUnread = notifications.where((n) => !n.isRead).length;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Row(
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 20,
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
                    '$totalUnread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (notifications.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (val) {
                  if (val == 'mark_read') {
                    ref.read(notificationsProvider.notifier).markAllAsRead();
                  } else if (val == 'open_messages') {
                    context.push('/messages');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'mark_read',
                    child: Row(
                      children: [
                        Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Mark all as read', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'open_messages',
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Open Message Box', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              const Tab(text: 'All'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Messages'),
                    if (unreadMessagesCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadMessagesCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Prices'),
              const Tab(text: 'Deals'),
              const Tab(text: 'System'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildNotificationList(context, ref, notifications),
            _buildNotificationList(context, ref, notifications, filterType: 'Messages'),
            _buildNotificationList(context, ref, notifications, filterType: 'Prices'),
            _buildNotificationList(context, ref, notifications, filterType: 'Deals'),
            _buildNotificationList(context, ref, notifications, filterType: 'System'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    WidgetRef ref,
    List<NotificationItem> all, {
    String? filterType,
  }) {
    final filtered = filterType == null
        ? all
        : all.where((n) => n.type == filterType).toList();

    if (filtered.isEmpty) {
      String emptyMsg = 'No notifications yet';
      IconData emptyIcon = Icons.notifications_none_rounded;
      if (filterType == 'Messages') {
        emptyMsg = 'No message notifications';
        emptyIcon = Icons.chat_bubble_outline_rounded;
      } else if (filterType == 'Prices') {
        emptyMsg = 'No price alerts';
        emptyIcon = Icons.trending_down_rounded;
      } else if (filterType == 'Deals') {
        emptyMsg = 'No promotional deals';
        emptyIcon = Icons.local_offer_outlined;
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(emptyIcon, size: 36, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Text(
                emptyMsg,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'When you receive chat updates or market price changes, they will appear here.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (filterType == 'Messages') ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  icon: const Icon(Icons.forum_outlined, size: 16, color: AppColors.primary),
                  label: const Text('Go to Message Box', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => context.push('/messages'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final n = filtered[index];
        final timeStr = _formatTimestamp(n.timestamp);

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _handleNotificationTap(context, ref, n),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !n.isRead ? AppColors.primary.withValues(alpha: 0.3) : AppColors.cardBorder,
                  width: !n.isRead ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: n.iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      n.iconData,
                      size: 20,
                      color: n.iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      n.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: !n.isRead ? FontWeight.w800 : FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!n.isRead) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accentRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: !n.isRead ? FontWeight.w700 : FontWeight.w500,
                                color: !n.isRead ? AppColors.primary : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          n.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: !n.isRead ? AppColors.textPrimary : AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        if (n.type == 'Messages') ...[
                          const SizedBox(height: 6),
                          Row(
                            children: const [
                              Icon(Icons.reply_rounded, size: 13, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Tap to open chat thread & reply',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
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
  }
}

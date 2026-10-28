import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Prices'),
              Tab(text: 'Errands'),
              Tab(text: 'System'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildNotificationList(context),
            _buildNotificationList(context, filterType: 'Prices'),
            _buildNotificationList(context, filterType: 'Errands'),
            _buildNotificationList(context, filterType: 'System'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context, {String? filterType}) {
    final notifications = [
      {
        'title': 'Price drop alert',
        'subtitle': 'Tomatoes at Market C dropped to ₦1,100',
        'time': '1h ago',
        'type': 'Prices',
        'icon': Icons.trending_down_rounded,
        'iconColor': AppColors.primary,
        'iconBg': AppColors.primaryTint,
      },
      {
        'title': 'Errand updated',
        'subtitle': 'Pharmacy Plus is now open for prescription pickups',
        'time': '3h ago',
        'type': 'Errands',
        'icon': Icons.check_circle_outline,
        'iconColor': AppColors.blue,
        'iconBg': AppColors.infoBg,
      },
      {
        'title': 'New price report',
        'subtitle': 'Rice (1kg) observation verified by Trader Mama Bello',
        'time': '4h ago',
        'type': 'Prices',
        'icon': Icons.verified_outlined,
        'iconColor': AppColors.primary,
        'iconBg': AppColors.primaryTint,
      },
      {
        'title': 'Plan reminder',
        'subtitle': 'Your scheduled errand run starts in 30 minutes',
        'time': '5h ago',
        'type': 'Errands',
        'icon': Icons.access_time_rounded,
        'iconColor': AppColors.amber,
        'iconBg': AppColors.warningBg,
      },
      {
        'title': 'Weekly summary',
        'subtitle': 'You saved ₦2,350 across your planned errands this week',
        'time': '1d ago',
        'type': 'System',
        'icon': Icons.savings_outlined,
        'iconColor': AppColors.primary,
        'iconBg': AppColors.primaryTint,
      },
    ];

    final filtered = filterType == null
        ? notifications
        : notifications.where((n) => n['type'] == filterType).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final n = filtered[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: n['iconBg'] as Color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  n['icon'] as IconData,
                  size: 20,
                  color: n['iconColor'] as Color,
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
                        Text(
                          n['title'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          n['time'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n['subtitle'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String type; // 'Messages', 'Prices', 'Deals', 'System'
  final bool isRead;
  final String? iconName;
  final int? iconColorHex;
  final int? iconBgHex;
  final String? route;
  final String? conversationKey;
  final Map<String, dynamic>? metadata;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.iconName,
    this.iconColorHex,
    this.iconBgHex,
    this.route,
    this.conversationKey,
    this.metadata,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    DateTime? timestamp,
    String? type,
    bool? isRead,
    String? iconName,
    int? iconColorHex,
    int? iconBgHex,
    String? route,
    String? conversationKey,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      iconName: iconName ?? this.iconName,
      iconColorHex: iconColorHex ?? this.iconColorHex,
      iconBgHex: iconBgHex ?? this.iconBgHex,
      route: route ?? this.route,
      conversationKey: conversationKey ?? this.conversationKey,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
        'type': type,
        'isRead': isRead,
        'iconName': iconName,
        'iconColorHex': iconColorHex,
        'iconBgHex': iconBgHex,
        'route': route,
        'conversationKey': conversationKey,
        'metadata': metadata,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime ts = DateTime.now();
    if (json['timestamp'] != null) {
      ts = DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
    }
    return NotificationItem(
      id: json['id']?.toString() ?? 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      timestamp: ts,
      type: json['type']?.toString() ?? 'System',
      isRead: json['isRead'] as bool? ?? false,
      iconName: json['iconName']?.toString(),
      iconColorHex: json['iconColorHex'] as int?,
      iconBgHex: json['iconBgHex'] as int?,
      route: json['route']?.toString(),
      conversationKey: json['conversationKey']?.toString(),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  IconData get iconData {
    if (iconName == 'chat') return Icons.chat_bubble_rounded;
    if (iconName == 'offer') return Icons.handshake_rounded;
    if (iconName == 'price_down') return Icons.trending_down_rounded;
    if (iconName == 'deal') return Icons.local_offer_outlined;
    if (iconName == 'verified') return Icons.verified_outlined;
    if (iconName == 'stock') return Icons.inventory_2_outlined;

    switch (type) {
      case 'Messages':
        return Icons.chat_bubble_rounded;
      case 'Prices':
        return Icons.trending_down_rounded;
      case 'Deals':
        return Icons.local_offer_outlined;
      case 'System':
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color get iconColor {
    if (iconColorHex != null) return Color(iconColorHex!);
    switch (type) {
      case 'Messages':
        return const Color(0xFF0D9488);
      case 'Prices':
        return const Color(0xFF16A34A);
      case 'Deals':
        return const Color(0xFF2563EB);
      case 'System':
      default:
        return const Color(0xFF4F46E5);
    }
  }

  Color get iconBg {
    if (iconBgHex != null) return Color(iconBgHex!);
    switch (type) {
      case 'Messages':
        return const Color(0xFFCCFBF1);
      case 'Prices':
        return const Color(0xFFDCFCE7);
      case 'Deals':
        return const Color(0xFFDBEAFE);
      case 'System':
      default:
        return const Color(0xFFE0E7FF);
    }
  }
}

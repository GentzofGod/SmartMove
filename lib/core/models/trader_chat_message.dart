class TraderChatMessage {
  final String id;
  final String senderName;
  final bool isTrader;
  final String text;
  final DateTime timestamp;
  final double? proposedPrice;
  final String? conversationKey;
  final String? commodityName;

  const TraderChatMessage({
    required this.id,
    required this.senderName,
    required this.isTrader,
    required this.text,
    required this.timestamp,
    this.proposedPrice,
    this.conversationKey,
    this.commodityName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderName': senderName,
        'isTrader': isTrader,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'proposedPrice': proposedPrice,
        'conversationKey': conversationKey,
        'commodityName': commodityName,
      };

  factory TraderChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime ts = DateTime.now();
    if (json['timestamp'] != null || json['created_at'] != null) {
      ts = DateTime.tryParse((json['timestamp'] ?? json['created_at']).toString()) ?? DateTime.now();
    }
    return TraderChatMessage(
      id: json['id']?.toString() ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
      senderName: (json['senderName'] ?? json['sender_name'])?.toString() ?? 'User',
      isTrader: (json['isTrader'] ?? json['is_trader']) as bool? ?? false,
      text: (json['text'] ?? json['message_text'])?.toString() ?? '',
      timestamp: ts,
      proposedPrice: ((json['proposedPrice'] ?? json['proposed_price']) as num?)?.toDouble(),
      conversationKey: (json['conversationKey'] ?? json['conversation_key'])?.toString(),
      commodityName: (json['commodityName'] ?? json['commodity_name'])?.toString(),
    );
  }
}


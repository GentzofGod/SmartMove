class TraderChatMessage {
  final String id;
  final String senderName;
  final bool isTrader;
  final String text;
  final DateTime timestamp;
  final double? proposedPrice;
  final String? conversationKey;
  final String? commodityName;
  final bool isRead;
  final String? senderId;
  final String? recipientName;
  final String? unit;
  final double? quantity;
  final double? unitPrice;
  final String? outletLocation;
  final double? outletDistance;
  final bool? isOfferAccepted;
  final bool? isOfferDeclined;

  const TraderChatMessage({
    required this.id,
    required this.senderName,
    required this.isTrader,
    required this.text,
    required this.timestamp,
    this.proposedPrice,
    this.conversationKey,
    this.commodityName,
    this.isRead = false,
    this.senderId,
    this.recipientName,
    this.unit,
    this.quantity,
    this.unitPrice,
    this.outletLocation,
    this.outletDistance,
    this.isOfferAccepted,
    this.isOfferDeclined,
  });

  TraderChatMessage copyWith({
    String? id,
    String? senderName,
    bool? isTrader,
    String? text,
    DateTime? timestamp,
    double? proposedPrice,
    String? conversationKey,
    String? commodityName,
    bool? isRead,
    String? senderId,
    String? recipientName,
    String? unit,
    double? quantity,
    double? unitPrice,
    String? outletLocation,
    double? outletDistance,
    bool? isOfferAccepted,
    bool? isOfferDeclined,
  }) {
    return TraderChatMessage(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      isTrader: isTrader ?? this.isTrader,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      conversationKey: conversationKey ?? this.conversationKey,
      commodityName: commodityName ?? this.commodityName,
      isRead: isRead ?? this.isRead,
      senderId: senderId ?? this.senderId,
      recipientName: recipientName ?? this.recipientName,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      outletLocation: outletLocation ?? this.outletLocation,
      outletDistance: outletDistance ?? this.outletDistance,
      isOfferAccepted: isOfferAccepted ?? this.isOfferAccepted,
      isOfferDeclined: isOfferDeclined ?? this.isOfferDeclined,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderName': senderName,
        'isTrader': isTrader,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'proposedPrice': proposedPrice,
        'conversationKey': conversationKey,
        'commodityName': commodityName,
        'isRead': isRead,
        'senderId': senderId,
        'recipientName': recipientName,
        'unit': unit,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'outletLocation': outletLocation,
        'outletDistance': outletDistance,
        'isOfferAccepted': isOfferAccepted,
        'isOfferDeclined': isOfferDeclined,
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
      isRead: (json['isRead'] ?? json['is_read']) as bool? ?? false,
      senderId: (json['senderId'] ?? json['sender_id'])?.toString(),
      recipientName: (json['recipientName'] ?? json['recipient_name'])?.toString(),
      unit: json['unit']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble(),
      unitPrice: ((json['unitPrice'] ?? json['unit_price']) as num?)?.toDouble(),
      outletLocation: (json['outletLocation'] ?? json['outlet_location'])?.toString(),
      outletDistance: (json['outletDistance'] ?? json['outlet_distance'] as num?)?.toDouble(),
      isOfferAccepted: (json['isOfferAccepted'] ?? json['is_offer_accepted']) as bool?,
      isOfferDeclined: (json['isOfferDeclined'] ?? json['is_offer_declined']) as bool?,
    );
  }
}

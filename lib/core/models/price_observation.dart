enum ObservationSource {
  simulatedDemo,
  communityReported,
  traderProvided,
  traderConfirmed,
  independentlyVerified,
  onlineGrounded,
}

extension ObservationSourceX on ObservationSource {
  String get displayLabel {
    switch (this) {
      case ObservationSource.simulatedDemo:
        return 'Demo data — simulated';
      case ObservationSource.communityReported:
        return 'Community reported';
      case ObservationSource.traderProvided:
        return 'Trader provided';
      case ObservationSource.traderConfirmed:
        return 'Trader confirmed';
      case ObservationSource.independentlyVerified:
        return 'Independently verified';
      case ObservationSource.onlineGrounded:
        return 'Online verified quote';
    }
  }

  bool get isSimulated => this == ObservationSource.simulatedDemo;
}

enum SellerChannel {
  onlineRetailer,
  localMarket,
  smbStore;

  String get displayName {
    switch (this) {
      case SellerChannel.onlineRetailer:
        return 'Online Retailer';
      case SellerChannel.localMarket:
        return 'Local Market';
      case SellerChannel.smbStore:
        return 'Neighborhood SMB';
    }
  }
}

class PriceObservation {
  final String id;
  final String productId;
  final String productName;
  final String sellerName;
  final String marketLocation;
  final double price;
  final String unit;
  final DateTime timestamp;
  final ObservationSource sourceType;
  final String submitterName;
  final String submitterRole; // 'Trader', 'Customer', 'System', 'Admin'
  final bool isVerified;
  final String? notes;
  final String channel; // 'Local Market', 'Online Retailer', 'SMB Store'
  final String? brandOrGrade;
  final bool inStock;
  final double? standardizedUnitPrice;
  final String baseUnit;

  const PriceObservation({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sellerName,
    required this.marketLocation,
    required this.price,
    required this.unit,
    required this.timestamp,
    required this.sourceType,
    required this.submitterName,
    this.submitterRole = 'Customer',
    this.isVerified = false,
    this.notes,
    this.channel = 'Local Market',
    this.brandOrGrade,
    this.inStock = true,
    this.standardizedUnitPrice,
    this.baseUnit = 'kg',
  });

  String get formattedPrice => '₦${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  SellerChannel get sellerChannel {
    final lower = channel.toLowerCase();
    if (lower.contains('online')) return SellerChannel.onlineRetailer;
    if (lower.contains('smb') || lower.contains('store') || lower.contains('mart') || lower.contains('grocer') || lower.contains('supermarket')) {
      return SellerChannel.smbStore;
    }
    return SellerChannel.localMarket;
  }

  PriceObservation copyWith({
    String? id,
    String? productId,
    String? productName,
    String? sellerName,
    String? marketLocation,
    double? price,
    String? unit,
    DateTime? timestamp,
    ObservationSource? sourceType,
    String? submitterName,
    String? submitterRole,
    bool? isVerified,
    String? notes,
    String? channel,
    String? brandOrGrade,
    bool? inStock,
    double? standardizedUnitPrice,
    String? baseUnit,
  }) {
    return PriceObservation(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sellerName: sellerName ?? this.sellerName,
      marketLocation: marketLocation ?? this.marketLocation,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      sourceType: sourceType ?? this.sourceType,
      submitterName: submitterName ?? this.submitterName,
      submitterRole: submitterRole ?? this.submitterRole,
      isVerified: isVerified ?? this.isVerified,
      notes: notes ?? this.notes,
      channel: channel ?? this.channel,
      brandOrGrade: brandOrGrade ?? this.brandOrGrade,
      inStock: inStock ?? this.inStock,
      standardizedUnitPrice:
          standardizedUnitPrice ?? this.standardizedUnitPrice,
      baseUnit: baseUnit ?? this.baseUnit,
    );
  }
}

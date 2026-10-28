enum ObservationSource {
  simulatedDemo,
  communityReported,
  traderProvided,
  traderConfirmed,
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
        return 'Verified by Trader';
    }
  }

  bool get isSimulated => this == ObservationSource.simulatedDemo;
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
  final String submitterRole; // 'Trader', 'Customer', 'System'
  final bool isVerified;
  final String? notes;

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
}

import 'product.dart';
import '../services/location_service.dart';

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
  final String category; // 'Groceries', 'Electronics', 'Pharmacy', 'Others'
  final String? imageUrl;
  final bool isFlaggedAnomaly;
  final String? anomalyReason;
  final double? latitude;
  final double? longitude;
  final String? submitterContact;

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
    this.category = 'Groceries',
    this.imageUrl,
    this.isFlaggedAnomaly = false,
    this.anomalyReason,
    this.latitude,
    this.longitude,
    this.submitterContact,
  });

  bool get isConfirmed =>
      isVerified &&
      (sourceType == ObservationSource.traderConfirmed ||
          sourceType == ObservationSource.independentlyVerified);

  bool get isOnline => sourceType == ObservationSource.onlineGrounded;

  bool get isSimulatedDemo => sourceType == ObservationSource.simulatedDemo;

  String get verificationBadgeLabel {
    if (isFlaggedAnomaly) return 'Anomaly Flagged';
    if (isConfirmed) return 'Verified Confirmed';
    if (isOnline) return 'Online Verified';
    if (isSimulatedDemo) return 'Demo Benchmark';
    return 'Community Reported';
  }

  String get formattedPrice => '₦${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';

  /// Converts this observation into a standard Product model for detail viewing & comparisons
  Product toProduct({GeoPoint? userLocation}) {
    final dist = LocationService.resolveDistanceKm(
      userLocation: userLocation,
      destLat: latitude,
      destLon: longitude,
      destLocationName: marketLocation.isNotEmpty ? marketLocation : sellerName,
    );
    return Product(
      id: productId.isNotEmpty ? productId : 'prod-$id',
      name: productName,
      category: category.isNotEmpty ? category : 'Food',
      standardUnit: unit,
      lowestPrice: price,
      bestSeller: '$sellerName ($marketLocation)',
      distanceKm: dist,
      updateTime: timeAgo,
      brandOrGrade: brandOrGrade,
      channel: channel,
      imageUrl: imageUrl,
      sourceType: sourceType,
      isCheapest: true,
      description: notes,
    );
  }

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
    String? category,
    String? imageUrl,
    bool? isFlaggedAnomaly,
    String? anomalyReason,
    double? latitude,
    double? longitude,
    String? submitterContact,
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
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isFlaggedAnomaly: isFlaggedAnomaly ?? this.isFlaggedAnomaly,
      anomalyReason: anomalyReason ?? this.anomalyReason,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      submitterContact: submitterContact ?? this.submitterContact,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'sellerName': sellerName,
        'marketLocation': marketLocation,
        'price': price,
        'unit': unit,
        'timestamp': timestamp.toIso8601String(),
        'sourceType': sourceType.name,
        'submitterName': submitterName,
        'submitterRole': submitterRole,
        'isVerified': isVerified,
        'notes': notes,
        'channel': channel,
        'brandOrGrade': brandOrGrade,
        'inStock': inStock,
        'standardizedUnitPrice': standardizedUnitPrice,
        'baseUnit': baseUnit,
        'category': category,
        'imageUrl': imageUrl,
        'isFlaggedAnomaly': isFlaggedAnomaly,
        'anomalyReason': anomalyReason,
        'latitude': latitude,
        'longitude': longitude,
        'submitterContact': submitterContact,
      };

  factory PriceObservation.fromJson(Map<String, dynamic> json) {
    ObservationSource source = ObservationSource.communityReported;
    final sourceVal = json['sourceType']?.toString() ?? json['source_type']?.toString();
    for (final s in ObservationSource.values) {
      if (s.name == sourceVal || s.toString() == sourceVal) {
        source = s;
        break;
      }
    }
    if (sourceVal == 'trader_confirmed') source = ObservationSource.traderConfirmed;
    if (sourceVal == 'trader_provided') source = ObservationSource.traderProvided;
    if (sourceVal == 'simulated_demo') source = ObservationSource.simulatedDemo;
    if (sourceVal == 'online_grounded') source = ObservationSource.onlineGrounded;

    DateTime ts = DateTime.now();
    if (json['timestamp'] != null || json['created_at'] != null) {
      ts = DateTime.tryParse((json['timestamp'] ?? json['created_at']).toString()) ?? DateTime.now();
    }

    return PriceObservation(
      id: json['id']?.toString() ?? 'obs-${DateTime.now().millisecondsSinceEpoch}',
      productId: (json['productId'] ?? json['product_id'])?.toString() ?? 'p-custom',
      productName: (json['productName'] ?? json['product_name'])?.toString() ?? '',
      sellerName: (json['sellerName'] ?? json['seller_name'])?.toString() ?? 'Local Vendor',
      marketLocation: (json['marketLocation'] ?? json['market_location'])?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? '1kg',
      timestamp: ts,
      sourceType: source,
      submitterName: (json['submitterName'] ?? json['submitter_name'])?.toString() ?? 'Community Member',
      submitterRole: (json['submitterRole'] ?? json['submitter_role'])?.toString() ?? 'Customer',
      isVerified: (json['isVerified'] ?? json['is_verified']) as bool? ?? false,
      notes: json['notes']?.toString(),
      channel: json['channel']?.toString() ?? 'Local Market',
      brandOrGrade: (json['brandOrGrade'] ?? json['brand_or_grade'])?.toString(),
      inStock: (json['inStock'] ?? json['in_stock']) as bool? ?? true,
      standardizedUnitPrice: ((json['standardizedUnitPrice'] ?? json['standardized_unit_price']) as num?)?.toDouble(),
      baseUnit: (json['baseUnit'] ?? json['base_unit'])?.toString() ?? 'kg',
      category: json['category']?.toString() ?? 'Groceries',
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString(),
      isFlaggedAnomaly: (json['isFlaggedAnomaly'] ?? json['is_flagged_anomaly']) as bool? ?? false,
      anomalyReason: (json['anomalyReason'] ?? json['anomaly_reason'])?.toString(),
      latitude: ((json['latitude'] ?? json['lat']) as num?)?.toDouble(),
      longitude: ((json['longitude'] ?? json['lng'] ?? json['lon']) as num?)?.toDouble(),
      submitterContact: (json['submitterContact'] ?? json['submitter_contact'] ?? json['phone'])?.toString(),
    );
  }
}

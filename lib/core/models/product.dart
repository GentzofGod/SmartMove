import 'price_observation.dart';

class Product {
  final String id;
  final String name;
  final String category; // 'Groceries', 'Electronics', 'Pharmacy', 'Others'
  final String? categoryId;
  final String standardUnit; // '1kg', '50kg', 'crate', '1L', '5L', 'basket'
  final double lowestPrice;
  final String bestSeller;
  final String? sellerId;
  final String? createdBy;
  final double distanceKm;
  final String updateTime;
  final double percentageChange; // e.g. +8.0, -5.0
  final bool isCheapest;
  final ObservationSource sourceType;
  final int observationCount;
  final String? description;
  final String? imageUrl;
  final String? brandOrGrade;
  final double? standardizedUnitPrice;
  final String baseUnit;
  final String channel;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    this.categoryId,
    required this.standardUnit,
    required this.lowestPrice,
    required this.bestSeller,
    this.sellerId,
    this.createdBy,
    required this.distanceKm,
    required this.updateTime,
    this.percentageChange = 0.0,
    this.isCheapest = false,
    this.sourceType = ObservationSource.traderConfirmed,
    this.observationCount = 3,
    this.description,
    this.imageUrl,
    this.brandOrGrade,
    this.standardizedUnitPrice,
    this.baseUnit = 'kg',
    this.channel = 'Local Market',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'categoryId': categoryId,
        'standardUnit': standardUnit,
        'lowestPrice': lowestPrice,
        'bestSeller': bestSeller,
        'sellerId': sellerId,
        'createdBy': createdBy,
        'distanceKm': distanceKm,
        'updateTime': updateTime,
        'percentageChange': percentageChange,
        'isCheapest': isCheapest,
        'sourceType': sourceType.name,
        'observationCount': observationCount,
        'description': description,
        'imageUrl': imageUrl,
        'brandOrGrade': brandOrGrade,
        'standardizedUnitPrice': standardizedUnitPrice,
        'baseUnit': baseUnit,
        'channel': channel,
      };

  Map<String, dynamic> toDbMap() => {
        'name': name,
        'category': category,
        'category_id': categoryId,
        'standard_unit': standardUnit,
        'lowest_price': lowestPrice,
        'best_seller_name': bestSeller,
        'seller_id': sellerId,
        'created_by': createdBy,
        'percentage_change': percentageChange,
        'is_cheapest': isCheapest,
        'source_type': () {
          switch (sourceType) {
            case ObservationSource.traderConfirmed:
              return 'trader_confirmed';
            case ObservationSource.traderProvided:
              return 'trader_provided';
            case ObservationSource.simulatedDemo:
              return 'simulated_demo';
            default:
              return 'community_reported';
          }
        }(),
        'observation_count': observationCount,
        'description': description,
        'image_url': imageUrl,
        'brand_or_grade': brandOrGrade,
        'standardized_unit_price': standardizedUnitPrice,
        'base_unit': baseUnit,
        'channel': channel,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    final srcStr = (json['sourceType'] ?? json['source_type'])?.toString() ?? '';
    final ObservationSource source;
    if (srcStr == 'trader_confirmed' || srcStr == 'traderConfirmed') {
      source = ObservationSource.traderConfirmed;
    } else if (srcStr == 'trader_provided' || srcStr == 'traderProvided') {
      source = ObservationSource.traderProvided;
    } else if (srcStr == 'simulated_demo' || srcStr == 'simulatedDemo') {
      source = ObservationSource.simulatedDemo;
    } else if (srcStr == 'online_grounded' || srcStr == 'onlineGrounded') {
      source = ObservationSource.onlineGrounded;
    } else {
      source = ObservationSource.communityReported;
    }

    return Product(
      id: json['id']?.toString() ?? 'p-unknown',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Groceries',
      categoryId: (json['categoryId'] ?? json['category_id'])?.toString(),
      standardUnit:
          (json['standardUnit'] ?? json['standard_unit'])?.toString() ?? '1kg',
      lowestPrice: ((json['lowestPrice'] ?? json['lowest_price']) as num?)?.toDouble() ?? 0.0,
      bestSeller: (json['bestSeller'] ?? json['best_seller_name'])?.toString() ?? 'Local Market',
      sellerId: (json['sellerId'] ?? json['seller_id'])?.toString(),
      createdBy: (json['createdBy'] ?? json['created_by'])?.toString(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 1.5,
      updateTime: json['updateTime']?.toString() ?? 'Updated recently',
      percentageChange:
          ((json['percentageChange'] ?? json['percentage_change']) as num?)?.toDouble() ?? 0.0,
      isCheapest: (json['isCheapest'] ?? json['is_cheapest']) as bool? ?? false,
      sourceType: source,
      observationCount:
          ((json['observationCount'] ?? json['observation_count']) as num?)?.toInt() ?? 1,
      description: json['description']?.toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString(),
      brandOrGrade: (json['brandOrGrade'] ?? json['brand_or_grade'])?.toString(),
      standardizedUnitPrice:
          ((json['standardizedUnitPrice'] ?? json['standardized_unit_price']) as num?)?.toDouble(),
      baseUnit: (json['baseUnit'] ?? json['base_unit'])?.toString() ?? 'kg',
      channel: json['channel']?.toString() ?? 'Local Market',
    );
  }

  String get formattedPrice => '₦${lowestPrice.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';

  String get formattedStandardizedPrice {
    final unitPrice = standardizedUnitPrice ?? lowestPrice;
    return '₦${unitPrice.toStringAsFixed(0)} / $baseUnit';
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? categoryId,
    String? standardUnit,
    double? lowestPrice,
    String? bestSeller,
    String? sellerId,
    String? createdBy,
    double? distanceKm,
    String? updateTime,
    double? percentageChange,
    bool? isCheapest,
    ObservationSource? sourceType,
    int? observationCount,
    String? description,
    String? imageUrl,
    String? brandOrGrade,
    double? standardizedUnitPrice,
    String? baseUnit,
    String? channel,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      standardUnit: standardUnit ?? this.standardUnit,
      lowestPrice: lowestPrice ?? this.lowestPrice,
      bestSeller: bestSeller ?? this.bestSeller,
      sellerId: sellerId ?? this.sellerId,
      createdBy: createdBy ?? this.createdBy,
      distanceKm: distanceKm ?? this.distanceKm,
      updateTime: updateTime ?? this.updateTime,
      percentageChange: percentageChange ?? this.percentageChange,
      isCheapest: isCheapest ?? this.isCheapest,
      sourceType: sourceType ?? this.sourceType,
      observationCount: observationCount ?? this.observationCount,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      brandOrGrade: brandOrGrade ?? this.brandOrGrade,
      standardizedUnitPrice:
          standardizedUnitPrice ?? this.standardizedUnitPrice,
      baseUnit: baseUnit ?? this.baseUnit,
      channel: channel ?? this.channel,
    );
  }
}

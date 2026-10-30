import 'price_observation.dart';

class Product {
  final String id;
  final String name;
  final String category; // 'Groceries', 'Electronics', 'Pharmacy', 'Others'
  final String standardUnit; // '1kg', '50kg', 'crate', '1L', '5L', 'basket'
  final double lowestPrice;
  final String bestSeller;
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
    required this.standardUnit,
    required this.lowestPrice,
    required this.bestSeller,
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
    String? standardUnit,
    double? lowestPrice,
    String? bestSeller,
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
      standardUnit: standardUnit ?? this.standardUnit,
      lowestPrice: lowestPrice ?? this.lowestPrice,
      bestSeller: bestSeller ?? this.bestSeller,
      distanceKm: distanceKm ?? this.distanceKm,
      updateTime: updateTime ?? this.updateTime,
      percentageChange: percentageChange ?? this.percentageChange,
      isCheapest: isCheapest ?? this.isCheapest,
      sourceType: sourceType ?? this.sourceType,
      observationCount: observationCount ?? this.observationCount,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      brandOrGrade: brandOrGrade ?? this.brandOrGrade,
      standardizedUnitPrice: standardizedUnitPrice ?? this.standardizedUnitPrice,
      baseUnit: baseUnit ?? this.baseUnit,
      channel: channel ?? this.channel,
    );
  }
}

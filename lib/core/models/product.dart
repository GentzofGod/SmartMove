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
  });

  String get formattedPrice => '₦${lowestPrice.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
}

enum CommodityPriority {
  high,
  medium,
  low;

  static const CommodityPriority essential = CommodityPriority.high;
  static const CommodityPriority flexible = CommodityPriority.medium;
}

/// Backwards-compatibility alias for priority
typedef ErrandPriority = CommodityPriority;

/// Represents a commodity or grocery product item in a comparison basket
class ShoppingItem {
  final String id;
  final String? productId;
  final String productName;
  final String? brandOrGrade;
  final double quantity;
  final String unit;
  final String? standardizedUnit;
  final double estimatedUnitPrice;
  final CommodityPriority priority;
  final String? specification;
  final String? preferredSellerType; // 'Local Market', 'Online Retailer', 'SMB Store', 'Any'
  final List<String> acceptableAlternatives;
  bool isChecked;

  ShoppingItem({
    required this.id,
    this.productId,
    required this.productName,
    this.brandOrGrade,
    required this.quantity,
    required this.unit,
    this.standardizedUnit,
    required this.estimatedUnitPrice,
    this.priority = CommodityPriority.medium,
    this.specification,
    this.preferredSellerType = 'Any',
    this.acceptableAlternatives = const [],
    this.isChecked = false,
  });

  double get totalEstimatedCost => quantity * estimatedUnitPrice;

  ShoppingItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? brandOrGrade,
    double? quantity,
    String? unit,
    String? standardizedUnit,
    double? estimatedUnitPrice,
    CommodityPriority? priority,
    String? specification,
    String? preferredSellerType,
    List<String>? acceptableAlternatives,
    bool? isChecked,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      brandOrGrade: brandOrGrade ?? this.brandOrGrade,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      standardizedUnit: standardizedUnit ?? this.standardizedUnit,
      estimatedUnitPrice: estimatedUnitPrice ?? this.estimatedUnitPrice,
      priority: priority ?? this.priority,
      specification: specification ?? this.specification,
      preferredSellerType: preferredSellerType ?? this.preferredSellerType,
      acceptableAlternatives: acceptableAlternatives ?? this.acceptableAlternatives,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

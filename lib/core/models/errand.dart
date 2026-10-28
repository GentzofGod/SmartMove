enum ErrandPriority { high, medium, low }

class ShoppingItem {
  final String id;
  final String productName;
  final double quantity;
  final String unit;
  final double estimatedUnitPrice;
  bool isChecked;

  ShoppingItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.estimatedUnitPrice,
    this.isChecked = false,
  });

  double get totalEstimatedCost => quantity * estimatedUnitPrice;

  ShoppingItem copyWith({
    String? id,
    String? productName,
    double? quantity,
    String? unit,
    double? estimatedUnitPrice,
    bool? isChecked,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedUnitPrice: estimatedUnitPrice ?? this.estimatedUnitPrice,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

class Errand {
  final String id;
  final String title;
  final String locationName;
  final String scheduledTime;
  final String? deadline; // e.g. "2:00 PM"
  final ErrandPriority priority;
  final String category; // 'groceries', 'pickup', 'pharmacy', 'utility', 'general'
  final List<ShoppingItem> shoppingItems;
  final int durationMinutes;
  final String? openingHours; // e.g. "8:00 AM - 6:00 PM"
  final String? constraintsNote;
  final int? maxStops;
  bool isCompleted;

  Errand({
    required this.id,
    required this.title,
    required this.locationName,
    required this.scheduledTime,
    this.deadline,
    required this.priority,
    required this.category,
    this.shoppingItems = const [],
    this.durationMinutes = 25,
    this.openingHours,
    this.constraintsNote,
    this.maxStops,
    this.isCompleted = false,
  });

  bool get isShopping => shoppingItems.isNotEmpty;

  double get totalShoppingCost =>
      shoppingItems.fold(0.0, (sum, item) => sum + item.totalEstimatedCost);

  Errand copyWith({
    String? id,
    String? title,
    String? locationName,
    String? scheduledTime,
    String? deadline,
    ErrandPriority? priority,
    String? category,
    List<ShoppingItem>? shoppingItems,
    int? durationMinutes,
    String? openingHours,
    String? constraintsNote,
    int? maxStops,
    bool? isCompleted,
  }) {
    return Errand(
      id: id ?? this.id,
      title: title ?? this.title,
      locationName: locationName ?? this.locationName,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      openingHours: openingHours ?? this.openingHours,
      constraintsNote: constraintsNote ?? this.constraintsNote,
      maxStops: maxStops ?? this.maxStops,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

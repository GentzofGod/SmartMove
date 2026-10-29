export 'commodity_item.dart';
import 'commodity_item.dart';

/// Legacy errand container preserved temporarily for backward compatibility.
/// All core workflows now use ShoppingItem / CommodityItem directly.
class Errand {
  final String id;
  final String title;
  final String locationName;
  final String scheduledTime;
  final String? deadline;
  final CommodityPriority priority;
  final String category;
  final List<ShoppingItem> shoppingItems;
  final int durationMinutes;
  final String? openingHours;
  final String? constraintsNote;
  final int? maxStops;
  bool isCompleted;

  Errand({
    required this.id,
    required this.title,
    required this.locationName,
    required this.scheduledTime,
    this.deadline,
    this.priority = CommodityPriority.flexible,
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
    CommodityPriority? priority,
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

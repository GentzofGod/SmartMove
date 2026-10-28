class ItineraryStop {
  final String id;
  final int stopNumber;
  final String title;
  final String subtitle;
  final String location;
  final double distanceKm;
  final int durationMinutes;
  final String timeWindow; // e.g. "9:20 AM - 10:10 AM"
  final String? badgeText; // e.g. "Best prices"
  final double estimatedCost;
  final List<String> taskItems;
  bool isCompleted;

  ItineraryStop({
    required this.id,
    required this.stopNumber,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.distanceKm,
    required this.durationMinutes,
    required this.timeWindow,
    this.badgeText,
    this.estimatedCost = 0.0,
    this.taskItems = const [],
    this.isCompleted = false,
  });

  ItineraryStop copyWith({
    String? id,
    int? stopNumber,
    String? title,
    String? subtitle,
    String? location,
    double? distanceKm,
    int? durationMinutes,
    String? timeWindow,
    String? badgeText,
    double? estimatedCost,
    List<String>? taskItems,
    bool? isCompleted,
  }) {
    return ItineraryStop(
      id: id ?? this.id,
      stopNumber: stopNumber ?? this.stopNumber,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      location: location ?? this.location,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      timeWindow: timeWindow ?? this.timeWindow,
      badgeText: badgeText ?? this.badgeText,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      taskItems: taskItems ?? this.taskItems,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

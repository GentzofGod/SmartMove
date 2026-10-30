import 'item_acquisition_source.dart';

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
  final List<ItemAcquisitionSource> itemSources;
  final String? outletName;
  final AcquisitionChannel? channel;
  final bool isPlatformRegisteredTrader;
  final String? traderId;
  final String? contactPhone;
  final String? whatsappNumber;
  final String? webUrl;
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
    this.itemSources = const [],
    this.outletName,
    this.channel,
    this.isPlatformRegisteredTrader = false,
    this.traderId,
    this.contactPhone,
    this.whatsappNumber,
    this.webUrl,
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
    List<ItemAcquisitionSource>? itemSources,
    String? outletName,
    AcquisitionChannel? channel,
    bool? isPlatformRegisteredTrader,
    String? traderId,
    String? contactPhone,
    String? whatsappNumber,
    String? webUrl,
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
      itemSources: itemSources ?? this.itemSources,
      outletName: outletName ?? this.outletName,
      channel: channel ?? this.channel,
      isPlatformRegisteredTrader:
          isPlatformRegisteredTrader ?? this.isPlatformRegisteredTrader,
      traderId: traderId ?? this.traderId,
      contactPhone: contactPhone ?? this.contactPhone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      webUrl: webUrl ?? this.webUrl,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

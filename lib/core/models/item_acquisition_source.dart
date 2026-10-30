enum AcquisitionChannel {
  registeredTrader,
  physicalMarketHub,
  retailStore,
  ecommercePlatform;

  String get displayName {
    switch (this) {
      case AcquisitionChannel.registeredTrader:
        return 'Platform Registered Trader';
      case AcquisitionChannel.physicalMarketHub:
        return 'Physical Market Hub';
      case AcquisitionChannel.retailStore:
        return 'Neighborhood Store';
      case AcquisitionChannel.ecommercePlatform:
        return 'Online Ecommerce';
    }
  }
}

class ItemAcquisitionSource {
  final String id;
  final String itemId;
  final String commodityName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalCost;
  final String outletName;
  final AcquisitionChannel channel;
  final String marketHubOrLocation;
  final double? latitude;
  final double? longitude;
  final double dynamicDistanceKm;
  final bool isPlatformRegisteredTrader;
  final String? traderId;
  final String? contactPhone;
  final String? whatsappNumber;
  final String? webUrl;
  final bool inStock;
  final String? brandOrGrade;

  const ItemAcquisitionSource({
    required this.id,
    required this.itemId,
    required this.commodityName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalCost,
    required this.outletName,
    required this.channel,
    required this.marketHubOrLocation,
    this.latitude,
    this.longitude,
    required this.dynamicDistanceKm,
    this.isPlatformRegisteredTrader = false,
    this.traderId,
    this.contactPhone,
    this.whatsappNumber,
    this.webUrl,
    this.inStock = true,
    this.brandOrGrade,
  });

  String get formattedUnitPrice => '₦${unitPrice.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';

  String get formattedTotalCost => '₦${totalCost.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';

  ItemAcquisitionSource copyWith({
    String? id,
    String? itemId,
    String? commodityName,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalCost,
    String? outletName,
    AcquisitionChannel? channel,
    String? marketHubOrLocation,
    double? latitude,
    double? longitude,
    double? dynamicDistanceKm,
    bool? isPlatformRegisteredTrader,
    String? traderId,
    String? contactPhone,
    String? whatsappNumber,
    String? webUrl,
    bool? inStock,
    String? brandOrGrade,
  }) {
    return ItemAcquisitionSource(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      commodityName: commodityName ?? this.commodityName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalCost: totalCost ?? this.totalCost,
      outletName: outletName ?? this.outletName,
      channel: channel ?? this.channel,
      marketHubOrLocation: marketHubOrLocation ?? this.marketHubOrLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dynamicDistanceKm: dynamicDistanceKm ?? this.dynamicDistanceKm,
      isPlatformRegisteredTrader:
          isPlatformRegisteredTrader ?? this.isPlatformRegisteredTrader,
      traderId: traderId ?? this.traderId,
      contactPhone: contactPhone ?? this.contactPhone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      webUrl: webUrl ?? this.webUrl,
      inStock: inStock ?? this.inStock,
      brandOrGrade: brandOrGrade ?? this.brandOrGrade,
    );
  }
}


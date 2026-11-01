import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../models/price_observation.dart';
import '../../models/item_acquisition_source.dart';
import '../../services/location_service.dart';
import '../../state/app_state.dart';
import '../../../features/decision_lab/presentation/widgets/trader_negotiation_sheet.dart';

class SellerLocationMapSheet extends ConsumerStatefulWidget {
  final String sellerName;
  final String marketLocation;
  final String? stallLocation;
  final double? sellerLat;
  final double? sellerLng;
  final String? productName;
  final double? price;
  final String? unit;
  final String? brandOrGrade;
  final bool inStock;
  final String? contactPhone;
  final PriceObservation? observation;

  const SellerLocationMapSheet({
    super.key,
    required this.sellerName,
    required this.marketLocation,
    this.stallLocation,
    this.sellerLat,
    this.sellerLng,
    this.productName,
    this.price,
    this.unit,
    this.brandOrGrade,
    this.inStock = true,
    this.contactPhone,
    this.observation,
  });

  factory SellerLocationMapSheet.fromObservation(PriceObservation obs) {
    return SellerLocationMapSheet(
      sellerName: obs.sellerName,
      marketLocation: obs.marketLocation,
      stallLocation: obs.notes,
      sellerLat: obs.latitude,
      sellerLng: obs.longitude,
      productName: obs.productName,
      price: obs.price,
      unit: obs.unit,
      brandOrGrade: obs.brandOrGrade,
      inStock: obs.inStock,
      observation: obs,
    );
  }

  factory SellerLocationMapSheet.fromSource(ItemAcquisitionSource src) {
    return SellerLocationMapSheet(
      sellerName: src.outletName,
      marketLocation: src.marketHubOrLocation,
      sellerLat: src.latitude,
      sellerLng: src.longitude,
      productName: src.commodityName,
      price: src.unitPrice,
      unit: src.unit,
      brandOrGrade: src.brandOrGrade,
      inStock: src.inStock,
      contactPhone: src.contactPhone,
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String sellerName,
    required String marketLocation,
    String? stallLocation,
    double? sellerLat,
    double? sellerLng,
    String? productName,
    double? price,
    String? unit,
    String? brandOrGrade,
    bool inStock = true,
    String? contactPhone,
    PriceObservation? observation,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SellerLocationMapSheet(
        sellerName: sellerName,
        marketLocation: marketLocation,
        stallLocation: stallLocation,
        sellerLat: sellerLat,
        sellerLng: sellerLng,
        productName: productName,
        price: price,
        unit: unit,
        brandOrGrade: brandOrGrade,
        inStock: inStock,
        contactPhone: contactPhone,
        observation: observation,
      ),
    );
  }

  @override
  ConsumerState<SellerLocationMapSheet> createState() => _SellerLocationMapSheetState();
}

class _SellerLocationMapSheetState extends ConsumerState<SellerLocationMapSheet> {
  late final MapController _mapController;

  static const Map<String, LatLng> _hubCoordinates = {
    'bodija': LatLng(7.4243, 3.9168),
    'dugbe': LatLng(7.3916, 3.8797),
    'oje': LatLng(7.3871, 3.9110),
    'oja oba': LatLng(7.3752, 3.8963),
    'gbagi': LatLng(7.3965, 3.9638),
    'abeokuta': LatLng(7.1475, 3.3619),
    'kuto': LatLng(7.1420, 3.3550),
    'itoku': LatLng(7.1550, 3.3400),
    'omida': LatLng(7.1480, 3.3450),
    'lafenwa': LatLng(7.1700, 3.3300),
    'ibara': LatLng(7.1557, 3.3451),
    'sagamu': LatLng(6.8400, 3.6500),
    'ijebu': LatLng(6.8200, 3.9200),
    'mile 12': LatLng(6.6020, 3.3900),
    'oyingbo': LatLng(6.4950, 3.3780),
    'tejuosho': LatLng(6.5150, 3.3640),
    'balogun': LatLng(6.4550, 3.3850),
    'alaba': LatLng(6.4620, 3.1930),
    'wuse': LatLng(9.0600, 7.4680),
    'utako': LatLng(9.0700, 7.4390),
    'kano': LatLng(12.0000, 8.5200),
    'port harcourt': LatLng(4.8360, 7.0500),
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng? _resolveSellerCoordinates() {
    if (widget.sellerLat != null && widget.sellerLng != null && widget.sellerLat != 0.0) {
      return LatLng(widget.sellerLat!, widget.sellerLng!);
    }

    // 1. Try extracting explicit Lat / Lon from stallLocation or marketLocation string
    final marketString = '${widget.stallLocation ?? ""} ${widget.marketLocation}'.trim();
    final coordMatch = RegExp(r'Lat:\s*([0-9.-]+).*?Lon:\s*([0-9.-]+)', caseSensitive: false).firstMatch(marketString);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1) ?? '');
      final lon = double.tryParse(coordMatch.group(2) ?? '');
      if (lat != null && lon != null && lat != 0.0) {
        return LatLng(lat, lon);
      }
    }

    // 2. Try looking up seller in sellerApplicationsProvider or currentUser session
    try {
      final applications = ref.read(sellerApplicationsProvider);
      final sName = widget.sellerName.toLowerCase().trim();
      for (final a in applications) {
        if (a.businessName.toLowerCase().trim() == sName ||
            a.applicantName.toLowerCase().trim() == sName) {
          if (a.latitude != null && a.longitude != null && a.latitude != 0.0) {
            return LatLng(a.latitude!, a.longitude!);
          }
        }
      }

      final session = ref.read(authProvider);
      if (session.businessName?.toLowerCase().trim() == sName || session.displayName.toLowerCase().trim() == sName) {
        if (session.latitude != null && session.longitude != null && session.latitude != 0.0) {
          return LatLng(session.latitude!, session.longitude!);
        }
      }
    } catch (_) {}

    // 3. Match market location against known hub coordinates
    final marketQuery = marketString.toLowerCase();
    for (final entry in _hubCoordinates.entries) {
      if (marketQuery.contains(entry.key)) {
        return entry.value;
      }
    }

    // 4. City-level resolution if market location mentions a known city
    if (marketQuery.contains('abeokuta') || marketQuery.contains('ogun')) {
      return const LatLng(7.1475, 3.3619);
    }
    if (marketQuery.contains('lagos') || marketQuery.contains('ikeja')) {
      return const LatLng(6.6020, 3.3515);
    }
    if (marketQuery.contains('abuja') || marketQuery.contains('fct')) {
      return const LatLng(9.0765, 7.3986);
    }

    // Return null if coordinates are unknown so UI reports accurately without fake fallback
    return null;
  }

  Future<void> _openExternalNavigation(LatLng sellerPos) async {
    final lat = sellerPos.latitude;
    final lng = sellerPos.longitude;
    final label = Uri.encodeComponent('${widget.sellerName} (${widget.marketLocation})');
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    final webMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webMapsUri)) {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _openTraderChat() {
    Navigator.pop(context);
    final source = widget.observation != null
        ? ItemAcquisitionSource.fromObservation(widget.observation!)
        : ItemAcquisitionSource(
            id: 'src-${widget.sellerName.toLowerCase().replaceAll(' ', '-')}',
            itemId: 'item-${widget.productName ?? "commodity"}',
            commodityName: widget.productName ?? 'Commodity Item',
            quantity: 1.0,
            unit: widget.unit ?? '1kg',
            unitPrice: widget.price ?? 0.0,
            totalCost: widget.price ?? 0.0,
            outletName: widget.sellerName,
            channel: AcquisitionChannel.registeredTrader,
            marketHubOrLocation: widget.marketLocation,
            latitude: widget.sellerLat,
            longitude: widget.sellerLng,
            dynamicDistanceKm: 1.5,
            isPlatformRegisteredTrader: true,
            inStock: widget.inStock,
            brandOrGrade: widget.brandOrGrade,
          );

    TraderNegotiationSheet.show(context, source: source);
  }

  @override
  Widget build(BuildContext context) {
    final buyerLocation = ref.watch(locationProvider);
    final sellerPos = _resolveSellerCoordinates();
    final buyerPos = buyerLocation.isSet ? LatLng(buyerLocation.latitude, buyerLocation.longitude) : null;

    double? distanceKm;
    if (buyerPos != null && sellerPos != null) {
      distanceKm = LocationService.calculateDistanceKm(
        lat1: buyerPos.latitude,
        lon1: buyerPos.longitude,
        lat2: sellerPos.latitude,
        lon2: sellerPos.longitude,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            // Sheet grab handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.explore_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.sellerName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.badgeSuccessBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Verified Trader',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'OpenStreetMap Physical Stall Locator',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Interactive OpenStreetMap Canvas
            Expanded(
              child: sellerPos != null
                  ? Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: sellerPos,
                      initialZoom: 15.5,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      // Open-source OpenStreetMap carto tile layer (100% free, no API keys)
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ng.smartmove.app',
                      ),

                      // Connecting route polyline between buyer and seller stall
                      if (buyerPos != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [buyerPos, sellerPos],
                              strokeWidth: 3.5,
                              color: AppColors.primary,
                              pattern: StrokePattern.dashed(segments: const [8, 6]),
                            ),
                          ],
                        ),

                      // Pin Markers Layer
                      MarkerLayer(
                        markers: [
                          if (buyerPos != null)
                            Marker(
                              point: buyerPos,
                              width: 50,
                              height: 50,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1976D2),
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.person_pin, color: Colors.white, size: 18),
                                  ),
                                  const Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1976D2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Marker(
                            point: sellerPos,
                            width: 80,
                            height: 70,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                  ),
                                  child: Text(
                                    widget.sellerName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFD32F2F),
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Map Floating Controls
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'map_zoom_in',
                          backgroundColor: Colors.white,
                          onPressed: () {
                            final current = _mapController.camera.zoom;
                            _mapController.move(_mapController.camera.center, current + 1);
                          },
                          child: const Icon(Icons.add, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'map_zoom_out',
                          backgroundColor: Colors.white,
                          onPressed: () {
                            final current = _mapController.camera.zoom;
                            _mapController.move(_mapController.camera.center, current - 1);
                          },
                          child: const Icon(Icons.remove, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'map_recenter_seller',
                          backgroundColor: AppColors.primary,
                          onPressed: () => _mapController.move(sellerPos, 16.0),
                          child: const Icon(Icons.my_location, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // OpenStreetMap attribution badge
                  Positioned(
                    left: 10,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 9, color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF8E1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_off_rounded,
                            color: Color(0xFFF57F17), size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Stall GPS Not Yet Calibrated',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.sellerName} is listed at "${widget.marketLocation}", but precise GPS stall coordinates have not been submitted.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Contact the seller via In-App Chat or Phone Call below for direct stall directions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Seller & Product Navigation Sheet
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location & Stall row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.stallLocation != null && widget.stallLocation!.isNotEmpty
                                    ? widget.stallLocation!
                                    : widget.marketLocation,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Text(
                                '${widget.marketLocation} • ${distanceKm != null ? "${distanceKm.toStringAsFixed(1)} km away" : "Physical Store"}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.inStock ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.inStock ? 'In Stock' : 'Out of Stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.inStock ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (widget.productName != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.productName!,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.price != null && widget.price! > 0)
                              Text(
                                '₦${widget.price!.toStringAsFixed(0)} / ${widget.unit ?? "1kg"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Actions Row
                    Row(
                      children: [
                        // Open External GPS Directions
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: sellerPos != null
                                ? () => _openExternalNavigation(sellerPos)
                                : null,
                            icon: const Icon(Icons.directions_outlined, size: 18),
                            label: const Text('Directions', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Chat & Buy
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _openTraderChat,
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Chat & Buy', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

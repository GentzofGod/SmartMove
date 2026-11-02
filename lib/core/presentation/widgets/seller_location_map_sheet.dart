import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
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
    final cleanStall = (obs.notes != null &&
            !obs.notes!.toLowerCase().contains('submitted via') &&
            !obs.notes!.toLowerCase().contains('smartmove app'))
        ? obs.notes
        : null;

    return SellerLocationMapSheet(
      sellerName: obs.sellerName,
      marketLocation: obs.marketLocation,
      stallLocation: cleanStall,
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
  LatLng? _dynamicallyGeocodedPos;
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _attemptDynamicGeocodingIfNeeded();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String? _resolveStallLocation() {
    if (widget.stallLocation != null && widget.stallLocation!.trim().isNotEmpty) {
      final s = widget.stallLocation!.trim();
      if (!s.toLowerCase().contains('submitted via') && !s.toLowerCase().contains('smartmove app')) {
        return s;
      }
    }
    final sName = widget.sellerName.toLowerCase().trim();
    try {
      final applications = ref.read(sellerApplicationsProvider);
      for (final a in applications) {
        if (a.businessName.toLowerCase().trim() == sName ||
            a.applicantName.toLowerCase().trim() == sName) {
          if (a.stallLocation != null && a.stallLocation!.trim().isNotEmpty) {
            return a.stallLocation!.trim();
          }
        }
      }
      final session = ref.read(authProvider);
      if (session.businessName?.toLowerCase().trim() == sName ||
          session.displayName.toLowerCase().trim() == sName) {
        if (session.stallLocation != null && session.stallLocation!.trim().isNotEmpty) {
          return session.stallLocation!.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  String? _resolveContactPhone() {
    if (widget.contactPhone != null && widget.contactPhone!.trim().isNotEmpty) {
      return widget.contactPhone!.trim();
    }
    final sName = widget.sellerName.toLowerCase().trim();
    try {
      final applications = ref.read(sellerApplicationsProvider);
      for (final a in applications) {
        if (a.businessName.toLowerCase().trim() == sName ||
            a.applicantName.toLowerCase().trim() == sName) {
          if (a.phone.trim().isNotEmpty) return a.phone.trim();
        }
      }
      final session = ref.read(authProvider);
      if (session.businessName?.toLowerCase().trim() == sName ||
          session.displayName.toLowerCase().trim() == sName) {
        if (session.phone != null && session.phone!.trim().isNotEmpty) {
          return session.phone!.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  String get exactShopAddress {
    final stall = _resolveStallLocation();
    final market = widget.marketLocation.trim();
    if (stall != null && stall.isNotEmpty) {
      if (market.isNotEmpty && !stall.toLowerCase().contains(market.toLowerCase())) {
        return '$stall, $market';
      }
      return stall;
    }
    return market.isNotEmpty ? market : 'Exact stall location not listed';
  }

  LatLng? _resolveSellerCoordinates() {
    // 1. Direct explicit coordinates from widget
    if (widget.sellerLat != null && widget.sellerLng != null && widget.sellerLat != 0.0) {
      return LatLng(widget.sellerLat!, widget.sellerLng!);
    }

    // 2. Coordinates from PriceObservation
    if (widget.observation?.latitude != null &&
        widget.observation?.longitude != null &&
        widget.observation!.latitude != 0.0) {
      return LatLng(widget.observation!.latitude!, widget.observation!.longitude!);
    }

    // 3. Explicit Lat / Lon in stall or market string
    final marketString = '${widget.stallLocation ?? ""} ${widget.marketLocation}'.trim();
    final coordMatch = RegExp(r'Lat:\s*([0-9.-]+).*?Lon:\s*([0-9.-]+)', caseSensitive: false).firstMatch(marketString);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1) ?? '');
      final lon = double.tryParse(coordMatch.group(2) ?? '');
      if (lat != null && lon != null && lat != 0.0) {
        return LatLng(lat, lon);
      }
    }

    // 4. Coordinates from verified seller applications or current session
    final sName = widget.sellerName.toLowerCase().trim();
    try {
      final applications = ref.read(sellerApplicationsProvider);
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

    // 5. Dynamically geocoded coordinates (from real live OSM Nominatim query)
    if (_dynamicallyGeocodedPos != null) {
      return _dynamicallyGeocodedPos;
    }

    // Absolutely NO hardcoded fallback coordinates!
    return null;
  }

  Future<void> _attemptDynamicGeocodingIfNeeded() async {
    if (_resolveSellerCoordinates() != null) return;

    final query = exactShopAddress;
    if (query.isEmpty || query.contains('not listed')) return;

    setState(() => _isGeocoding = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent("$query, Nigeria")}&format=json&limit=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'SmartMoveApp/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final first = data.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null && mounted) {
            setState(() {
              _dynamicallyGeocodedPos = LatLng(lat, lon);
              _isGeocoding = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isGeocoding = false);
    }
  }

  Future<void> _openExternalNavigation(LatLng? sellerPos) async {
    final addressQuery = '${widget.sellerName}, $exactShopAddress';
    final queryEncoded = Uri.encodeComponent(addressQuery);

    final geoUri = sellerPos != null
        ? Uri.parse('geo:${sellerPos.latitude},${sellerPos.longitude}?q=${sellerPos.latitude},${sellerPos.longitude}($queryEncoded)')
        : Uri.parse('geo:0,0?q=$queryEncoded');

    final webMapsUri = sellerPos != null
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=${sellerPos.latitude},${sellerPos.longitude}')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$queryEncoded');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webMapsUri)) {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _callSeller(String phone) async {
    final telUri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F5E9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.store_mall_directory_rounded,
                                  color: Color(0xFF2E7D32), size: 48),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Stall GPS Not Yet Calibrated',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 18),
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
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F8E9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFAED581)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.pin_drop_rounded, color: Color(0xFF2E7D32), size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'EXACT SHOP / STALL ADDRESS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2E7D32),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    exactShopAddress,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (_resolveStallLocation() != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Market / District: ${widget.marketLocation}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _isGeocoding
                                  ? 'Locating exact coordinates on map...'
                                  : 'Navigate directly to this shop using Google Maps or contact the seller below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                  height: 1.3),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1976D2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _openExternalNavigation(null),
                                icon: const Icon(Icons.map_rounded, size: 20),
                                label: const Text(
                                  'Find Exact Shop on Google Maps',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                ),
                              ),
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
                                LocationService.cleanDisplayAddress(exactShopAddress),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                distanceKm != null
                                    ? '${distanceKm.toStringAsFixed(1)} km away • Verified Outlet'
                                    : 'Verified Physical Outlet',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                        // Open External Directions (Google Maps / GPS)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _openExternalNavigation(sellerPos),
                            icon: const Icon(Icons.directions_outlined, size: 18),
                            label: const Text('Directions', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        if (_resolveContactPhone() != null && _resolveContactPhone()!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE8F5E9),
                              foregroundColor: const Color(0xFF2E7D32),
                              padding: const EdgeInsets.all(12),
                            ),
                            tooltip: 'Call Seller: ${_resolveContactPhone()!}',
                            icon: const Icon(Icons.call_rounded, size: 20),
                            onPressed: () => _callSeller(_resolveContactPhone()!),
                          ),
                        ],
                        const SizedBox(width: 8),
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

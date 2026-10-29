import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeoPoint {
  final double latitude;
  final double longitude;
  final String label;
  final String city;
  final bool isDeviceLocation;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.city,
    this.isDeviceLocation = false,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
        'city': city,
        'isDeviceLocation': isDeviceLocation,
      };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        label: json['label'] as String? ?? 'Custom Location',
        city: json['city'] as String? ?? 'Local Area',
        isDeviceLocation: json['isDeviceLocation'] as bool? ?? false,
      );

  GeoPoint copyWith({
    double? latitude,
    double? longitude,
    String? label,
    String? city,
    bool? isDeviceLocation,
  }) {
    return GeoPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      city: city ?? this.city,
      isDeviceLocation: isDeviceLocation ?? this.isDeviceLocation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          label == other.label &&
          city == other.city &&
          isDeviceLocation == other.isDeviceLocation;

  @override
  int get hashCode =>
      latitude.hashCode ^
      longitude.hashCode ^
      label.hashCode ^
      city.hashCode ^
      isDeviceLocation.hashCode;
}

class LocationService {
  static const String _storageKey = 'smartmove_saved_location_v1';

  // Common predefined commercial hubs in Nigeria for fast switching & fallbacks
  static const GeoPoint defaultHub = GeoPoint(
    latitude: 6.5244,
    longitude: 3.3792,
    label: 'Lagos Mainland (Yaba/Surulere)',
    city: 'Lagos',
  );

  static const List<GeoPoint> availableHubs = [
    GeoPoint(
      latitude: 6.5244,
      longitude: 3.3792,
      label: 'Lagos Mainland (Yaba/Surulere)',
      city: 'Lagos',
    ),
    GeoPoint(
      latitude: 6.6018,
      longitude: 3.3515,
      label: 'Ikeja Commercial Hub',
      city: 'Lagos',
    ),
    GeoPoint(
      latitude: 6.4531,
      longitude: 3.5283,
      label: 'Lekki / Victoria Island',
      city: 'Lagos',
    ),
    GeoPoint(
      latitude: 7.4343,
      longitude: 3.9056,
      label: 'Bodija Market Area',
      city: 'Ibadan',
    ),
    GeoPoint(
      latitude: 7.3876,
      longitude: 3.8767,
      label: 'Dugbe Business District',
      city: 'Ibadan',
    ),
    GeoPoint(
      latitude: 9.0765,
      longitude: 7.3986,
      label: 'Wuse 2 Market Zone',
      city: 'Abuja',
    ),
  ];

  // Coordinates of recognized markets/merchants
  static const Map<String, GeoPoint> knownMarketCoordinates = {
    'Market A': GeoPoint(
      latitude: 6.4950,
      longitude: 3.3780,
      label: 'Market A (Oyingbo)',
      city: 'Lagos',
    ),
    'Market B': GeoPoint(
      latitude: 6.5150,
      longitude: 3.3640,
      label: 'Market B (Tejuosho)',
      city: 'Lagos',
    ),
    'Market C': GeoPoint(
      latitude: 6.6020,
      longitude: 3.3900,
      label: 'Market C (Mile 12)',
      city: 'Lagos',
    ),
    'MedPlus Pharmacy': GeoPoint(
      latitude: 6.5200,
      longitude: 3.3750,
      label: 'MedPlus Pharmacy',
      city: 'Lagos',
    ),
    'GIG Logistics': GeoPoint(
      latitude: 6.5100,
      longitude: 3.3700,
      label: 'GIG Logistics Hub',
      city: 'Lagos',
    ),
    'Pharmacy Plus': GeoPoint(
      latitude: 6.5180,
      longitude: 3.3720,
      label: 'Pharmacy Plus',
      city: 'Lagos',
    ),
    'TechHub Dugbe': GeoPoint(
      latitude: 7.3876,
      longitude: 3.8767,
      label: 'TechHub Dugbe',
      city: 'Ibadan',
    ),
  };

  /// Persist the selected or live location to SharedPreferences
  static Future<void> persistLocation(GeoPoint point) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(point.toJson()));
    } catch (_) {}
  }

  /// Restore saved location from disk on app launch
  static Future<GeoPoint?> restorePersistedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return GeoPoint.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Obtain the live device GPS position via Geolocator or IP fallback,
  /// resolved to the user's actual location rather than collapsing to default hubs.
  static Future<GeoPoint?> getCurrentDeviceLocation() async {
    // 1. Try Hardware GPS via Geolocator
    try {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          // If location service is disabled on device, proceed to IP-based location
          return await _getIpBasedLocation();
        }
      } catch (_) {
        // Some web/desktop environments throw or don't support isLocationServiceEnabled
      }

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
      } catch (_) {}

      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        Position? position;

        // Try getting fresh position with 12s timeout
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 12),
            ),
          );
        } catch (_) {
          // If timeout or failure, check last known position
          try {
            position = await Geolocator.getLastKnownPosition();
          } catch (_) {}
        }

        if (position != null) {
          return await _resolveLiveGeoPoint(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      }
    } catch (_) {
      // Hardware GPS failed, proceed to IP fallback
    }

    // 2. Network / IP Geolocation fallback (useful for web, simulators, or GPS off)
    try {
      final ipPoint = await _getIpBasedLocation();
      if (ipPoint != null) {
        return ipPoint;
      }
    } catch (_) {}

    return null;
  }

  /// Fallback: Geolocation via IP address
  static Future<GeoPoint?> _getIpBasedLocation() async {
    try {
      final url = Uri.parse('http://ip-api.com/json/');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          final lat = (data['lat'] as num).toDouble();
          final lon = (data['lon'] as num).toDouble();
          final city = (data['city'] as String?)?.trim() ?? 'Local Area';
          final region = (data['regionName'] as String?)?.trim() ?? '';
          final label = region.isNotEmpty && region != city
              ? 'Live: $city, $region'
              : 'Live: $city';

          return GeoPoint(
            latitude: lat,
            longitude: lon,
            label: label,
            city: city,
            isDeviceLocation: true,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolve coordinates into human-readable real place name,
  /// avoiding collapsing live locations back to default hubs.
  static Future<GeoPoint> _resolveLiveGeoPoint({
    required double latitude,
    required double longitude,
  }) async {
    // Attempt reverse geocoding via OpenStreetMap Nominatim
    try {
      final reverse = await reverseGeocode(latitude, longitude);
      if (reverse != null) {
        return GeoPoint(
          latitude: latitude,
          longitude: longitude,
          label: reverse['label']!,
          city: reverse['city']!,
          isDeviceLocation: true,
        );
      }
    } catch (_) {}

    // Fallback: Check proximity to known Nigerian commercial hubs or keep coordinates
    final closestHub = findClosestHub(latitude, longitude);
    final distanceToHub = calculateDistanceKm(
      lat1: latitude,
      lon1: longitude,
      lat2: closestHub.latitude,
      lon2: closestHub.longitude,
    );

    String label;
    String city;

    if (distanceToHub <= 30.0) {
      final hubName = closestHub.label.split('(').first.trim();
      label = 'Live: Near $hubName';
      city = closestHub.city;
    } else {
      label = 'Live: (${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)})';
      city = closestHub.city;
    }

    return GeoPoint(
      latitude: latitude,
      longitude: longitude,
      label: label,
      city: city,
      isDeviceLocation: true,
    );
  }

  /// Reverse geocode coordinates to human-readable neighborhood/city
  static Future<Map<String, String>?> reverseGeocode(
    double lat,
    double lon,
  ) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=14&addressdetails=1',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'SmartMoveApp/1.0'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final suburb = address['suburb']?.toString() ??
            address['neighbourhood']?.toString() ??
            address['residential']?.toString() ??
            address['quarter']?.toString();

        final city = address['city']?.toString() ??
            address['town']?.toString() ??
            address['village']?.toString() ??
            address['county']?.toString() ??
            address['state']?.toString() ??
            'Local Area';

        String label;
        if (suburb != null && suburb.isNotEmpty && suburb != city) {
          label = 'Live: $suburb, $city';
        } else {
          label = 'Live: $city';
        }

        return {
          'label': label,
          'city': city,
        };
      }
    } catch (_) {}
    return null;
  }

  /// Finds the closest Nigerian commercial hub from given coordinates
  static GeoPoint findClosestHub(double lat, double lon) {
    GeoPoint closest = availableHubs.first;
    double minDistance = double.infinity;

    for (final hub in availableHubs) {
      final d = calculateDistanceKm(
        lat1: lat,
        lon1: lon,
        lat2: hub.latitude,
        lon2: hub.longitude,
      );
      if (d < minDistance) {
        minDistance = d;
        closest = hub;
      }
    }
    return closest;
  }

  /// Calculate distance between two coordinate points using Haversine formula
  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadiusKm = 6371.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final dist = earthRadiusKm * c;
    return double.parse(dist.toStringAsFixed(1));
  }

  static double _degToRad(double deg) {
    return deg * (pi / 180.0);
  }

  /// Estimate road transit fare based on distance in Naira (₦)
  static double estimateTransportFare(double distanceKm) {
    if (distanceKm <= 1.0) return 500.0;
    final fare = 500.0 + ((distanceKm - 1.0) * 150.0);
    // Round to nearest 50
    return ((fare / 50).round() * 50).toDouble();
  }
}

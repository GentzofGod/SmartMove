import 'dart:math';
import 'package:geolocator/geolocator.dart';

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
}

class LocationService {
  // Common predefined commercial hubs in Nigeria for fast switching & fallbacks
  static const GeoPoint defaultHub = GeoPoint(
    latitude: 6.5244,
    longitude: 3.3792,
    label: 'Lagos Mainland',
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
  };

  /// Obtain the live device GPS position via Geolocator
  static Future<GeoPoint?> getCurrentDeviceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final closestHub = findClosestHub(position.latitude, position.longitude);

      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'Current Location (${closestHub.city})',
        city: closestHub.city,
        isDeviceLocation: true,
      );
    } catch (_) {
      return null;
    }
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

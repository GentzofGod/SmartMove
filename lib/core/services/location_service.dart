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
  final String town;
  final bool isDeviceLocation;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.city,
    this.town = '',
    this.isDeviceLocation = false,
  });

  /// Returns the human-readable town/locality name (guaranteed never raw coordinates)
  String get displayTown {
    if (town.isNotEmpty && !_isRawCoordinateString(town)) {
      return town;
    }
    // Extract town from label if label contains human-readable place name
    final cleanLabel = label.replaceFirst(RegExp(r'^Live:\s*', caseSensitive: false), '').trim();
    if (cleanLabel.isNotEmpty && !_isRawCoordinateString(cleanLabel)) {
      final candidate = cleanLabel.split('(').first.split(',').first.trim();
      if (candidate.isNotEmpty && !_isRawCoordinateString(candidate)) {
        return candidate.replaceFirst(RegExp(r'^Near\s+', caseSensitive: false), '').trim();
      }
    }
    if (city.isNotEmpty && city != 'Local Area' && !_isRawCoordinateString(city)) {
      return city;
    }
    return 'Commercial Area';
  }

  /// Clean display representation: e.g. "Dugbe, Ibadan", "Abeokuta, Ogun", or "Ikeja, Lagos"
  String get displayLocation {
    final t = displayTown;
    if (city.isNotEmpty &&
        city != 'Local Area' &&
        !_isRawCoordinateString(city) &&
        !t.toLowerCase().contains(city.toLowerCase()) &&
        !city.toLowerCase().contains(t.toLowerCase())) {
      return '$t, $city';
    }
    return t;
  }

  static bool _isRawCoordinateString(String s) {
    final trimmed = s.replaceAll(RegExp(r'[()\[\]\s]'), '');
    return RegExp(r'^-?\d+(\.\d+)?,-?\d+(\.\d+)?$').hasMatch(trimmed) ||
        RegExp(r'^-?\d+(\.\d+)?$').hasMatch(trimmed);
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
        'city': city,
        'town': town,
        'isDeviceLocation': isDeviceLocation,
      };

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    final city = json['city'] as String? ?? 'Local Area';
    final rawTown = json['town'] as String?;
    final label = json['label'] as String? ?? 'Custom Location';
    final town = rawTown ??
        (label.isNotEmpty && !label.startsWith('(')
            ? label.split('(').first.replaceFirst('Live:', '').trim()
            : city);

    return GeoPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      label: label,
      city: city,
      town: town,
      isDeviceLocation: json['isDeviceLocation'] as bool? ?? false,
    );
  }

  GeoPoint copyWith({
    double? latitude,
    double? longitude,
    String? label,
    String? city,
    String? town,
    bool? isDeviceLocation,
  }) {
    return GeoPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      city: city ?? this.city,
      town: town ?? this.town,
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
          town == other.town &&
          isDeviceLocation == other.isDeviceLocation;

  @override
  int get hashCode =>
      latitude.hashCode ^
      longitude.hashCode ^
      label.hashCode ^
      city.hashCode ^
      town.hashCode ^
      isDeviceLocation.hashCode;
}

class NigerianTown {
  final String town;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final String commercialHub;

  const NigerianTown({
    required this.town,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    required this.commercialHub,
  });
}

class LocationService {
  static const String _storageKey = 'smartmove_saved_location_v1';

  // Common predefined commercial hubs in Nigeria for fast switching & fallbacks
  static const GeoPoint defaultHub = GeoPoint(
    latitude: 6.5244,
    longitude: 3.3792,
    label: 'Lagos Mainland (Yaba/Surulere)',
    city: 'Lagos',
    town: 'Yaba',
  );

  static const List<GeoPoint> availableHubs = [
    GeoPoint(
      latitude: 6.5244,
      longitude: 3.3792,
      label: 'Lagos Mainland (Yaba/Surulere)',
      city: 'Lagos',
      town: 'Yaba',
    ),
    GeoPoint(
      latitude: 6.6018,
      longitude: 3.3515,
      label: 'Ikeja Commercial Hub',
      city: 'Lagos',
      town: 'Ikeja',
    ),
    GeoPoint(
      latitude: 6.4531,
      longitude: 3.5283,
      label: 'Lekki / Victoria Island',
      city: 'Lagos',
      town: 'Lekki',
    ),
    GeoPoint(
      latitude: 7.4343,
      longitude: 3.9056,
      label: 'Bodija Market Area',
      city: 'Ibadan',
      town: 'Bodija',
    ),
    GeoPoint(
      latitude: 7.3876,
      longitude: 3.8767,
      label: 'Dugbe Business District',
      city: 'Ibadan',
      town: 'Dugbe',
    ),
    GeoPoint(
      latitude: 9.0765,
      longitude: 7.3986,
      label: 'Wuse 2 Market Zone',
      city: 'Abuja',
      town: 'Wuse 2',
    ),
    GeoPoint(
      latitude: 7.1557,
      longitude: 3.3451,
      label: 'Abeokuta Commercial Hub (Ibara)',
      city: 'Ogun',
      town: 'Abeokuta',
    ),
    GeoPoint(
      latitude: 7.7827,
      longitude: 4.5418,
      label: 'Osogbo Central Market Zone',
      city: 'Osun',
      town: 'Osogbo',
    ),
    GeoPoint(
      latitude: 7.2571,
      longitude: 5.2058,
      label: 'Akure Commercial Hub (Oja Oba)',
      city: 'Ondo',
      town: 'Akure',
    ),
    GeoPoint(
      latitude: 8.4966,
      longitude: 4.5421,
      label: 'Ilorin Commercial Zone (Post Office)',
      city: 'Kwara',
      town: 'Ilorin',
    ),
    GeoPoint(
      latitude: 6.3350,
      longitude: 5.6037,
      label: 'Benin City Hub (Ring Road)',
      city: 'Edo',
      town: 'Benin City',
    ),
    GeoPoint(
      latitude: 5.5442,
      longitude: 5.7603,
      label: 'Warri / Effurun Commercial Hub',
      city: 'Delta',
      town: 'Warri',
    ),
    GeoPoint(
      latitude: 4.8156,
      longitude: 7.0498,
      label: 'Port Harcourt Hub (Mile 1/Oil Mill)',
      city: 'Rivers',
      town: 'Port Harcourt',
    ),
    GeoPoint(
      latitude: 6.1498,
      longitude: 6.7858,
      label: 'Onitsha Main Market Hub',
      city: 'Anambra',
      town: 'Onitsha',
    ),
    GeoPoint(
      latitude: 6.4584,
      longitude: 7.5464,
      label: 'Enugu Commercial Hub (Ogbete)',
      city: 'Enugu',
      town: 'Enugu',
    ),
    GeoPoint(
      latitude: 5.4836,
      longitude: 7.0333,
      label: 'Owerri Central Hub (Douglas)',
      city: 'Imo',
      town: 'Owerri',
    ),
    GeoPoint(
      latitude: 5.1065,
      longitude: 7.3667,
      label: 'Aba Commercial Hub (Ariaria)',
      city: 'Abia',
      town: 'Aba',
    ),
    GeoPoint(
      latitude: 12.0022,
      longitude: 8.5920,
      label: 'Kano Central (Sabon Gari/Kurmi)',
      city: 'Kano',
      town: 'Kano',
    ),
    GeoPoint(
      latitude: 10.5222,
      longitude: 7.4383,
      label: 'Kaduna Central Market Zone',
      city: 'Kaduna',
      town: 'Kaduna',
    ),
    GeoPoint(
      latitude: 9.8965,
      longitude: 8.8583,
      label: 'Jos Commercial Hub (Terminus)',
      city: 'Plateau',
      town: 'Jos',
    ),
  ];

  /// Comprehensive registry of Nigerian commercial towns across geopolitical zones
  /// for accurate offline reverse geocoding and town identification.
  static const List<NigerianTown> nigerianTownDirectory = [
    // --- Oyo State ---
    NigerianTown(
      town: 'Dugbe',
      city: 'Ibadan',
      state: 'Oyo',
      latitude: 7.3876,
      longitude: 3.8767,
      commercialHub: 'Dugbe Business District',
    ),
    NigerianTown(
      town: 'Bodija',
      city: 'Ibadan',
      state: 'Oyo',
      latitude: 7.4343,
      longitude: 3.9056,
      commercialHub: 'Bodija Market',
    ),
    NigerianTown(
      town: 'Iwo Road',
      city: 'Ibadan',
      state: 'Oyo',
      latitude: 7.4100,
      longitude: 3.9350,
      commercialHub: 'Iwo Road Transit Hub',
    ),
    NigerianTown(
      town: 'Challenge',
      city: 'Ibadan',
      state: 'Oyo',
      latitude: 7.3500,
      longitude: 3.8700,
      commercialHub: 'Challenge / Ring Road Hub',
    ),
    NigerianTown(
      town: 'Ona Ara',
      city: 'Ibadan',
      state: 'Oyo',
      latitude: 7.2587,
      longitude: 4.0649,
      commercialHub: 'Ona Ara Commercial Zone',
    ),
    NigerianTown(
      town: 'Ogbomoso',
      city: 'Ogbomoso',
      state: 'Oyo',
      latitude: 8.1333,
      longitude: 4.2500,
      commercialHub: 'Oja Akande / Takie',
    ),
    NigerianTown(
      town: 'Oyo Town',
      city: 'Oyo',
      state: 'Oyo',
      latitude: 7.8430,
      longitude: 3.9368,
      commercialHub: 'Akesan Market',
    ),
    NigerianTown(
      town: 'Iseyin',
      city: 'Iseyin',
      state: 'Oyo',
      latitude: 7.9667,
      longitude: 3.6000,
      commercialHub: 'Oja Oba Iseyin',
    ),

    // --- Lagos State ---
    NigerianTown(
      town: 'Yaba',
      city: 'Lagos',
      state: 'Lagos',
      latitude: 6.5000,
      longitude: 3.3700,
      commercialHub: 'Tejuosho / Yaba Market',
    ),
    NigerianTown(
      town: 'Ikeja',
      city: 'Lagos',
      state: 'Lagos',
      latitude: 6.6018,
      longitude: 3.3515,
      commercialHub: 'Computer Village',
    ),
    NigerianTown(
      town: 'Lekki',
      city: 'Lagos',
      state: 'Lagos',
      latitude: 6.4531,
      longitude: 3.5283,
      commercialHub: 'Lekki Phase 1 / Admiralty',
    ),
    NigerianTown(
      town: 'Lagos Island',
      city: 'Lagos',
      state: 'Lagos',
      latitude: 6.4550,
      longitude: 3.3840,
      commercialHub: 'Balogun / Idumota Market',
    ),
    NigerianTown(
      town: 'Surulere',
      city: 'Lagos',
      state: 'Lagos',
      latitude: 6.4950,
      longitude: 3.3550,
      commercialHub: 'Ojuelegba / Surulere Plaza',
    ),
    NigerianTown(
      town: 'Ikorodu',
      city: 'Lagos',
      state: 'Lagos',
      latitude: 6.6194,
      longitude: 3.5105,
      commercialHub: 'Ikorodu Garage Market',
    ),
    NigerianTown(
      town: 'Alimosho',
      city: 'Lagos',
      state: 'Lagos',
      latitude: 6.6010,
      longitude: 3.2750,
      commercialHub: 'Egbeda / Ikotun Market',
    ),
    NigerianTown(
      town: 'Festac',
      city: 'Lagos',
      state: 'Lagos',
      latitude: 6.4670,
      longitude: 3.2830,
      commercialHub: 'Festac Commercial Avenue',
    ),

    // --- Ogun State ---
    NigerianTown(
      town: 'Abeokuta',
      city: 'Ogun',
      state: 'Ogun',
      latitude: 7.1557,
      longitude: 3.3451,
      commercialHub: 'Ibara / Itoku Market',
    ),
    NigerianTown(
      town: 'Sagamu',
      city: 'Ogun',
      state: 'Ogun',
      latitude: 6.8482,
      longitude: 3.6465,
      commercialHub: 'Sagamu Interchange Zone',
    ),
    NigerianTown(
      town: 'Ijebu Ode',
      city: 'Ogun',
      state: 'Ogun',
      latitude: 6.8206,
      longitude: 3.9206,
      commercialHub: 'Oyingbo Market Ijebu',
    ),
    NigerianTown(
      town: 'Ota',
      city: 'Ogun',
      state: 'Ogun',
      latitude: 6.6908,
      longitude: 3.2354,
      commercialHub: 'Sango Ota Market',
    ),

    // --- Osun State ---
    NigerianTown(
      town: 'Osogbo',
      city: 'Osun',
      state: 'Osun',
      latitude: 7.7827,
      longitude: 4.5418,
      commercialHub: 'Alekuwodo / Oja Oba',
    ),
    NigerianTown(
      town: 'Ile-Ife',
      city: 'Osun',
      state: 'Osun',
      latitude: 7.4833,
      longitude: 4.5667,
      commercialHub: 'Mayfair / Oja Titun',
    ),

    // --- Ondo & Ekiti ---
    NigerianTown(
      town: 'Akure',
      city: 'Ondo',
      state: 'Ondo',
      latitude: 7.2571,
      longitude: 5.2058,
      commercialHub: 'Oja Oba Market Akure',
    ),
    NigerianTown(
      town: 'Ondo Town',
      city: 'Ondo',
      state: 'Ondo',
      latitude: 7.0910,
      longitude: 4.8360,
      commercialHub: 'Yaba / Moferere Market',
    ),
    NigerianTown(
      town: 'Ado-Ekiti',
      city: 'Ekiti',
      state: 'Ekiti',
      latitude: 7.6210,
      longitude: 5.2210,
      commercialHub: 'Oja Bisi Market',
    ),

    // --- Kwara & Kogi ---
    NigerianTown(
      town: 'Ilorin',
      city: 'Kwara',
      state: 'Kwara',
      latitude: 8.4966,
      longitude: 4.5421,
      commercialHub: 'Post Office / Taiwo Isale',
    ),
    NigerianTown(
      town: 'Lokoja',
      city: 'Kogi',
      state: 'Kogi',
      latitude: 7.8023,
      longitude: 6.7430,
      commercialHub: 'International Market Lokoja',
    ),

    // --- South-South (Edo, Delta, Rivers, Bayelsa, Akwa Ibom, Cross River) ---
    NigerianTown(
      town: 'Benin City',
      city: 'Edo',
      state: 'Edo',
      latitude: 6.3350,
      longitude: 5.6037,
      commercialHub: 'Ring Road / Oba Market',
    ),
    NigerianTown(
      town: 'Warri',
      city: 'Delta',
      state: 'Delta',
      latitude: 5.5442,
      longitude: 5.7603,
      commercialHub: 'Effurun Roundabout / Main Market',
    ),
    NigerianTown(
      town: 'Asaba',
      city: 'Delta',
      state: 'Delta',
      latitude: 6.1989,
      longitude: 6.7294,
      commercialHub: 'Nnebisi Road Market',
    ),
    NigerianTown(
      town: 'Port Harcourt',
      city: 'Rivers',
      state: 'Rivers',
      latitude: 4.8156,
      longitude: 7.0498,
      commercialHub: 'Mile 1 Market / Oil Mill',
    ),
    NigerianTown(
      town: 'Yenagoa',
      city: 'Bayelsa',
      state: 'Bayelsa',
      latitude: 4.9267,
      longitude: 6.2676,
      commercialHub: 'Swali Market',
    ),
    NigerianTown(
      town: 'Uyo',
      city: 'Akwa Ibom',
      state: 'Akwa Ibom',
      latitude: 5.0377,
      longitude: 7.9128,
      commercialHub: 'Itam Market / Ibom Plaza',
    ),
    NigerianTown(
      town: 'Calabar',
      city: 'Cross River',
      state: 'Cross River',
      latitude: 4.9589,
      longitude: 8.3269,
      commercialHub: 'Watt Market',
    ),

    // --- South-East (Anambra, Enugu, Imo, Abia, Ebonyi) ---
    NigerianTown(
      town: 'Onitsha',
      city: 'Anambra',
      state: 'Anambra',
      latitude: 6.1498,
      longitude: 6.7858,
      commercialHub: 'Onitsha Main Market',
    ),
    NigerianTown(
      town: 'Awka',
      city: 'Anambra',
      state: 'Anambra',
      latitude: 6.2107,
      longitude: 7.0720,
      commercialHub: 'Eke Awka Market',
    ),
    NigerianTown(
      town: 'Enugu',
      city: 'Enugu',
      state: 'Enugu',
      latitude: 6.4584,
      longitude: 7.5464,
      commercialHub: 'Ogbete Main Market',
    ),
    NigerianTown(
      town: 'Owerri',
      city: 'Imo',
      state: 'Imo',
      latitude: 5.4836,
      longitude: 7.0333,
      commercialHub: 'Douglas / Relief Market',
    ),
    NigerianTown(
      town: 'Aba',
      city: 'Abia',
      state: 'Abia',
      latitude: 5.1065,
      longitude: 7.3667,
      commercialHub: 'Ariaria International Market',
    ),
    NigerianTown(
      town: 'Abakaliki',
      city: 'Ebonyi',
      state: 'Ebonyi',
      latitude: 6.3249,
      longitude: 8.1137,
      commercialHub: 'Margret Umahi International Market',
    ),

    // --- FCT & North-Central ---
    NigerianTown(
      town: 'Wuse 2',
      city: 'Abuja',
      state: 'FCT',
      latitude: 9.0765,
      longitude: 7.3986,
      commercialHub: 'Wuse 2 Market Zone',
    ),
    NigerianTown(
      town: 'Garki',
      city: 'Abuja',
      state: 'FCT',
      latitude: 9.0300,
      longitude: 7.4900,
      commercialHub: 'Garki Area 1 Market',
    ),
    NigerianTown(
      town: 'Kubwa',
      city: 'Abuja',
      state: 'FCT',
      latitude: 9.1500,
      longitude: 7.3300,
      commercialHub: 'Kubwa Village Market',
    ),
    NigerianTown(
      town: 'Jos',
      city: 'Plateau',
      state: 'Plateau',
      latitude: 9.8965,
      longitude: 8.8583,
      commercialHub: 'Terminus Commercial Hub',
    ),
    NigerianTown(
      town: 'Makurdi',
      city: 'Benue',
      state: 'Benue',
      latitude: 7.7306,
      longitude: 8.5211,
      commercialHub: 'Wurukum Modern Market',
    ),
    NigerianTown(
      town: 'Minna',
      city: 'Niger',
      state: 'Niger',
      latitude: 9.6139,
      longitude: 6.5569,
      commercialHub: 'Central Market Minna',
    ),

    // --- North-West & North-East ---
    NigerianTown(
      town: 'Kano',
      city: 'Kano',
      state: 'Kano',
      latitude: 12.0022,
      longitude: 8.5920,
      commercialHub: 'Sabon Gari / Kurmi Market',
    ),
    NigerianTown(
      town: 'Kaduna',
      city: 'Kaduna',
      state: 'Kaduna',
      latitude: 10.5222,
      longitude: 7.4383,
      commercialHub: 'Kaduna Central Market',
    ),
    NigerianTown(
      town: 'Zaria',
      city: 'Kaduna',
      state: 'Kaduna',
      latitude: 11.0855,
      longitude: 7.7199,
      commercialHub: 'Sabon Gari Market Zaria',
    ),
    NigerianTown(
      town: 'Sokoto',
      city: 'Sokoto',
      state: 'Sokoto',
      latitude: 13.0627,
      longitude: 5.2339,
      commercialHub: 'Sokoto Central Market',
    ),
    NigerianTown(
      town: 'Maiduguri',
      city: 'Borno',
      state: 'Borno',
      latitude: 11.8333,
      longitude: 13.1500,
      commercialHub: 'Monday Market Maiduguri',
    ),
  ];

  // Coordinates of recognized markets/merchants
  static const Map<String, GeoPoint> knownMarketCoordinates = {
    'Market A': GeoPoint(
      latitude: 6.4950,
      longitude: 3.3780,
      label: 'Market A (Oyingbo)',
      city: 'Lagos',
      town: 'Oyingbo',
    ),
    'Market B': GeoPoint(
      latitude: 6.5150,
      longitude: 3.3640,
      label: 'Market B (Tejuosho)',
      city: 'Lagos',
      town: 'Yaba',
    ),
    'Market C': GeoPoint(
      latitude: 6.6020,
      longitude: 3.3900,
      label: 'Market C (Mile 12)',
      city: 'Lagos',
      town: 'Mile 12',
    ),
    'MedPlus Pharmacy': GeoPoint(
      latitude: 6.5200,
      longitude: 3.3750,
      label: 'MedPlus Pharmacy',
      city: 'Lagos',
      town: 'Yaba',
    ),
    'GIG Logistics': GeoPoint(
      latitude: 6.5100,
      longitude: 3.3700,
      label: 'GIG Logistics Hub',
      city: 'Lagos',
      town: 'Yaba',
    ),
    'Pharmacy Plus': GeoPoint(
      latitude: 6.5180,
      longitude: 3.3720,
      label: 'Pharmacy Plus',
      city: 'Lagos',
      town: 'Yaba',
    ),
    'TechHub Dugbe': GeoPoint(
      latitude: 7.3876,
      longitude: 3.8767,
      label: 'TechHub Dugbe',
      city: 'Ibadan',
      town: 'Dugbe',
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

  /// Resolve coordinates directly into a town name
  static Future<String> resolveTown(double latitude, double longitude) async {
    final point = await _resolveLiveGeoPoint(latitude: latitude, longitude: longitude);
    return point.displayTown;
  }

  /// Resolve coordinates into a complete GeoPoint with town and city
  static Future<GeoPoint> resolveLocation(double latitude, double longitude) async {
    return await _resolveLiveGeoPoint(latitude: latitude, longitude: longitude);
  }

  /// Obtain the live device GPS position via Geolocator or IP fallback,
  /// resolved to the user's actual town rather than raw coordinates.
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

  /// Fallback: Geolocation via IP address using secure HTTPS services
  static Future<GeoPoint?> _getIpBasedLocation() async {
    // 1. Try ipwho.is (fast HTTPS, returns city, region, lat, lon)
    try {
      final url = Uri.parse('https://ipwho.is/');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final lat = (data['latitude'] as num).toDouble();
          final lon = (data['longitude'] as num).toDouble();
          final rawTown = (data['city'] as String?)?.trim() ?? '';
          final region = (data['region'] as String?)?.trim() ?? '';
          final town = _cleanDiacritics(rawTown);
          final city = region.isNotEmpty ? _cleanDiacritics(region) : (town.isNotEmpty ? town : 'Local Area');
          final displayTown = town.isNotEmpty ? town : city;

          final label = (region.isNotEmpty && region != displayTown)
              ? 'Live: $displayTown, $region'
              : 'Live: $displayTown';

          return GeoPoint(
            latitude: lat,
            longitude: lon,
            label: label,
            city: city,
            town: displayTown,
            isDeviceLocation: true,
          );
        }
      }
    } catch (_) {}

    // 2. Fallback to ipapi.co (HTTPS)
    try {
      final url = Uri.parse('https://ipapi.co/json/');
      final response = await http.get(
        url,
        headers: {'User-Agent': 'SmartMoveApp/1.0 (contact@smartmove.app)'},
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lat = (data['latitude'] as num).toDouble();
        final lon = (data['longitude'] as num).toDouble();
        final rawTown = (data['city'] as String?)?.trim() ?? '';
        final region = (data['region'] as String?)?.trim() ?? '';
        final town = _cleanDiacritics(rawTown);
        final city = region.isNotEmpty ? _cleanDiacritics(region) : (town.isNotEmpty ? town : 'Local Area');
        final displayTown = town.isNotEmpty ? town : city;

        final label = (region.isNotEmpty && region != displayTown)
            ? 'Live: $displayTown, $region'
            : 'Live: $displayTown';

        return GeoPoint(
          latitude: lat,
          longitude: lon,
          label: label,
          city: city,
          town: displayTown,
          isDeviceLocation: true,
        );
      }
    } catch (_) {}

    return null;
  }

  /// Resolve coordinates into human-readable real town and city name,
  /// guaranteeing that raw coordinates are NEVER returned as the location label.
  static Future<GeoPoint> _resolveLiveGeoPoint({
    required double latitude,
    required double longitude,
  }) async {
    // 1. Attempt reverse geocoding via OpenStreetMap Nominatim
    try {
      final reverse = await reverseGeocode(latitude, longitude);
      if (reverse != null) {
        final town = reverse['town'] ?? reverse['city'] ?? 'Local Area';
        final city = reverse['city'] ?? 'Local Area';
        return GeoPoint(
          latitude: latitude,
          longitude: longitude,
          label: reverse['label'] ?? 'Live: $town, $city',
          city: city,
          town: town,
          isDeviceLocation: true,
        );
      }
    } catch (_) {}

    // 2. Offline / Connectivity Fallback: Resolve nearest town from Nigerian directory
    final closest = findClosestTown(latitude, longitude);
    final distanceToTown = calculateDistanceKm(
      lat1: latitude,
      lon1: longitude,
      lat2: closest.latitude,
      lon2: closest.longitude,
    );

    final String label;
    if (distanceToTown <= 15.0) {
      label = 'Live: ${closest.town}, ${closest.city}';
    } else {
      label = 'Live: Near ${closest.town}, ${closest.city}';
    }

    return GeoPoint(
      latitude: latitude,
      longitude: longitude,
      label: label,
      city: closest.city,
      town: closest.town,
      isDeviceLocation: true,
    );
  }

  /// Reverse geocode coordinates to human-readable neighborhood/town/city
  /// with Nigerian LGA recognition and diacritic normalization.
  static Future<Map<String, String>?> reverseGeocode(
    double lat,
    double lon,
  ) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'SmartMoveApp/1.0 (contact@smartmove.app)'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final suburb = address['suburb']?.toString() ??
            address['neighbourhood']?.toString() ??
            address['quarter']?.toString() ??
            address['residential']?.toString();

        final rawTown = address['town']?.toString() ??
            address['city']?.toString() ??
            address['village']?.toString() ??
            address['hamlet']?.toString() ??
            address['municipality']?.toString();

        final county = address['county']?.toString() ??
            address['city_district']?.toString() ??
            address['district']?.toString();

        final state = address['state']?.toString() ??
            address['state_district']?.toString();

        final displayName = data['display_name']?.toString() ?? '';

        // Resolve town and city using Nigerian LGA and hierarchy mappings
        final resolved = _extractTownAndCity(
          suburb: suburb,
          rawTown: rawTown,
          county: county,
          state: state,
          displayName: displayName,
          latitude: lat,
          longitude: lon,
        );

        final town = resolved['town']!;
        final city = resolved['city']!;

        final String label;
        if (town != city && town.isNotEmpty && city.isNotEmpty) {
          label = 'Live: $town, $city';
        } else {
          label = 'Live: $town';
        }

        return {
          'town': town,
          'city': city,
          'label': label,
        };
      }
    } catch (_) {}
    return null;
  }

  /// Helper to extract clean town and city from geocoded address components
  static Map<String, String> _extractTownAndCity({
    String? suburb,
    String? rawTown,
    String? county,
    String? state,
    required String displayName,
    required double latitude,
    required double longitude,
  }) {
    String cleanSuburb = suburb != null ? _cleanDiacritics(suburb) : '';
    String cleanTown = rawTown != null ? _cleanDiacritics(rawTown) : '';
    String cleanCounty = county != null ? _cleanDiacritics(county) : '';
    String cleanState = state != null ? _cleanDiacritics(state) : '';

    // Nigerian LGA specific corrections (e.g. Ibadan, Lagos, Abuja, Abeokuta)
    final lgaLower = cleanCounty.toLowerCase();
    final displayLower = displayName.toLowerCase();

    // Check Ibadan LGAs
    if (displayLower.contains('ibadan') ||
        lgaLower.contains('ibadan') ||
        lgaLower == 'ona ara' ||
        lgaLower == 'oluyole' ||
        lgaLower == 'egbeda' ||
        lgaLower == 'akinyele' ||
        lgaLower == 'lagelu' ||
        lgaLower == 'ido') {
      final town = cleanSuburb.isNotEmpty
          ? cleanSuburb
          : (cleanTown.isNotEmpty && cleanTown.toLowerCase() != 'ibadan'
              ? cleanTown
              : (cleanCounty.isNotEmpty ? cleanCounty : 'Ibadan Central'));
      return {
        'town': town,
        'city': 'Ibadan',
      };
    }

    // Check Lagos LGAs
    if (displayLower.contains('lagos') ||
        lgaLower.contains('lagos') ||
        lgaLower == 'ikeja' ||
        lgaLower == 'alimosho' ||
        lgaLower == 'surulere' ||
        lgaLower == 'eti-osa' ||
        lgaLower == 'yaba' ||
        lgaLower == 'mushin' ||
        lgaLower == 'oshodi-isolo' ||
        lgaLower == 'kosofe' ||
        lgaLower == 'somolu' ||
        lgaLower == 'amuwo-odofin' ||
        lgaLower == 'ajeromi-ifelodun' ||
        lgaLower == 'ikorodu' ||
        lgaLower == 'badagry' ||
        lgaLower == 'epe') {
      final town = cleanSuburb.isNotEmpty
          ? cleanSuburb
          : (cleanTown.isNotEmpty && cleanTown.toLowerCase() != 'lagos'
              ? cleanTown
              : (cleanCounty.isNotEmpty ? cleanCounty : 'Lagos Mainland'));
      return {
        'town': town,
        'city': 'Lagos',
      };
    }

    // Check Ogun LGAs (Abeokuta, Sagamu, Ijebu)
    if (displayLower.contains('abeokuta') ||
        lgaLower.contains('abeokuta') ||
        lgaLower == 'odeda' ||
        lgaLower == 'obafemi owode') {
      return {
        'town': cleanSuburb.isNotEmpty ? cleanSuburb : 'Abeokuta',
        'city': 'Ogun',
      };
    }

    // Check Abuja / FCT
    if (displayLower.contains('abuja') ||
        displayLower.contains('federal capital territory') ||
        cleanState.toLowerCase().contains('federal capital') ||
        lgaLower.contains('municipal area council') ||
        lgaLower == 'bwari' ||
        lgaLower == 'gwagwalada') {
      return {
        'town': cleanSuburb.isNotEmpty
            ? cleanSuburb
            : (cleanTown.isNotEmpty ? cleanTown : 'Wuse / Central'),
        'city': 'Abuja',
      };
    }

    // Generic fallback extraction
    String finalTown = cleanSuburb.isNotEmpty
        ? cleanSuburb
        : (cleanTown.isNotEmpty
            ? cleanTown
            : (cleanCounty.isNotEmpty ? cleanCounty : ''));

    String finalCity = cleanTown.isNotEmpty && cleanTown != finalTown
        ? cleanTown
        : (cleanState.isNotEmpty
            ? cleanState
            : (cleanCounty.isNotEmpty ? cleanCounty : 'Local Area'));

    if (finalTown.isEmpty) {
      if (displayName.isNotEmpty) {
        final parts = displayName.split(',').map((p) => p.trim()).toList();
        if (parts.isNotEmpty) {
          finalTown = _cleanDiacritics(parts.first);
        }
      }
    }

    if (finalTown.isEmpty) {
      final fallbackTown = findClosestTown(latitude, longitude);
      finalTown = fallbackTown.town;
      finalCity = fallbackTown.city;
    }

    return {
      'town': finalTown,
      'city': finalCity,
    };
  }

  /// Normalize diacritics (e.g. Ìbàdàn -> Ibadan)
  static String _cleanDiacritics(String str) {
    return str
        .replaceAll(RegExp(r'[ÌíìÍîï]'), 'i')
        .replaceAll(RegExp(r'[àáâãäåÀÁÂÃÄÅ]'), 'a')
        .replaceAll(RegExp(r'[èéêëÈÉÊË]'), 'e')
        .replaceAll(RegExp(r'[òóôõöÒÓÔÕÖ]'), 'o')
        .replaceAll(RegExp(r'[ùúûüÙÚÛÜ]'), 'u')
        .replaceAll(RegExp(r'[ñÑ]'), 'n')
        .trim();
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

  /// Finds the closest Nigerian town from comprehensive directory
  static NigerianTown findClosestTown(double lat, double lon) {
    NigerianTown closest = nigerianTownDirectory.first;
    double minDistance = double.infinity;

    for (final town in nigerianTownDirectory) {
      final d = calculateDistanceKm(
        lat1: lat,
        lon1: lon,
        lat2: town.latitude,
        lon2: town.longitude,
      );
      if (d < minDistance) {
        minDistance = d;
        closest = town;
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

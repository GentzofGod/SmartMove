import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartmove/core/services/location_service.dart';
import 'package:smartmove/core/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService & GeoPoint Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. GeoPoint serialization to and from JSON preserves all fields', () {
      const original = GeoPoint(
        latitude: 6.6018,
        longitude: 3.3515,
        label: 'Live: Ikeja Commercial Hub',
        city: 'Ikeja',
        isDeviceLocation: true,
      );

      final json = original.toJson();
      final reconstructed = GeoPoint.fromJson(json);

      expect(reconstructed.latitude, original.latitude);
      expect(reconstructed.longitude, original.longitude);
      expect(reconstructed.label, original.label);
      expect(reconstructed.city, original.city);
      expect(reconstructed.isDeviceLocation, true);
      expect(reconstructed, equals(original));
    });

    test('2. defaultHub matches the primary commercial hub in availableHubs', () {
      expect(LocationService.defaultHub.label, LocationService.availableHubs.first.label);
      expect(LocationService.defaultHub.latitude, LocationService.availableHubs.first.latitude);
      expect(LocationService.defaultHub.longitude, LocationService.availableHubs.first.longitude);
      expect(LocationService.defaultHub.city, LocationService.availableHubs.first.city);
    });

    test('3. findClosestHub accurately selects nearest regional commercial center', () {
      // Near Bodija Market in Ibadan (7.43, 3.90)
      final closestIbadan = LocationService.findClosestHub(7.4350, 3.9060);
      expect(closestIbadan.city, 'Ibadan');
      expect(closestIbadan.label.contains('Bodija'), true);

      // Near Wuse 2 in Abuja (9.07, 7.39)
      final closestAbuja = LocationService.findClosestHub(9.0770, 7.3990);
      expect(closestAbuja.city, 'Abuja');
      expect(closestAbuja.label.contains('Wuse 2'), true);

      // Near Ikeja in Lagos (6.60, 3.35)
      final closestLagos = LocationService.findClosestHub(6.6020, 3.3520);
      expect(closestLagos.city, 'Lagos');
      expect(closestLagos.label.contains('Ikeja'), true);
    });

    test('4. calculateDistanceKm computes sensible Haversine distances', () {
      // Distance from Lagos Mainland (6.5244, 3.3792) to Ikeja (6.6018, 3.3515) is ~9km
      final dist = LocationService.calculateDistanceKm(
        lat1: 6.5244,
        lon1: 3.3792,
        lat2: 6.6018,
        lon2: 3.3515,
      );

      expect(dist > 8.0 && dist < 12.0, true);

      // Distance to self should be 0.0
      final zeroDist = LocationService.calculateDistanceKm(
        lat1: 6.5244,
        lon1: 3.3792,
        lat2: 6.5244,
        lon2: 3.3792,
      );
      expect(zeroDist, 0.0);
    });

    test('5. estimateTransportFare rounds correctly to 50 Naira intervals', () {
      final fareShort = LocationService.estimateTransportFare(0.8);
      expect(fareShort, 500.0); // Base minimum fare

      final fareLong = LocationService.estimateTransportFare(5.0);
      // 500 + (4.0 * 150) = 1100.0
      expect(fareLong, 1100.0);
    });

    test('6. LocationService persists and restores GeoPoint across sessions', () async {
      const customPoint = GeoPoint(
        latitude: 6.4531,
        longitude: 3.5283,
        label: 'Live: Lekki Phase 1',
        city: 'Lekki',
        isDeviceLocation: true,
      );

      await LocationService.persistLocation(customPoint);
      final restored = await LocationService.restorePersistedLocation();

      expect(restored, isNotNull);
      expect(restored!.label, 'Live: Lekki Phase 1');
      expect(restored.city, 'Lekki');
      expect(restored.isDeviceLocation, true);
    });

    test('7. LocationNotifier loads persisted location and updates correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state is defaultHub
      final initial = container.read(locationProvider);
      expect(initial.label, LocationService.defaultHub.label);

      // Set new location
      const newLoc = GeoPoint(
        latitude: 9.0765,
        longitude: 7.3986,
        label: 'Live: Wuse 2, Abuja',
        city: 'Abuja',
        isDeviceLocation: true,
      );

      container.read(locationProvider.notifier).setLocation(newLoc);
      expect(container.read(locationProvider).label, 'Live: Wuse 2, Abuja');
      expect(container.read(locationProvider).isDeviceLocation, true);

      // Verify it was persisted to storage
      final stored = await LocationService.restorePersistedLocation();
      expect(stored?.label, 'Live: Wuse 2, Abuja');
      expect(stored?.isDeviceLocation, true);
    });

    test('8. GeoPoint displayTown and displayLocation never expose raw coordinates', () {
      // Clean point with town and city
      const pointA = GeoPoint(
        latitude: 7.3876,
        longitude: 3.8767,
        label: 'Live: Dugbe, Ibadan',
        city: 'Ibadan',
        town: 'Dugbe',
        isDeviceLocation: true,
      );
      expect(pointA.displayTown, 'Dugbe');
      expect(pointA.displayLocation, 'Dugbe, Ibadan');

      // Point where town == city
      const pointB = GeoPoint(
        latitude: 7.1557,
        longitude: 3.3451,
        label: 'Live: Abeokuta',
        city: 'Abeokuta',
        town: 'Abeokuta',
      );
      expect(pointB.displayTown, 'Abeokuta');
      expect(pointB.displayLocation, 'Abeokuta');

      // Point with coordinate string legacy label: should fallback to city, never show coords
      const pointC = GeoPoint(
        latitude: 7.3775,
        longitude: 3.9470,
        label: 'Live: (7.38, 3.95)',
        city: 'Ibadan',
      );
      expect(pointC.displayTown, 'Ibadan');
      expect(pointC.displayLocation, 'Ibadan');
      expect(pointC.displayTown.contains('('), false);
      expect(pointC.displayLocation.contains('('), false);
    });

    test('9. findClosestTown accurately resolves coordinates across Nigeria to towns', () {
      // Ibadan (Dugbe)
      final townIbadan = LocationService.findClosestTown(7.3870, 3.8760);
      expect(townIbadan.town, 'Dugbe');
      expect(townIbadan.city, 'Ibadan');

      // Abeokuta (Ogun)
      final townAbeokuta = LocationService.findClosestTown(7.1550, 3.3450);
      expect(townAbeokuta.town, 'Abeokuta');
      expect(townAbeokuta.city, 'Ogun');

      // Kano (North)
      final townKano = LocationService.findClosestTown(12.0020, 8.5910);
      expect(townKano.town, 'Kano');
      expect(townKano.city, 'Kano');

      // Port Harcourt (South)
      final townPH = LocationService.findClosestTown(4.8150, 7.0490);
      expect(townPH.town, 'Port Harcourt');
      expect(townPH.city, 'Rivers');
    });

    test('10. resolveLocation always yields human-readable town and city without raw coordinates', () async {
      // Coordinates outside central hubs (e.g. Abeokuta or outskirts of Ibadan)
      final resolved = await LocationService.resolveLocation(7.1557, 3.3451);
      expect(resolved.displayTown, isNotEmpty);
      expect(resolved.displayTown.contains('('), false);
      expect(resolved.displayLocation.contains('('), false);
      expect(resolved.label.contains('('), false);
      expect(resolved.isDeviceLocation, true);
    });
  });
}

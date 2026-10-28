import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/price_observation.dart';
import '../models/errand.dart';

class SupabaseDataService {
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get isConnected => _client != null;

  /// Fetch all active products from Cloud Supabase
  static Future<List<Product>?> fetchProducts() async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('products')
          .select()
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return null;

      return data.map((json) {
        final map = json as Map<String, dynamic>;
        return Product(
          id: map['id']?.toString() ?? 'p-unknown',
          name: map['name']?.toString() ?? '',
          category: map['category']?.toString() ?? 'Groceries',
          standardUnit: map['standard_unit']?.toString() ?? '1kg',
          lowestPrice: (map['lowest_price'] as num?)?.toDouble() ?? 0.0,
          bestSeller: map['best_seller_name']?.toString() ?? 'Local Market',
          distanceKm: 1.5,
          updateTime: 'Updated recently',
          percentageChange:
              (map['percentage_change'] as num?)?.toDouble() ?? 0.0,
          isCheapest: map['is_cheapest'] as bool? ?? false,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Fetch crowdsourced community price observations from Cloud Supabase
  static Future<List<PriceObservation>?> fetchObservations() async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('price_observations')
          .select()
          .order('created_at', ascending: false)
          .limit(30);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return null;

      return data.map((json) {
        final map = json as Map<String, dynamic>;
        final sourceStr = map['source_type']?.toString() ?? 'community_reported';
        final ObservationSource source;
        if (sourceStr == 'trader_confirmed') {
          source = ObservationSource.traderConfirmed;
        } else if (sourceStr == 'trader_provided') {
          source = ObservationSource.traderProvided;
        } else if (sourceStr == 'simulated_demo') {
          source = ObservationSource.simulatedDemo;
        } else {
          source = ObservationSource.communityReported;
        }

        DateTime timestamp = DateTime.now();
        if (map['created_at'] != null) {
          timestamp = DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
        }

        return PriceObservation(
          id: map['id']?.toString() ?? 'obs-unknown',
          productId: map['product_id']?.toString() ?? 'p-custom',
          productName: map['product_name']?.toString() ?? '',
          sellerName: map['seller_name']?.toString() ?? 'Local Vendor',
          marketLocation: map['market_location']?.toString() ?? 'Lagos',
          price: (map['price'] as num?)?.toDouble() ?? 0.0,
          unit: map['unit']?.toString() ?? '1kg',
          timestamp: timestamp,
          sourceType: source,
          submitterName: map['submitter_name']?.toString() ?? 'Community Member',
          submitterRole: map['submitter_role']?.toString() ?? 'Customer',
          isVerified: map['is_verified'] as bool? ?? false,
          notes: map['notes']?.toString(),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Insert a new price observation into Cloud Supabase
  static Future<bool> insertObservation({
    required String productName,
    required String sellerName,
    required double price,
    required String unit,
    required String submitterName,
    required String submitterRole,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final source = submitterRole == 'Trader'
          ? 'trader_confirmed'
          : 'community_reported';

      final user = client.auth.currentUser;

      await client.from('price_observations').insert({
        'product_name': productName,
        'seller_name': sellerName,
        'market_location': sellerName,
        'price': price,
        'unit': unit,
        'source_type': source,
        'submitter_id': user?.id,
        'submitter_name': submitterName,
        'submitter_role': submitterRole,
        'is_verified': submitterRole == 'Trader',
        'notes': 'Submitted via SmartMove app.',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Insert a newly planned errand into Cloud Supabase
  static Future<bool> insertErrand({
    required Errand errand,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final user = client.auth.currentUser;
      final response = await client.from('errands').insert({
        'user_id': user?.id,
        'title': errand.title,
        'location_name': errand.locationName,
        'scheduled_time': errand.scheduledTime,
        'deadline': errand.deadline,
        'priority': errand.priority.name,
        'category': errand.category,
        'is_completed': errand.isCompleted,
      }).select();

      final dynamic errandRecord = (response as List<dynamic>).firstOrNull;
      if (errandRecord != null && errand.shoppingItems.isNotEmpty) {
        final errandDbId = (errandRecord as Map<String, dynamic>)['id'];
        final shoppingRows = errand.shoppingItems.map((item) {
          return {
            'errand_id': errandDbId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit': item.unit,
            'estimated_unit_price': item.estimatedUnitPrice,
            'is_checked': item.isChecked,
          };
        }).toList();

        await client.from('shopping_items').insert(shoppingRows);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

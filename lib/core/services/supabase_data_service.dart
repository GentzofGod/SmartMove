import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/price_observation.dart';
import '../models/commodity_category.dart';
import '../models/errand.dart';
import '../models/seller_application.dart';

class SupabaseDataService {
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get isConnected => _client != null;
  static SupabaseClient? get client => _client;

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
      if (data.isEmpty) return const <Product>[];

      return data.map((json) {
        return Product.fromJson(json as Map<String, dynamic>);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Fetch all active commodity categories from Cloud Supabase
  static Future<List<CommodityCategory>?> fetchCategories() async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('commodity_categories')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const <CommodityCategory>[];

      return data.map((json) {
        return CommodityCategory.fromJson(json as Map<String, dynamic>);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Upload a new commodity or product listing (Verified Sellers & Admins)
  static Future<bool> insertProduct(Product product) async {
    final client = _client;
    if (client == null) return false;

    try {
      final user = client.auth.currentUser;
      final payload = product.toDbMap();
      if (user != null) {
        payload['created_by'] = user.id;
        payload['seller_id'] = user.id;
      }
      await client.from('products').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update an existing product listing
  static Future<bool> updateProduct(Product product) async {
    final client = _client;
    if (client == null) return false;

    try {
      final payload = product.toDbMap();
      payload['updated_at'] = DateTime.now().toIso8601String();
      await client.from('products').update(payload).eq('id', product.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete a product listing
  static Future<bool> deleteProduct(String productId) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.from('products').delete().eq('id', productId);
      return true;
    } catch (_) {
      return false;
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
      if (data.isEmpty) return const <PriceObservation>[];

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
        } else if (sourceStr == 'online_grounded') {
          source = ObservationSource.onlineGrounded;
        } else {
          source = ObservationSource.communityReported;
        }

        DateTime timestamp = DateTime.now();
        if (map['created_at'] != null) {
          timestamp = DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
        }

        final rawChannel = map['channel']?.toString() ?? 'Local Market';
        final brandOrGrade = map['brand_or_grade']?.toString();
        final inStock = map['in_stock'] as bool? ?? true;
        final standardizedUnitPrice = (map['standardized_unit_price'] as num?)?.toDouble();
        final baseUnit = map['base_unit']?.toString() ?? 'kg';
        final isFlagged = map['is_flagged_anomaly'] as bool? ?? false;
        final anomalyReason = map['anomaly_reason']?.toString();

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
          channel: rawChannel,
          brandOrGrade: brandOrGrade,
          inStock: inStock,
          standardizedUnitPrice: standardizedUnitPrice,
          baseUnit: baseUnit,
          isFlaggedAnomaly: isFlagged,
          anomalyReason: anomalyReason,
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
    String channel = 'Local Market',
    String? brandOrGrade,
    bool inStock = true,
    double? standardizedUnitPrice,
    String baseUnit = 'kg',
    String? marketLocation,
    String? notes,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final isTrader = submitterRole == 'Trader' || submitterRole == 'Seller';
      final isAdmin = submitterRole == 'Admin' || submitterRole == 'Administrator';
      final source = isTrader
          ? 'trader_confirmed'
          : (isAdmin ? 'independently_verified' : 'community_reported');

      final user = client.auth.currentUser;

      await client.from('price_observations').insert({
        'product_name': productName,
        'seller_name': sellerName,
        'market_location': marketLocation ?? sellerName,
        'price': price,
        'unit': unit,
        'source_type': source,
        'submitter_id': user?.id,
        'submitter_name': submitterName,
        'submitter_role': submitterRole,
        'is_verified': isTrader || isAdmin,
        'notes': notes ?? 'Submitted via SmartMove app.',
        'channel': channel,
        'brand_or_grade': brandOrGrade,
        'in_stock': inStock,
        'standardized_unit_price': standardizedUnitPrice,
        'base_unit': baseUnit,
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

  /// Fetch pending and reviewed seller applications from Cloud Supabase
  static Future<List<SellerApplication>?> fetchSellerApplications() async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('seller_applications')
          .select()
          .order('submitted_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const <SellerApplication>[];

      return data.map((json) {
        return SellerApplication.fromJson(json as Map<String, dynamic>);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Submit a seller application to Cloud Supabase
  static Future<bool> insertSellerApplication(SellerApplication app) async {
    final client = _client;
    if (client == null) return false;

    try {
      final user = client.auth.currentUser;
      final payload = app.toDbMap();
      if (user != null) {
        payload['user_id'] = user.id;
      }
      await client.from('seller_applications').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update application review status in Cloud Supabase (Admin approval / rejection)
  static Future<bool> updateSellerApplicationStatus({
    required String applicationId,
    required SellerApplicationStatus status,
    String? reason,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final reviewer = client.auth.currentUser;
      final updateData = <String, dynamic>{
        'status': status.name,
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': reviewer?.id,
      };
      if (reason != null && reason.isNotEmpty) {
        updateData['rejection_reason'] = reason;
      }

      await client
          .from('seller_applications')
          .update(updateData)
          .eq('id', applicationId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

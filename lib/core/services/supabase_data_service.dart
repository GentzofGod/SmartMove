import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/price_observation.dart';
import '../models/commodity_category.dart';
import '../models/errand.dart';
import '../models/seller_application.dart';
import '../models/trader_chat_message.dart';
import '../models/store_edit_request.dart';

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

  /// Create a new commodity category (SuperAdmin)
  static Future<CommodityCategory?> insertCategory(CommodityCategory category) async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('commodity_categories')
          .insert(category.toDbMap())
          .select()
          .maybeSingle();

      if (response != null) {
        return CommodityCategory.fromJson(response);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Update an existing category (SuperAdmin)
  static Future<bool> updateCategory(CommodityCategory category) async {
    final client = _client;
    if (client == null) return false;

    try {
      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(category.id);

      if (isUuid) {
        await client
            .from('commodity_categories')
            .update(category.toDbMap())
            .eq('id', category.id);
      } else {
        await client
            .from('commodity_categories')
            .update(category.toDbMap())
            .eq('slug', category.slug);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete a category (SuperAdmin)
  static Future<bool> deleteCategory(String categoryId, {String? slug}) async {
    final client = _client;
    if (client == null) return false;

    try {
      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(categoryId);

      if (isUuid) {
        await client.from('commodity_categories').delete().eq('id', categoryId);
      } else if (slug != null && slug.isNotEmpty) {
        await client.from('commodity_categories').delete().eq('slug', slug);
      }
      return true;
    } catch (_) {
      return false;
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

  /// Delete a product listing from Cloud Supabase
  static Future<bool> deleteProduct(String productId, {String? name}) async {
    final client = _client;
    if (client == null) return false;

    try {
      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(productId);

      if (isUuid) {
        await client.from('products').delete().eq('id', productId);
        await client.from('price_observations').delete().eq('product_id', productId);
      }
      if (name != null && name.trim().isNotEmpty) {
        final cleanName = name.trim();
        await client.from('products').delete().ilike('name', cleanName);
        await client.from('products').delete().ilike('name', '%$cleanName%');
        await client.from('price_observations').delete().ilike('product_name', cleanName);
        await client.from('price_observations').delete().ilike('product_name', '%$cleanName%');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Purges hardcoded/demo seed products (e.g. cooking oil, eggs crate) from Cloud Supabase
  static Future<void> purgeDemoSeedProducts() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('products').delete().ilike('name', '%cooking oil%');
      await client.from('products').delete().ilike('name', '%eggs (crate)%');
      await client.from('products').delete().ilike('name', 'eggs');
      await client.from('products').delete().eq('id', 'b0000000-0000-0000-0000-000000000002');
      await client.from('products').delete().eq('id', 'b0000000-0000-0000-0000-000000000004');
      await client.from('price_observations').delete().ilike('product_name', '%cooking oil%');
      await client.from('price_observations').delete().ilike('product_name', '%eggs (crate)%');
      await client.from('price_observations').delete().ilike('product_name', 'eggs');
      await client.from('price_observations').delete().eq('product_id', 'b0000000-0000-0000-0000-000000000002');
      await client.from('price_observations').delete().eq('product_id', 'b0000000-0000-0000-0000-000000000004');
    } catch (_) {}
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

        final category = map['category']?.toString() ?? 'Groceries';
        final imageUrl = map['image_url']?.toString();
        final latitude = ((map['latitude'] ?? map['lat']) as num?)?.toDouble();
        final longitude = ((map['longitude'] ?? map['lng'] ?? map['lon']) as num?)?.toDouble();

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
          category: category,
          imageUrl: imageUrl,
          isFlaggedAnomaly: isFlagged,
          anomalyReason: anomalyReason,
          latitude: latitude,
          longitude: longitude,
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
    String category = 'Groceries',
    String? imageUrl,
    double? latitude,
    double? longitude,
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

      final payload = <String, dynamic>{
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
        'category': category,
      };

      if (imageUrl != null) payload['image_url'] = imageUrl;
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      await client.from('price_observations').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update an existing price observation in Cloud Supabase (Sellers & Admins)
  static Future<bool> updateObservation({
    required String id,
    String? productName,
    double? price,
    String? unit,
    String? category,
    String? brandOrGrade,
    String? notes,
    bool? inStock,
    String? imageUrl,
    String? marketLocation,
    double? latitude,
    double? longitude,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final updateData = <String, dynamic>{
        'product_name': ?productName,
        'price': ?price,
        'unit': ?unit,
        'category': ?category,
        'brand_or_grade': ?brandOrGrade,
        'notes': ?notes,
        'in_stock': ?inStock,
        'image_url': ?imageUrl,
        'market_location': ?marketLocation,
        'latitude': ?latitude,
        'longitude': ?longitude,
      };

      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id);

      if (isUuid) {
        await client.from('price_observations').update(updateData).eq('id', id);
      } else if (productName != null) {
        await client.from('price_observations').update(updateData).eq('product_name', productName);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete a price observation from Cloud Supabase
  static Future<bool> deleteObservation(String id, {String? productName}) async {
    final client = _client;
    if (client == null) return false;

    try {
      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id);

      if (isUuid) {
        await client.from('price_observations').delete().eq('id', id);
        await client.from('products').delete().eq('id', id);
      }
      if (productName != null && productName.trim().isNotEmpty) {
        final cleanName = productName.trim();
        await client.from('price_observations').delete().ilike('product_name', cleanName);
        await client.from('price_observations').delete().ilike('product_name', '%$cleanName%');
        await client.from('products').delete().ilike('name', cleanName);
        await client.from('products').delete().ilike('name', '%$cleanName%');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle in_stock status of an observation in Cloud Supabase
  static Future<bool> toggleObservationStock(String id, bool inStock) async {
    final client = _client;
    if (client == null) return false;

    try {
      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id);

      if (isUuid) {
        await client.from('price_observations').update({'in_stock': inStock}).eq('id', id);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update observation verification flag in Cloud Supabase (Admin moderation)
  static Future<bool> verifyObservation(String id, bool isVerified) async {
    final client = _client;
    if (client == null) return false;

    try {
      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id);

      if (isUuid) {
        await client.from('price_observations').update({
          'is_verified': isVerified,
          'source_type': isVerified ? 'trader_confirmed' : 'community_reported',
        }).eq('id', id);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fetch chat / negotiation messages between buyer and seller from Supabase
  static Future<List<TraderChatMessage>?> fetchChatMessages(String conversationKey) async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('negotiation_messages')
          .select()
          .eq('conversation_key', conversationKey)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const <TraderChatMessage>[];

      return data.map((json) {
        return TraderChatMessage.fromJson(json as Map<String, dynamic>);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Fetch all customer inquiries directed to a specific seller from Supabase
  static Future<Map<String, List<TraderChatMessage>>?> fetchAllSellerInquiries(String sellerStoreName) async {
    final client = _client;
    if (client == null) return null;

    try {
      final sName = sellerStoreName.trim();
      final response = await client
          .from('negotiation_messages')
          .select()
          .ilike('conversation_key', '%$sName%')
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return const {};

      final result = <String, List<TraderChatMessage>>{};
      for (final item in data) {
        final msg = TraderChatMessage.fromJson(item as Map<String, dynamic>);
        final key = msg.conversationKey ?? sName;
        result.putIfAbsent(key, () => []).add(msg);
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Insert a chat message between buyer and seller into Supabase
  static Future<bool> sendChatMessage(
    TraderChatMessage message, {
    required String conversationKey,
    required String commodityName,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final user = client.auth.currentUser;
      final payload = <String, dynamic>{
        'conversation_key': conversationKey,
        'sender_id': user?.id ?? (message.isTrader ? 'seller-user' : 'buyer-user'),
        'sender_name': message.senderName,
        'is_trader': message.isTrader,
        'message_text': message.text,
        'proposed_price': message.proposedPrice,
        'commodity_name': commodityName,
        'created_at': message.timestamp.toIso8601String(),
      };
      await client.from('negotiation_messages').insert(payload);
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
    String? applicantEmail,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final reviewer = client.auth.currentUser;
      final updateData = <String, dynamic>{
        'status': status.name,
        'reviewed_at': DateTime.now().toIso8601String(),
        if (reviewer?.id != null) 'reviewed_by': reviewer!.id,
      };
      if (reason != null && reason.isNotEmpty) {
        updateData['rejection_reason'] = reason;
      }

      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(applicationId);

      if (isUuid) {
        await client
            .from('seller_applications')
            .update(updateData)
            .eq('id', applicationId);
      } else if (applicantEmail != null && applicantEmail.isNotEmpty) {
        await client
            .from('seller_applications')
            .update(updateData)
            .eq('applicant_email', applicantEmail.trim().toLowerCase());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Promote a user's profile to Seller/Trader upon application approval
  static Future<bool> promoteProfileToSeller({
    required String userId,
    String? email,
    required String businessName,
    required String marketHub,
    required String sellerChannel,
    String? stallLocation,
    double? latitude,
    double? longitude,
    String? phone,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final updateData = <String, dynamic>{
        'role': 'Trader',
        'seller_application_status': 'approved',
        'business_name': businessName,
        'market_hub': marketHub,
        'seller_channel': sellerChannel,
        'stall_location': ?stallLocation,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'phone': ?phone,
      };

      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(userId);

      if (isUuid) {
        await client.from('profiles').update(updateData).eq('id', userId);
      } else if (email != null && email.isNotEmpty) {
        await client.from('profiles').update(updateData).eq('email', email.trim().toLowerCase());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Demote a user's profile back to Customer upon application rejection or revocation
  static Future<bool> demoteProfileToCustomer({
    required String userId,
    String? email,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final updateData = <String, dynamic>{
        'role': 'Customer',
        'seller_application_status': 'rejected',
      };

      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(userId);

      if (isUuid) {
        await client.from('profiles').update(updateData).eq('id', userId);
      } else if (email != null && email.isNotEmpty) {
        await client.from('profiles').update(updateData).eq('email', email.trim().toLowerCase());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update an existing user/trader profile details in Cloud Supabase
  static Future<bool> updateProfile({
    required String userId,
    String? email,
    String? businessName,
    String? marketHub,
    String? sellerChannel,
    String? stallLocation,
    double? latitude,
    double? longitude,
    String? phone,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final updateData = <String, dynamic>{
        'business_name': ?businessName,
        'market_hub': ?marketHub,
        'seller_channel': ?sellerChannel,
        'stall_location': ?stallLocation,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'phone': ?phone,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(userId);

      if (isUuid) {
        await client.from('profiles').update(updateData).eq('id', userId);
      } else if (email != null && email.isNotEmpty) {
        await client.from('profiles').update(updateData).eq('email', email.trim().toLowerCase());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fetch all store edit requests from Cloud Supabase
  static Future<List<StoreEditRequest>?> fetchStoreEditRequests() async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('store_edit_requests')
          .select()
          .order('submitted_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((j) => StoreEditRequest.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Submit a store edit request to Cloud Supabase
  static Future<bool> insertStoreEditRequest(StoreEditRequest request) async {
    final client = _client;
    if (client == null) return false;

    try {
      final payload = Map<String, dynamic>.from(request.toJson());
      // Let DB generate UUID if id is local string
      if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(request.id)) {
        payload.remove('id');
      }
      await client.from('store_edit_requests').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update store edit request review status in Cloud Supabase (Admin moderation)
  static Future<bool> updateStoreEditRequestStatus({
    required String requestId,
    required String status,
    String? reviewerName,
    String? rejectionReason,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final updateData = <String, dynamic>{
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': ?reviewerName,
        'rejection_reason': ?rejectionReason,
      };

      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(requestId);

      if (isUuid) {
        await client
            .from('store_edit_requests')
            .update(updateData)
            .eq('id', requestId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

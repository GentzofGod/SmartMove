import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/price_observation.dart';
import '../models/seller_application.dart';
import '../models/store_edit_request.dart';
import '../models/commodity_category.dart';
import '../models/trader_chat_message.dart';
export '../models/trader_chat_message.dart';
export '../models/commodity_category.dart';
import '../models/errand.dart';
import '../models/itinerary_stop.dart';
import '../models/plan_candidate.dart';
import '../models/ai_proposal.dart';
import '../data/demo_seed_data.dart';
import '../services/decision_engine.dart';
import '../services/meta_ai_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/supabase_data_service.dart';
import '../services/commodity_comparison_service.dart';

// --- Products State ---
class ProductsNotifier extends Notifier<List<Product>> {
  static const _tombstoneNamesKey = 'smartmove_deleted_product_names_v1';
  static const _tombstoneIdsKey = 'smartmove_deleted_product_ids_v1';
  List<Product> _allProducts = [];
  final Set<String> _deletedProductNames = {};
  final Set<String> _deletedProductIds = {};

  @override
  List<Product> build() {
    _loadTombstonesAndLive();
    return [];
  }

  Future<void> _loadTombstonesAndLive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final names = prefs.getStringList(_tombstoneNamesKey) ?? [];
      final ids = prefs.getStringList(_tombstoneIdsKey) ?? [];
      _deletedProductNames.addAll(names.map((s) => s.trim().toLowerCase()));
      _deletedProductIds.addAll(ids);
    } catch (_) {}
    await _fetchLive();
  }

  Future<void> _persistTombstones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_tombstoneNamesKey, _deletedProductNames.toList());
      await prefs.setStringList(_tombstoneIdsKey, _deletedProductIds.toList());
    } catch (_) {}
  }

  bool _isTombstoned(Product p) {
    if (_deletedProductIds.contains(p.id)) return true;
    final clean = p.name.trim().toLowerCase();
    if (clean.isNotEmpty && _deletedProductNames.contains(clean)) return true;
    return false;
  }

  Future<void> _fetchLive() async {
    final live = await SupabaseDataService.fetchProducts();
    if (live != null) {
      _allProducts = live.where((p) => !_isTombstoned(p)).toList();
      state = _allProducts;
    }
  }

  Future<void> fetchLive() async {
    await _fetchLive();
  }

  void filterCategory(String category) {
    if (category == 'All') {
      state = _allProducts;
    } else {
      final clean = category.toLowerCase();
      state = _allProducts
          .where((p) {
            final pCat = p.category.toLowerCase();
            if (pCat == clean) return true;
            if (clean == 'food' || clean == 'groceries') {
              return pCat == 'food' ||
                  pCat == 'groceries' ||
                  pCat.contains('grain') ||
                  pCat.contains('tuber') ||
                  pCat.contains('oil');
            }
            return false;
          })
          .toList();
    }
  }

  void search(String query) {
    if (query.isEmpty) {
      state = _allProducts;
    } else {
      state = _allProducts
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  void addProduct(Product product) {
    _deletedProductIds.remove(product.id);
    _deletedProductNames.remove(product.name.trim().toLowerCase());
    _persistTombstones();
    _allProducts = [product, ..._allProducts.where((p) => p.id != product.id)];
    state = _allProducts;
    SupabaseDataService.insertProduct(product);
  }

  void updateProduct(Product updated) {
    _allProducts = [
      for (final p in _allProducts)
        if (p.id == updated.id) updated else p,
    ];
    state = _allProducts;
    SupabaseDataService.updateProduct(updated);
  }

  void deleteProduct(String productId) {
    _deletedProductIds.add(productId);
    final target = _allProducts.where((p) => p.id == productId).toList();
    if (target.isNotEmpty) {
      _deletedProductNames.add(target.first.name.trim().toLowerCase());
    }
    _persistTombstones();
    _allProducts = _allProducts.where((p) => p.id != productId).toList();
    state = _allProducts;
    SupabaseDataService.deleteProduct(
      productId,
      name: target.isNotEmpty ? target.first.name : null,
    );
  }

  void deleteProductByName(String name) {
    final clean = name.trim().toLowerCase();
    _deletedProductNames.add(clean);
    _persistTombstones();
    _allProducts = _allProducts.where((p) => p.name.trim().toLowerCase() != clean).toList();
    state = _allProducts;
    SupabaseDataService.deleteProduct('', name: name);
  }
}

final productsProvider =
    NotifierProvider<ProductsNotifier, List<Product>>(ProductsNotifier.new);

// --- Errands State ---
class ErrandsNotifier extends Notifier<List<Errand>> {
  @override
  List<Errand> build() => DemoSeedData.getInitialErrands();

  void toggleErrandCompletion(String id) {
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(isCompleted: !e.isCompleted) else e,
    ];
  }

  void addErrand(Errand newErrand) {
    state = [...state, newErrand];
    SupabaseDataService.insertErrand(errand: newErrand);
  }

  void updateShoppingItemQuantity(String errandId, String itemId, double delta) {
    state = [
      for (final e in state)
        if (e.id == errandId)
          e.copyWith(
            shoppingItems: [
              for (final item in e.shoppingItems)
                if (item.id == itemId)
                  item.copyWith(
                    quantity: (item.quantity + delta).clamp(1.0, 99.0),
                  )
                else
                  item,
            ],
          )
        else
          e,
    ];
  }
}

final errandsProvider =
    NotifierProvider<ErrandsNotifier, List<Errand>>(ErrandsNotifier.new);

// --- Itinerary / Route State ---
class ItineraryNotifier extends Notifier<List<ItineraryStop>> {
  @override
  List<ItineraryStop> build() => DemoSeedData.getInitialStops();

  void toggleStopCompletion(String id) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(isCompleted: !s.isCompleted) else s,
    ];
  }

  void updateWithPlan(PlanCandidate plan) {
    state = plan.stops;
  }
}

final itineraryProvider =
    NotifierProvider<ItineraryNotifier, List<ItineraryStop>>(
  ItineraryNotifier.new,
);

// --- Decision Lab State ---
class DecisionLabState {
  final double budget;
  final double transportCost;
  final double timeAvailableHours;
  final int maxStops;
  final double timeCostPerHour;
  final bool delayNonUrgent;
  final List<PlanCandidate> candidates;
  final String selectedPlanId;
  final String recommendationInsight;
  final List<ShoppingItem> activeItems;
  final List<Errand> activeErrands;
  final List<AiOptimizationTip> optimizationTips;

  const DecisionLabState({
    required this.budget,
    required this.transportCost,
    required this.timeAvailableHours,
    this.maxStops = 4,
    this.timeCostPerHour = 0.0,
    this.delayNonUrgent = false,
    required this.candidates,
    required this.selectedPlanId,
    required this.recommendationInsight,
    this.activeItems = const [],
    this.activeErrands = const [],
    this.optimizationTips = const [],
  });

  PlanCandidate get selectedPlan {
    if (candidates.isEmpty) {
      return const PlanCandidate(
        id: 'plan-default',
        name: 'Default Option',
        tag: 'Balanced',
        itemCost: 0,
        transportCost: 0,
        otherCost: 0,
        estimatedHours: 0,
        stopCount: 0,
        isFeasibleBudget: true,
        isFeasibleDeadline: true,
        isRecommended: true,
        satisfiedConstraints: [],
        violatedConstraints: [],
        tradeOffExplanation: 'Default option',
        stops: [],
      );
    }
    return candidates.firstWhere((p) => p.id == selectedPlanId,
        orElse: () => candidates.first);
  }

  DecisionLabState copyWith({
    double? budget,
    double? transportCost,
    double? timeAvailableHours,
    int? maxStops,
    double? timeCostPerHour,
    bool? delayNonUrgent,
    List<PlanCandidate>? candidates,
    String? selectedPlanId,
    String? recommendationInsight,
    List<ShoppingItem>? activeItems,
    List<Errand>? activeErrands,
    List<AiOptimizationTip>? optimizationTips,
  }) {
    return DecisionLabState(
      budget: budget ?? this.budget,
      transportCost: transportCost ?? this.transportCost,
      timeAvailableHours: timeAvailableHours ?? this.timeAvailableHours,
      maxStops: maxStops ?? this.maxStops,
      timeCostPerHour: timeCostPerHour ?? this.timeCostPerHour,
      delayNonUrgent: delayNonUrgent ?? this.delayNonUrgent,
      candidates: candidates ?? this.candidates,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      recommendationInsight:
          recommendationInsight ?? this.recommendationInsight,
      activeItems: activeItems ?? this.activeItems,
      activeErrands: activeErrands ?? this.activeErrands,
      optimizationTips: optimizationTips ?? this.optimizationTips,
    );
  }
}

class DecisionLabNotifier extends Notifier<DecisionLabState> {
  @override
  DecisionLabState build() {
    final initialErrands = DemoSeedData.getInitialErrands();
    final initialItems = initialErrands.isNotEmpty ? initialErrands.first.shoppingItems : <ShoppingItem>[];
    final userLocation = ref.read(locationProvider);
    final registeredTraders = ref.read(sellerApplicationsProvider);
    final observations = ref.read(communityProvider);

    // Reactively recalculate when user location changes
    ref.listen<GeoPoint>(locationProvider, (previous, next) {
      if (previous != next) {
        state = _recalculate(userLocation: next);
      }
    });

    // Reactively recalculate when seller applications change
    ref.listen<List<SellerApplication>>(sellerApplicationsProvider, (previous, next) {
      state = _recalculate(registeredTraders: next);
    });

    return _calculateState(
      budget: initialItems.isNotEmpty ? 15000.0 : 0.0,
      transportCost: 1200,
      timeHours: 3.0,
      maxStops: 4,
      timeCost: 0.0,
      delayNonUrgent: false,
      selectedId: 'plan-a',
      items: initialItems,
      errands: initialErrands,
      userLocation: userLocation,
      registeredTraders: registeredTraders,
      observations: observations,
    );
  }

  DecisionLabState _recalculate({
    double? budget,
    double? transportCost,
    double? timeHours,
    int? maxStops,
    double? timeCost,
    bool? delayNonUrgent,
    String? selectedId,
    List<ShoppingItem>? items,
    List<Errand>? errands,
    GeoPoint? userLocation,
    List<SellerApplication>? registeredTraders,
    List<PriceObservation>? observations,
  }) {
    return _calculateState(
      budget: budget ?? state.budget,
      transportCost: transportCost ?? state.transportCost,
      timeHours: timeHours ?? state.timeAvailableHours,
      maxStops: maxStops ?? state.maxStops,
      timeCost: timeCost ?? state.timeCostPerHour,
      delayNonUrgent: delayNonUrgent ?? state.delayNonUrgent,
      selectedId: selectedId ?? state.selectedPlanId,
      items: items ?? state.activeItems,
      errands: errands ?? state.activeErrands,
      userLocation: userLocation ?? ref.read(locationProvider),
      registeredTraders: registeredTraders ?? ref.read(sellerApplicationsProvider),
      observations: observations ?? ref.read(communityProvider),
    );
  }

  static DecisionLabState _calculateState({
    required double budget,
    required double transportCost,
    required double timeHours,
    required int maxStops,
    required double timeCost,
    required bool delayNonUrgent,
    required String selectedId,
    List<ShoppingItem>? items,
    List<Errand>? errands,
    GeoPoint? userLocation,
    List<SellerApplication>? registeredTraders,
    List<PriceObservation>? observations,
  }) {
    final candidatePlans = DecisionEngine.calculateCandidatePlans(
      userBudget: budget,
      baseTransportFare: transportCost,
      maxTimeHours: timeHours,
      maxStops: maxStops,
      timeCostPerHour: timeCost,
      delayNonUrgent: delayNonUrgent,
      items: items,
      errands: errands,
      userLocation: userLocation,
      registeredTraders: registeredTraders,
      observations: observations,
    );

    final insight = DecisionEngine.generateRecommendationInsight(
      budget: budget,
      transportCost: transportCost,
      timeAvailable: timeHours,
      candidates: candidatePlans,
      errands: errands,
    );

    // Meta AI generates proactive optimization tips to ease user planning
    const aiService = MetaAiService();
    final tips = aiService.generateOptimizationTips(
      currentPlans: candidatePlans,
      currentBudget: budget,
      currentTransport: transportCost,
      items: items ?? [],
      errands: errands ?? [],
    );

    return DecisionLabState(
      budget: budget,
      transportCost: transportCost,
      timeAvailableHours: timeHours,
      maxStops: maxStops,
      timeCostPerHour: timeCost,
      delayNonUrgent: delayNonUrgent,
      candidates: candidatePlans,
      selectedPlanId: selectedId,
      recommendationInsight: insight,
      activeItems: items ?? [],
      activeErrands: errands ?? [],
      optimizationTips: tips,
    );
  }

  void setPlanContext({
    required List<ShoppingItem> items,
    List<Errand>? errands,
    double? budget,
  }) {
    state = _recalculate(
      budget: budget ?? state.budget,
      items: items,
      errands: errands ?? state.activeErrands,
    );
  }

  void addShoppingItem(ShoppingItem item) {
    final updated = [...state.activeItems, item];
    state = _recalculate(
      budget: state.budget > 0 ? state.budget : (updated.fold(0.0, (sum, i) => sum + i.totalEstimatedCost) * 1.25).roundToDouble(),
      items: updated,
    );
  }

  void removeShoppingItem(String itemId) {
    final updated = state.activeItems.where((i) => i.id != itemId).toList();
    state = _recalculate(items: updated);
  }

  void updateItemQuantity(String itemId, double newQuantity) {
    if (newQuantity <= 0) {
      removeShoppingItem(itemId);
      return;
    }
    final updated = state.activeItems.map((item) {
      if (item.id == itemId) {
        return item.copyWith(quantity: newQuantity);
      }
      return item;
    }).toList();
    state = _recalculate(items: updated);
  }

  void toggleItemPriority(String itemId) {
    final updated = state.activeItems.map((item) {
      if (item.id == itemId) {
        final newPriority = item.priority == CommodityPriority.essential
            ? CommodityPriority.low
            : CommodityPriority.essential;
        return item.copyWith(priority: newPriority);
      }
      return item;
    }).toList();
    state = _recalculate(items: updated);
  }

  void clearCart() {
    state = _recalculate(
      selectedId: 'plan-a',
      items: const <ShoppingItem>[],
    );
  }

  void applyAiCommand(AiCommandExecutionResult result) {
    var newBudget = result.updatedBudget ?? state.budget;
    var newTransport = result.updatedTransport ?? state.transportCost;
    var newHours = result.updatedTimeHours ?? state.timeAvailableHours;
    var newStops = result.updatedMaxStops ?? state.maxStops;
    var newDelay = result.updatedDelayNonUrgent ?? state.delayNonUrgent;
    var newSelectedId = result.selectedPlanId ?? state.selectedPlanId;
    var items = List<ShoppingItem>.from(state.activeItems);
    var errands = List<Errand>.from(state.activeErrands);

    if (result.addedItem != null) {
      items.add(result.addedItem!);
    }
    if (result.removedItemId != null) {
      items.removeWhere((i) => i.id == result.removedItemId);
    }
    if (result.addedErrand != null) {
      errands.add(result.addedErrand!);
    }

    state = _recalculate(
      budget: newBudget,
      transportCost: newTransport,
      timeHours: newHours,
      maxStops: newStops,
      delayNonUrgent: newDelay,
      selectedId: newSelectedId,
      items: items,
      errands: errands,
    );
  }

  void updateBudget(double newBudget) {
    state = _recalculate(budget: newBudget);
  }

  void updateTransport(double newTransport) {
    state = _recalculate(transportCost: newTransport);
  }

  void updateTimeAvailable(double newHours) {
    state = _recalculate(timeHours: newHours);
  }

  void updateMaxStops(int newStops) {
    state = _recalculate(maxStops: newStops);
  }

  void updateTimeCostPerHour(double newCost) {
    state = _recalculate(timeCost: newCost);
  }

  void toggleDelayNonUrgent(bool delay) {
    state = _recalculate(delayNonUrgent: delay);
  }

  void selectPlan(String planId) {
    state = state.copyWith(selectedPlanId: planId);
  }
}

final decisionLabProvider =
    NotifierProvider<DecisionLabNotifier, DecisionLabState>(
  DecisionLabNotifier.new,
);

// --- Categories State ---
class CategoriesNotifier extends Notifier<List<CommodityCategory>> {
  static const _cacheKey = 'smartmove_categories_cache_v2';

  @override
  List<CommodityCategory> build() {
    _loadFromCacheAndLive();
    return _defaultCategories;
  }

  static const List<CommodityCategory> _defaultCategories = [
    CommodityCategory(
      id: 'cat-food',
      name: 'Food',
      slug: 'food',
      iconName: 'restaurant_outlined',
      description: 'Groceries, grains, tubers, oils, seasonings, and cooking items',
      displayOrder: 1,
    ),
    CommodityCategory(
      id: 'cat-electronics',
      name: 'Electronics',
      slug: 'electronics',
      iconName: 'electrical_services_outlined',
      description: 'Home appliances, gadgets, spares, and hardware',
      displayOrder: 2,
    ),
    CommodityCategory(
      id: 'cat-pharmacy',
      name: 'Pharmacy',
      slug: 'pharmacy',
      iconName: 'medication_outlined',
      description: 'Healthcare, medicines, OTC drugs, and hygiene',
      displayOrder: 3,
    ),
    CommodityCategory(
      id: 'cat-others',
      name: 'Others',
      slug: 'others',
      iconName: 'more_horiz_outlined',
      description: 'Household items, clothing, and general commodities',
      displayOrder: 4,
    ),
  ];

  Future<void> _loadFromCacheAndLive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as List<dynamic>;
        if (decoded.isNotEmpty) {
          final loaded = decoded
              .map((j) => CommodityCategory.fromJson(j as Map<String, dynamic>))
              .map((c) {
                final lower = c.name.toLowerCase();
                if (lower == 'groceries' ||
                    lower.contains('grain') ||
                    lower.contains('tuber') ||
                    lower.contains('oil')) {
                  return c.copyWith(
                    name: 'Food',
                    slug: 'food',
                    description:
                        'Groceries, grains, tubers, oils, seasonings, and cooking items',
                    iconName: 'restaurant_outlined',
                  );
                }
                return c;
              })
              .toList();
          final seen = <String>{};
          state = loaded.where((c) => seen.add(c.name.toLowerCase())).toList();
        }
      }
    } catch (_) {}

    final live = await SupabaseDataService.fetchCategories();
    if (live != null && live.isNotEmpty) {
      final consolidated = live.map((c) {
        final lower = c.name.toLowerCase();
        if (lower == 'groceries' ||
            lower.contains('grain') ||
            lower.contains('tuber') ||
            lower.contains('oil')) {
          return c.copyWith(
            name: 'Food',
            slug: 'food',
            description:
                'Groceries, grains, tubers, oils, seasonings, and cooking items',
            iconName: 'restaurant_outlined',
          );
        }
        return c;
      }).toList();
      final seen = <String>{};
      final cleanLive =
          consolidated.where((c) => seen.add(c.name.toLowerCase())).toList();
      state = cleanLive;
      _persist(cleanLive);
    }
  }

  Future<void> fetchLive() async {
    final live = await SupabaseDataService.fetchCategories();
    if (live != null && live.isNotEmpty) {
      final consolidated = live.map((c) {
        final lower = c.name.toLowerCase();
        if (lower == 'groceries' ||
            lower.contains('grain') ||
            lower.contains('tuber') ||
            lower.contains('oil')) {
          return c.copyWith(
            name: 'Food',
            slug: 'food',
            description:
                'Groceries, grains, tubers, oils, seasonings, and cooking items',
            iconName: 'restaurant_outlined',
          );
        }
        return c;
      }).toList();
      final seen = <String>{};
      final cleanLive =
          consolidated.where((c) => seen.add(c.name.toLowerCase())).toList();
      state = cleanLive;
      _persist(cleanLive);
    }
  }

  Future<void> _persist(List<CommodityCategory> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(categories.map((c) => c.toJson()).toList());
      await prefs.setString(_cacheKey, jsonStr);
    } catch (_) {}
  }

  void addCategory({
    required String name,
    String? description,
    String? iconName,
  }) async {
    final slug = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final tempId = 'cat-${DateTime.now().millisecondsSinceEpoch}';
    final newCat = CommodityCategory(
      id: tempId,
      name: name.trim(),
      slug: slug,
      description: description?.trim() ?? 'Managed market category',
      iconName: iconName ?? 'inventory_2_outlined',
      displayOrder: state.length + 1,
      isActive: true,
    );
    state = [...state, newCat];
    _persist(state);

    final inserted = await SupabaseDataService.insertCategory(newCat);
    if (inserted != null) {
      state = [
        for (final c in state)
          if (c.slug == slug || c.id == tempId) inserted else c,
      ];
      _persist(state);
    }
  }

  void updateCategory({
    required String id,
    required String name,
    String? description,
    String? iconName,
    bool? isActive,
  }) {
    state = [
      for (final cat in state)
        if (cat.id == id)
          cat.copyWith(
            name: name.trim(),
            description: description?.trim() ?? cat.description,
            iconName: iconName ?? cat.iconName,
            isActive: isActive ?? cat.isActive,
          )
        else
          cat,
    ];
    _persist(state);
    final updated = state.firstWhere((c) => c.id == id);
    SupabaseDataService.updateCategory(updated);
  }

  void deleteCategory(String id) {
    final catToDelete = state.firstWhere((c) => c.id == id, orElse: () => state.first);
    state = state.where((c) => c.id != id).toList();
    _persist(state);
    SupabaseDataService.deleteCategory(id, slug: catToDelete.slug);
  }
}

final categoriesProvider =
    NotifierProvider<CategoriesNotifier, List<CommodityCategory>>(
  CategoriesNotifier.new,
);

// --- Trader Negotiation Chat State ---
class TraderChatNotifier extends Notifier<Map<String, List<TraderChatMessage>>> {
  static const _chatCacheKey = 'smartmove_chat_history_v2';

  @override
  Map<String, List<TraderChatMessage>> build() {
    _loadFromCache();
    return {};
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final restored = <String, List<TraderChatMessage>>{};
        decoded.forEach((key, val) {
          final list = (val as List<dynamic>)
              .map((item) => TraderChatMessage.fromJson(item as Map<String, dynamic>))
              .toList();
          restored[key] = list;
        });
        state = restored;
      }
    } catch (_) {}
  }

  Future<void> _persist(Map<String, List<TraderChatMessage>> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodable = <String, dynamic>{};
      map.forEach((k, v) {
        encodable[k] = v.map((msg) => msg.toJson()).toList();
      });
      await prefs.setString(_chatCacheKey, jsonEncode(encodable));
    } catch (_) {}
  }

  Future<void> sendCustomerMessage({
    required String traderName,
    required String commodityName,
    required double quantity,
    required String unit,
    required double listedPrice,
    required String messageText,
    double? proposedPrice,
  }) async {
    final now = DateTime.now();
    final currentHistory = List<TraderChatMessage>.from(state[traderName] ?? []);

    final userSession = ref.read(authProvider);
    final senderName = userSession.displayName.isNotEmpty
        ? userSession.displayName
        : 'Customer';

    final customerMsg = TraderChatMessage(
      id: 'cust-${now.millisecondsSinceEpoch}',
      senderName: senderName,
      isTrader: false,
      text: messageText,
      timestamp: now,
      proposedPrice: proposedPrice,
      conversationKey: traderName,
      commodityName: commodityName,
    );

    currentHistory.add(customerMsg);

    final newState = {
      ...state,
      traderName: currentHistory,
    };
    state = newState;
    _persist(newState);

    // Sync to Supabase backend database
    SupabaseDataService.sendChatMessage(
      customerMsg,
      conversationKey: traderName,
      commodityName: commodityName,
    );
  }

  Future<void> sendTraderReply({
    required String traderName,
    required String replyText,
    String? customerName,
    String? commodityName,
  }) async {
    final now = DateTime.now();
    final currentHistory = List<TraderChatMessage>.from(state[traderName] ?? []);

    final traderMsg = TraderChatMessage(
      id: 'trader-${now.millisecondsSinceEpoch}',
      senderName: traderName,
      isTrader: true,
      text: replyText,
      timestamp: now,
      conversationKey: traderName,
      commodityName: commodityName,
    );

    currentHistory.add(traderMsg);

    final newState = {
      ...state,
      traderName: currentHistory,
    };
    state = newState;
    _persist(newState);

    // Sync to Supabase backend database
    SupabaseDataService.sendChatMessage(
      traderMsg,
      conversationKey: traderName,
      commodityName: commodityName ?? 'Commodity',
    );
  }

  /// Synchronize chat history from Cloud Supabase database for a given trader/outlet
  Future<void> loadMessages(String traderName) async {
    final remoteMessages = await SupabaseDataService.fetchChatMessages(traderName);
    if (remoteMessages != null && remoteMessages.isNotEmpty) {
      final current = List<TraderChatMessage>.from(state[traderName] ?? []);
      final currentIds = current.map((m) => m.id).toSet();
      bool changed = false;

      for (final rMsg in remoteMessages) {
        if (!currentIds.contains(rMsg.id)) {
          current.add(rMsg);
          currentIds.add(rMsg.id);
          changed = true;
        }
      }

      if (changed) {
        current.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final updatedState = {
          ...state,
          traderName: current,
        };
        state = updatedState;
        _persist(updatedState);
      }
    }
  }

  /// Synchronize all incoming customer inquiries from Cloud Supabase database for a verified seller
  Future<void> syncSellerInquiries(String sellerStoreName) async {
    final remoteMap = await SupabaseDataService.fetchAllSellerInquiries(sellerStoreName);
    if (remoteMap != null && remoteMap.isNotEmpty) {
      final updatedState = Map<String, List<TraderChatMessage>>.from(state);
      bool changed = false;

      remoteMap.forEach((convKey, remoteList) {
        final current = List<TraderChatMessage>.from(updatedState[convKey] ?? []);
        final currentIds = current.map((m) => m.id).toSet();

        for (final rMsg in remoteList) {
          if (!currentIds.contains(rMsg.id)) {
            current.add(rMsg);
            currentIds.add(rMsg.id);
            changed = true;
          }
        }

        if (changed) {
          current.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          updatedState[convKey] = current;
        }
      });

      if (changed) {
        state = updatedState;
        _persist(updatedState);
      }
    }
  }
}

final traderChatProvider =
    NotifierProvider<TraderChatNotifier, Map<String, List<TraderChatMessage>>>(
  TraderChatNotifier.new,
);

// --- Community Observations State ---
class CommunityNotifier extends Notifier<List<PriceObservation>> {
  static const _obsCacheKey = 'smartmove_observations_cache_v2';
  static const _tombstonesKey = 'smartmove_deleted_observation_ids_v1';
  static const _tombstoneNamesKey = 'smartmove_deleted_product_names_v1';
  final Set<String> _deletedTombstoneIds = {};
  final Set<String> _deletedProductNames = {};

  @override
  List<PriceObservation> build() {
    _loadFromCacheAndLive();
    return [];
  }

  Future<void> _loadTombstones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_tombstonesKey) ?? [];
      final names = prefs.getStringList(_tombstoneNamesKey) ?? [];
      _deletedTombstoneIds.addAll(ids);
      _deletedProductNames.addAll(names.map((n) => n.trim().toLowerCase()));
    } catch (_) {}
  }

  Future<void> _persistTombstones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_tombstonesKey, _deletedTombstoneIds.toList());
      await prefs.setStringList(_tombstoneNamesKey, _deletedProductNames.toList());
    } catch (_) {}
  }

  bool _isTombstoned(PriceObservation obs) {
    if (_deletedTombstoneIds.contains(obs.id)) return true;
    final clean = obs.productName.trim().toLowerCase();
    if (clean.isNotEmpty && _deletedProductNames.contains(clean)) return true;
    return false;
  }

  Future<void> _loadFromCacheAndLive() async {
    await _loadTombstones();
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_obsCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as List<dynamic>;
        if (decoded.isNotEmpty) {
          final items = decoded
              .map((j) => PriceObservation.fromJson(j as Map<String, dynamic>))
              .where((o) =>
                  !_isTombstoned(o) &&
                  !o.id.startsWith('obs-seed') &&
                  !o.sellerName.toLowerCase().contains('kudirat') &&
                  !o.sellerName.toLowerCase().contains('demo') &&
                  !o.sellerName.toLowerCase().contains('seed'))
              .toList();
          state = items;
          if (items.length != decoded.length) {
            _persist(items);
          }
        }
      }
    } catch (_) {}

    final live = await SupabaseDataService.fetchObservations();
    if (live != null) {
      final filteredLive = live.where((o) => !_isTombstoned(o)).toList();
      if (filteredLive.isEmpty && live.isNotEmpty) {
        state = state.where((o) => !_isTombstoned(o)).toList();
        _persist(state);
      } else if (filteredLive.isEmpty) {
        state = [];
        _persist(state);
      } else {
        final liveIds = filteredLive.map((o) => o.id).toSet();
        final localOnly = state
            .where((o) =>
                !liveIds.contains(o.id) &&
                !_isTombstoned(o) &&
                !o.id.startsWith('obs-seed') &&
                !o.sellerName.toLowerCase().contains('demo') &&
                !o.sellerName.toLowerCase().contains('seed'))
            .toList();
        state = [...localOnly, ...filteredLive];
        _persist(state);
      }
    }
  }

  Future<void> fetchLive() async {
    await _loadTombstones();
    final live = await SupabaseDataService.fetchObservations();
    if (live != null) {
      final filteredLive = live.where((o) => !_isTombstoned(o)).toList();
      state = filteredLive;
      _persist(state);
    }
  }

  Future<void> refreshFromCloud({bool purgeLocalMock = false}) async {
    await _loadTombstones();
    if (purgeLocalMock) {
      await purgeDemoObservations();
    }
    final live = await SupabaseDataService.fetchObservations();
    if (live != null) {
      final filteredLive = live.where((o) => !_isTombstoned(o)).toList();
      if (filteredLive.isEmpty && live.isNotEmpty) {
        state = state.where((o) => !_isTombstoned(o)).toList();
      } else if (filteredLive.isEmpty) {
        state = [];
      } else {
        final liveIds = filteredLive.map((o) => o.id).toSet();
        final localOnly = purgeLocalMock
            ? <PriceObservation>[]
            : state
                .where((o) =>
                    !liveIds.contains(o.id) &&
                    !_isTombstoned(o) &&
                    !o.id.startsWith('obs-seed') &&
                    !o.sellerName.toLowerCase().contains('demo') &&
                    !o.sellerName.toLowerCase().contains('seed'))
                .toList();
        state = [...localOnly, ...filteredLive];
      }
      await _persist(state);
    }
  }

  Future<void> purgeDemoObservations() async {
    state = state
        .where((o) =>
            !_isTombstoned(o) &&
            !o.id.startsWith('obs-seed') &&
            !o.sellerName.toLowerCase().contains('kudirat') &&
            !o.sellerName.toLowerCase().contains('demo') &&
            !o.sellerName.toLowerCase().contains('seed'))
        .toList();
    await _persist(state);
  }

  Future<void> _persist(List<PriceObservation> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(list.map((o) => o.toJson()).toList());
      await prefs.setString(_obsCacheKey, jsonStr);
    } catch (_) {}
  }

  void addObservation({
    required String productName,
    required String sellerName,
    required double price,
    required String unit,
    required String submitterName,
    required String submitterRole,
    String channel = 'Local Market',
    String? brandOrGrade,
    double? standardizedUnitPrice,
    bool inStock = true,
    String? marketLocation,
    String? notes,
    String category = 'Food',
    String? imageUrl,
    double? latitude,
    double? longitude,
  }) {
    final cleanName = productName.trim().toLowerCase();
    _deletedProductNames.remove(cleanName);
    _persistTombstones();

    final multiplier = CommodityComparisonService.calculateUnitMultiplier(
      unit,
      commodityName: productName,
    );
    final computedUnitPrice = standardizedUnitPrice ??
        (multiplier > 0 ? (price / multiplier) : price);
    final baseUnit = CommodityComparisonService.resolveBaseUnit(unit, commodityName: productName);

    final isTrader = submitterRole == 'Trader' || submitterRole == 'Seller';
    final isAdmin = submitterRole == 'Admin' || submitterRole == 'Administrator';

    final newObs = PriceObservation(
      id: 'obs-${DateTime.now().millisecondsSinceEpoch}',
      productId: 'p-custom',
      productName: productName,
      sellerName: sellerName,
      marketLocation: marketLocation ?? sellerName,
      price: price,
      unit: unit,
      timestamp: DateTime.now(),
      sourceType: isTrader
          ? ObservationSource.traderConfirmed
          : (isAdmin
              ? ObservationSource.independentlyVerified
              : ObservationSource.communityReported),
      submitterName: submitterName,
      submitterRole: submitterRole,
      isVerified: isTrader || isAdmin,
      notes: notes ?? 'Submitted via SmartMove app.',
      channel: channel,
      brandOrGrade: brandOrGrade,
      inStock: inStock,
      standardizedUnitPrice: computedUnitPrice,
      baseUnit: baseUnit,
      category: category,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
    );
    state = [newObs, ...state];
    _persist(state);

    // Asynchronously sync to Cloud Supabase
    SupabaseDataService.insertObservation(
      productName: productName,
      sellerName: sellerName,
      price: price,
      unit: unit,
      submitterName: submitterName,
      submitterRole: submitterRole,
      channel: channel,
      brandOrGrade: brandOrGrade,
      inStock: inStock,
      standardizedUnitPrice: computedUnitPrice,
      baseUnit: baseUnit,
      marketLocation: marketLocation,
      notes: notes,
      category: category,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
    );
  }

  void verifyObservation(String id, bool isVerified) {
    state = [
      for (final o in state)
        if (o.id == id)
          o.copyWith(
            isVerified: isVerified,
            sourceType: isVerified
                ? ObservationSource.independentlyVerified
                : ObservationSource.communityReported,
            isFlaggedAnomaly: isVerified ? false : o.isFlaggedAnomaly,
          )
        else
          o,
    ];
    _persist(state);
    SupabaseDataService.verifyObservation(id, isVerified);
  }

  void updateListingPrice(String id, double newPrice) {
    state = [
      for (final o in state)
        if (o.id == id)
          o.copyWith(
            price: newPrice,
            timestamp: DateTime.now(),
            standardizedUnitPrice: () {
              final mult = CommodityComparisonService.calculateUnitMultiplier(
                  o.unit,
                  commodityName: o.productName);
              return mult > 0 ? (newPrice / mult) : newPrice;
            }(),
          )
        else
          o,
    ];
    _persist(state);
    SupabaseDataService.updateObservation(id: id, price: newPrice);
  }

  void updateListingDetails({
    required String id,
    String? productName,
    required double price,
    String? unit,
    String? brandOrGrade,
    bool? inStock,
    String? notes,
    String? channel,
    String? sellerName,
    String? marketLocation,
    String? category,
    String? imageUrl,
    double? latitude,
    double? longitude,
  }) {
    state = [
      for (final o in state)
        if (o.id == id)
          o.copyWith(
            productName: productName ?? o.productName,
            price: price,
            unit: unit ?? o.unit,
            brandOrGrade: brandOrGrade ?? o.brandOrGrade,
            inStock: inStock ?? o.inStock,
            notes: notes ?? o.notes,
            channel: channel ?? o.channel,
            sellerName: sellerName ?? o.sellerName,
            marketLocation: marketLocation ?? o.marketLocation,
            category: category ?? o.category,
            imageUrl: imageUrl ?? o.imageUrl,
            latitude: latitude ?? o.latitude,
            longitude: longitude ?? o.longitude,
            timestamp: DateTime.now(),
            standardizedUnitPrice: () {
              final effectiveUnit = unit ?? o.unit;
              final effectiveName = productName ?? o.productName;
              final mult = CommodityComparisonService.calculateUnitMultiplier(
                  effectiveUnit,
                  commodityName: effectiveName);
              return mult > 0 ? (price / mult) : price;
            }(),
          )
        else
          o,
    ];
    _persist(state);
    SupabaseDataService.updateObservation(
      id: id,
      productName: productName,
      price: price,
      unit: unit,
      category: category,
      brandOrGrade: brandOrGrade,
      notes: notes,
      inStock: inStock,
      imageUrl: imageUrl,
      marketLocation: marketLocation,
      latitude: latitude,
      longitude: longitude,
    );
  }

  void toggleListingStock(String id) {
    bool? newStock;
    state = [
      for (final o in state)
        if (o.id == id) () {
          final next = !o.inStock;
          newStock = next;
          return o.copyWith(
            inStock: next,
            timestamp: DateTime.now(),
          );
        }()
        else
          o,
    ];
    _persist(state);
    if (newStock != null) {
      SupabaseDataService.toggleObservationStock(id, newStock!);
    }
  }

  void deleteListing(String id) {
    final deleted = state.where((o) => o.id == id).toList();
    _deletedTombstoneIds.add(id);
    String? productName;
    if (deleted.isNotEmpty) {
      productName = deleted.first.productName;
      final clean = productName.trim().toLowerCase();
      if (clean.isNotEmpty) {
        _deletedProductNames.add(clean);
      }
    }
    _persistTombstones();

    state = state.where((o) => o.id != id && !_isTombstoned(o)).toList();
    _persist(state);

    if (productName != null && productName.trim().isNotEmpty) {
      try {
        ref.read(productsProvider.notifier).deleteProductByName(productName);
      } catch (_) {}
    }
    if (deleted.isNotEmpty &&
        deleted.first.productId.isNotEmpty &&
        deleted.first.productId != 'p-custom') {
      try {
        ref.read(productsProvider.notifier).deleteProduct(deleted.first.productId);
      } catch (_) {}
    }

    SupabaseDataService.deleteObservation(
      id,
      productName: productName,
    );
  }

  void flagListingAnomaly(String id, {required bool isAnomalous, String? reason}) {
    state = [
      for (final o in state)
        if (o.id == id)
          o.copyWith(
            isFlaggedAnomaly: isAnomalous,
            anomalyReason: reason,
          )
        else
          o,
    ];
    _persist(state);
  }

  void reportListing({
    required String observationId,
    required String reportType,
    required String reason,
    String? details,
    required String reporterName,
  }) {
    final compositeReason =
        '[$reportType] $reason${details != null && details.trim().isNotEmpty ? " • Details: ${details.trim()}" : ""} • Reported by $reporterName';
    flagListingAnomaly(observationId, isAnomalous: true, reason: compositeReason);
  }
}

final communityProvider =
    NotifierProvider<CommunityNotifier, List<PriceObservation>>(
  CommunityNotifier.new,
);

// --- Auth State ---
class AuthNotifier extends Notifier<UserSession> {
  final UserSession? _initialSession;
  AuthNotifier([this._initialSession]);
  bool _manuallySet = false;

  @override
  UserSession build() {
    final initial = _initialSession;
    if (initial != null) {
      _manuallySet = true;
      return initial;
    }
    _restoreSession();
    return UserSession.guest;
  }

  void syncWithSellerApplications(List<SellerApplication> applications) {
    if (state.isGuest) return;
    for (final app in applications) {
      final matches = app.userId == state.id ||
          (state.email.isNotEmpty &&
              app.applicantEmail.trim().toLowerCase() ==
                  state.email.trim().toLowerCase());
      if (matches) {
        if (app.status == SellerApplicationStatus.approved) {
          if (!state.isApprovedSeller || state.role != 'Trader') {
            state = state.copyWith(
              role: 'Trader',
              sellerApplicationStatus: SellerApplicationStatus.approved,
              businessName: app.businessName,
              marketHub: app.marketHub,
              sellerChannel: app.sellerChannel,
              phone: app.phone,
              stallLocation: app.stallLocation,
              latitude: app.latitude,
              longitude: app.longitude,
            );
            AuthService.persistSession(state);
          }
        } else if (app.status == SellerApplicationStatus.pending) {
          if (state.sellerApplicationStatus !=
                  SellerApplicationStatus.pending &&
              state.sellerApplicationStatus !=
                  SellerApplicationStatus.approved) {
            state = state.copyWith(
              sellerApplicationStatus: SellerApplicationStatus.pending,
              businessName: app.businessName,
              marketHub: app.marketHub,
              sellerChannel: app.sellerChannel,
              phone: app.phone,
              stallLocation: app.stallLocation,
              latitude: app.latitude,
              longitude: app.longitude,
            );
            AuthService.persistSession(state);
          }
        } else if (app.status == SellerApplicationStatus.rejected) {
          state = state.copyWith(
            role: state.role == 'Trader' ? 'Customer' : state.role,
            sellerApplicationStatus: SellerApplicationStatus.rejected,
          );
          AuthService.persistSession(state);
        }
        break;
      }
    }
  }

  Future<void> _restoreSession() async {
    final session = await AuthService.restorePersistedSession();
    if (ref.mounted && !_manuallySet) {
      state = session;
      syncWithSellerApplications(ref.read(sellerApplicationsProvider));
    }
  }

  /// Live refresh of user role and attributes from Supabase profiles table
  Future<void> refreshProfileFromDatabase() async {
    final live = await AuthService.syncCurrentUserProfile();
    if (live != null) {
      state = live;
    }
  }

  void setSession(UserSession session) {
    _manuallySet = true;
    state = session;
    syncWithSellerApplications(ref.read(sellerApplicationsProvider));
    AuthService.persistSession(state);
  }

  void updateRole(String newRole) {
    String? defaultBiz = state.businessName;
    String? defaultHub = state.marketHub;
    String? defaultChannel = state.sellerChannel;
    if (newRole == 'Trader' && (defaultBiz == null || defaultBiz.isEmpty)) {
      defaultBiz = '${state.displayName}\'s Store';
      final loc = ref.read(locationProvider);
      defaultHub = defaultHub ?? (loc.isSet ? loc.displayLocation : 'Local Market');
      defaultChannel = defaultChannel ?? 'Local Market';
    }
    state = state.copyWith(
      role: newRole,
      businessName: defaultBiz,
      marketHub: defaultHub,
      sellerChannel: defaultChannel,
      sellerApplicationStatus: newRole == 'Trader'
          ? SellerApplicationStatus.approved
          : state.sellerApplicationStatus,
    );
    AuthService.persistSession(state);
  }

  void updateSellerProfile({
    String? businessName,
    String? marketHub,
    String? sellerChannel,
    String? phone,
    String? stallLocation,
    double? latitude,
    double? longitude,
    bool? hasPendingStoreEdit,
    String? pendingStoreEditSummary,
  }) {
    state = state.copyWith(
      businessName: businessName ?? state.businessName,
      marketHub: marketHub ?? state.marketHub,
      sellerChannel: sellerChannel ?? state.sellerChannel,
      phone: phone ?? state.phone,
      stallLocation: stallLocation ?? state.stallLocation,
      latitude: latitude ?? state.latitude,
      longitude: longitude ?? state.longitude,
      hasPendingStoreEdit: hasPendingStoreEdit ?? state.hasPendingStoreEdit,
      pendingStoreEditSummary: pendingStoreEditSummary ?? state.pendingStoreEditSummary,
    );
    AuthService.persistSession(state);
    SupabaseDataService.updateProfile(
      userId: state.id,
      email: state.email,
      businessName: state.businessName,
      marketHub: state.marketHub,
      sellerChannel: state.sellerChannel,
      stallLocation: state.stallLocation,
      latitude: state.latitude,
      longitude: state.longitude,
      phone: state.phone,
    );
  }

  void setPendingStoreEdit(bool hasPending, String? summary) {
    state = state.copyWith(
      hasPendingStoreEdit: hasPending,
      pendingStoreEditSummary: summary,
    );
    AuthService.persistSession(state);
  }

  void applyApprovedStoreEdit({
    required String businessName,
    required String marketHub,
    String? stallLocation,
    required String phone,
    required String sellerChannel,
  }) {
    state = state.copyWith(
      businessName: businessName,
      marketHub: marketHub,
      stallLocation: stallLocation ?? state.stallLocation,
      phone: phone,
      sellerChannel: sellerChannel,
      hasPendingStoreEdit: false,
      pendingStoreEditSummary: null,
    );
    AuthService.persistSession(state);
  }

  void updateUserProfile({
    String? displayName,
    String? email,
    String? phone,
  }) {
    state = state.copyWith(
      displayName: displayName ?? state.displayName,
      email: email ?? state.email,
      phone: phone ?? state.phone,
    );
    AuthService.persistSession(state);
  }

  void submitSellerApplication({
    required String businessName,
    required String marketHub,
    required String sellerChannel,
    required String phone,
    String? stallLocation,
    double? latitude,
    double? longitude,
  }) {
    state = state.copyWith(
      businessName: businessName,
      marketHub: marketHub,
      sellerChannel: sellerChannel,
      phone: phone,
      stallLocation: stallLocation,
      latitude: latitude,
      longitude: longitude,
      sellerApplicationStatus: SellerApplicationStatus.pending,
    );
    AuthService.persistSession(state);
  }

  void approveSellerStatus({
    String? businessName,
    String? marketHub,
    String? sellerChannel,
    String? phone,
    String? stallLocation,
    double? latitude,
    double? longitude,
  }) {
    state = state.copyWith(
      role: 'Trader',
      businessName: businessName ?? state.businessName,
      marketHub: marketHub ?? state.marketHub,
      sellerChannel: sellerChannel ?? state.sellerChannel,
      phone: phone ?? state.phone,
      stallLocation: stallLocation ?? state.stallLocation,
      latitude: latitude ?? state.latitude,
      longitude: longitude ?? state.longitude,
      sellerApplicationStatus: SellerApplicationStatus.approved,
    );
    AuthService.persistSession(state);
  }

  void rejectSellerStatus({String? reason}) {
    state = state.copyWith(
      role: 'Customer',
      sellerApplicationStatus: SellerApplicationStatus.rejected,
    );
    AuthService.persistSession(state);
  }

  Future<void> logout() async {
    await AuthService.signOut();
    state = UserSession.guest;
  }
}

final authProvider = NotifierProvider<AuthNotifier, UserSession>(
  AuthNotifier.new,
);

// --- Seller Applications State ---
class SellerApplicationsNotifier extends Notifier<List<SellerApplication>> {
  static const _storageKey = 'smartmove_cached_seller_applications';

  @override
  List<SellerApplication> build() {
    _loadPersisted();
    _fetchLive();
    return _getInitialApplications();
  }

  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        final apps = list
            .map((item) =>
                SellerApplication.fromJson(item as Map<String, dynamic>))
            .where((app) =>
                !app.id.startsWith('app-seed') &&
                !app.applicantName.toLowerCase().contains('kudirat') &&
                !app.businessName.toLowerCase().contains('kudirat') &&
                !app.applicantEmail.toLowerCase().contains('seed') &&
                !app.applicantEmail.toLowerCase().contains('demo') &&
                !app.businessName.toLowerCase().contains('demo'))
            .toList();
        if (apps.length != list.length) {
          // Re-persist cleansed list without any mock/seed applications
          _persist(apps);
        }
        if (ref.mounted) {
          state = apps;
          ref.read(authProvider.notifier).syncWithSellerApplications(state);
        }
      }
    } catch (_) {}
  }

  Future<void> _persist(List<SellerApplication> apps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = apps.map((a) => a.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _fetchLive() async {
    final live = await SupabaseDataService.fetchSellerApplications();
    if (live != null && ref.mounted) {
      if (live.isEmpty) {
        // Authoritative live database has 0 applications; clear state
        state = const <SellerApplication>[];
        _persist(state);
        ref.read(authProvider.notifier).syncWithSellerApplications(state);
        return;
      }

      final liveEmails = live
          .map((a) => a.applicantEmail.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      final liveUserIds = live.map((a) => a.userId).where((u) => u.isNotEmpty).toSet();
      final liveIds = live.map((a) => a.id).toSet();

      final localOnly = state.where((a) {
        if (a.id.startsWith('app-seed')) {
          return false;
        }
        if (a.applicantEmail.toLowerCase().contains('demo') ||
            a.applicantEmail.toLowerCase().contains('seed')) {
          return false;
        }
        if (liveIds.contains(a.id)) {
          return false;
        }
        if (a.userId.isNotEmpty && liveUserIds.contains(a.userId)) {
          return false;
        }
        if (a.applicantEmail.isNotEmpty &&
            liveEmails.contains(a.applicantEmail.trim().toLowerCase())) {
          return false;
        }
        return true;
      });

      state = [...live, ...localOnly];
      _persist(state);
      ref.read(authProvider.notifier).syncWithSellerApplications(state);
    }
  }

  Future<void> fetchLive() async {
    await _fetchLive();
  }

  Future<void> refreshFromCloud({bool purgeLocalMock = false}) async {
    if (purgeLocalMock) {
      await purgeDemoApplications();
    }
    final live = await SupabaseDataService.fetchSellerApplications();
    if (live != null && ref.mounted) {
      if (live.isEmpty) {
        state = const <SellerApplication>[];
      } else {
        if (purgeLocalMock) {
          state = live;
        } else {
          final liveIds = live.map((a) => a.id).toSet();
          final localOnly = state.where((a) =>
              !a.id.startsWith('app-seed') &&
              !a.applicantEmail.toLowerCase().contains('demo') &&
              !a.applicantEmail.toLowerCase().contains('seed') &&
              !liveIds.contains(a.id)).toList();
          state = [...live, ...localOnly];
        }
      }
      await _persist(state);
      ref.read(authProvider.notifier).syncWithSellerApplications(state);
    }
  }

  Future<void> purgeDemoApplications() async {
    state = state.where((a) =>
        !a.id.startsWith('app-seed') &&
        !a.applicantName.toLowerCase().contains('kudirat') &&
        !a.businessName.toLowerCase().contains('kudirat') &&
        !a.applicantEmail.toLowerCase().contains('seed') &&
        !a.applicantEmail.toLowerCase().contains('demo') &&
        !a.businessName.toLowerCase().contains('demo')).toList();
    await _persist(state);
    ref.read(authProvider.notifier).syncWithSellerApplications(state);
  }

  Future<void> clearAllApplications() async {
    state = const <SellerApplication>[];
    await _persist(state);
    ref.read(authProvider.notifier).syncWithSellerApplications(state);
  }

  List<SellerApplication> _getInitialApplications() {
    return const <SellerApplication>[];
  }

  void submitApplication({
    required UserSession user,
    required String businessName,
    required String marketHub,
    required String sellerChannel,
    required String phone,
    String? stallLocation,
    double? latitude,
    double? longitude,
  }) {
    final newApp = SellerApplication(
      id: 'app-${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      applicantName: user.displayName,
      applicantEmail: user.email,
      businessName: businessName,
      marketHub: marketHub,
      sellerChannel: sellerChannel,
      stallLocation: stallLocation,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      status: SellerApplicationStatus.pending,
      submittedAt: DateTime.now(),
    );

    // Cleanly replace any previous application by the same user or email
    final filtered = state.where((a) {
      if (a.userId == user.id) return false;
      if (user.email.isNotEmpty &&
          a.applicantEmail.trim().toLowerCase() == user.email.trim().toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    state = [newApp, ...filtered];
    _persist(state);

    // Asynchronously sync to Cloud Supabase
    SupabaseDataService.insertSellerApplication(newApp);

    // Update current user session to pending review
    ref.read(authProvider.notifier).submitSellerApplication(
          businessName: businessName,
          marketHub: marketHub,
          sellerChannel: sellerChannel,
          phone: phone,
          stallLocation: stallLocation,
          latitude: latitude,
          longitude: longitude,
        );
  }

  void approveApplication(String applicationId) {
    SellerApplication? approvedApp;
    state = [
      for (final app in state)
        if (app.id == applicationId) ...[
          (() {
            final updated = app.copyWith(
              status: SellerApplicationStatus.approved,
              reviewedAt: DateTime.now(),
            );
            approvedApp = updated;
            return updated;
          })(),
        ] else
          app,
    ];
    _persist(state);

    if (approvedApp != null) {
      // Asynchronously sync approval to Cloud Supabase
      SupabaseDataService.updateSellerApplicationStatus(
        applicationId: applicationId,
        status: SellerApplicationStatus.approved,
        applicantEmail: approvedApp!.applicantEmail,
      );

      // Sync promotion to Supabase public.profiles table
      SupabaseDataService.promoteProfileToSeller(
        userId: approvedApp!.userId,
        email: approvedApp!.applicantEmail,
        businessName: approvedApp!.businessName,
        marketHub: approvedApp!.marketHub,
        sellerChannel: approvedApp!.sellerChannel,
        stallLocation: approvedApp!.stallLocation,
        latitude: approvedApp!.latitude,
        longitude: approvedApp!.longitude,
        phone: approvedApp!.phone,
      );

      // Save approved trader profile to local persistent storage for this applicant
      AuthService.saveApprovedTraderProfile(
        email: approvedApp!.applicantEmail,
        userId: approvedApp!.userId,
        displayName: approvedApp!.applicantName,
        businessName: approvedApp!.businessName,
        marketHub: approvedApp!.marketHub,
        sellerChannel: approvedApp!.sellerChannel,
        stallLocation: approvedApp!.stallLocation,
        latitude: approvedApp!.latitude,
        longitude: approvedApp!.longitude,
        phone: approvedApp!.phone,
      );

      // If the approved application belongs to current user, upgrade them to Trader
      final currentUser = ref.read(authProvider);
      if (currentUser.id == approvedApp!.userId ||
          (currentUser.email.isNotEmpty &&
              currentUser.email.trim().toLowerCase() ==
                  approvedApp!.applicantEmail.trim().toLowerCase())) {
        ref.read(authProvider.notifier).approveSellerStatus(
              businessName: approvedApp!.businessName,
              marketHub: approvedApp!.marketHub,
              sellerChannel: approvedApp!.sellerChannel,
              phone: approvedApp!.phone,
              stallLocation: approvedApp!.stallLocation,
              latitude: approvedApp!.latitude,
              longitude: approvedApp!.longitude,
            );
      }
    }
  }

  void rejectApplication(String applicationId, {required String reason}) {
    SellerApplication? rejectedApp;
    state = [
      for (final app in state)
        if (app.id == applicationId) ...[
          (() {
            final updated = app.copyWith(
              status: SellerApplicationStatus.rejected,
              reviewedAt: DateTime.now(),
              rejectionReason: reason,
            );
            rejectedApp = updated;
            return updated;
          })(),
        ] else
          app,
    ];
    _persist(state);

    if (rejectedApp != null) {
      // Asynchronously sync rejection to Cloud Supabase
      SupabaseDataService.updateSellerApplicationStatus(
        applicationId: applicationId,
        status: SellerApplicationStatus.rejected,
        reason: reason,
        applicantEmail: rejectedApp!.applicantEmail,
      );

      // Demote profile in Supabase
      SupabaseDataService.demoteProfileToCustomer(
        userId: rejectedApp!.userId,
        email: rejectedApp!.applicantEmail,
      );

      // If the rejected application belongs to current user, mark rejected
      final currentUser = ref.read(authProvider);
      if (currentUser.id == rejectedApp!.userId ||
          (currentUser.email.isNotEmpty &&
              currentUser.email.trim().toLowerCase() ==
                  rejectedApp!.applicantEmail.trim().toLowerCase())) {
        ref.read(authProvider.notifier).rejectSellerStatus(reason: reason);
      }
    }
  }

  void revokeApproval(String applicationId, {required String reason}) {
    rejectApplication(applicationId, reason: reason);
  }

  void reopenApplication(String applicationId) {
    SellerApplication? reopenedApp;
    state = [
      for (final app in state)
        if (app.id == applicationId) ...[
          (() {
            final updated = app.copyWith(
              status: SellerApplicationStatus.pending,
              clearReviewedAt: true,
              clearRejectionReason: true,
            );
            reopenedApp = updated;
            return updated;
          })(),
        ] else
          app,
    ];
    _persist(state);

    if (reopenedApp != null) {
      SupabaseDataService.updateSellerApplicationStatus(
        applicationId: applicationId,
        status: SellerApplicationStatus.pending,
        applicantEmail: reopenedApp!.applicantEmail,
      );

      final currentUser = ref.read(authProvider);
      if (currentUser.id == reopenedApp!.userId ||
          (currentUser.email.isNotEmpty &&
              currentUser.email.trim().toLowerCase() ==
                  reopenedApp!.applicantEmail.trim().toLowerCase())) {
        ref.read(authProvider.notifier).submitSellerApplication(
              businessName: reopenedApp!.businessName,
              marketHub: reopenedApp!.marketHub,
              sellerChannel: reopenedApp!.sellerChannel,
              phone: reopenedApp!.phone,
              stallLocation: reopenedApp!.stallLocation,
              latitude: reopenedApp!.latitude,
              longitude: reopenedApp!.longitude,
            );
      }
    }
  }

  void updateApplicationStoreDetails({
    required String userId,
    required String userEmail,
    required String businessName,
    required String marketHub,
    String? stallLocation,
    required String phone,
    required String sellerChannel,
  }) {
    state = [
      for (final app in state)
        if (app.userId == userId ||
            (userEmail.isNotEmpty &&
                app.applicantEmail.trim().toLowerCase() ==
                    userEmail.trim().toLowerCase()))
          app.copyWith(
            businessName: businessName,
            marketHub: marketHub,
            stallLocation: stallLocation ?? app.stallLocation,
            phone: phone,
            sellerChannel: sellerChannel,
          )
        else
          app,
    ];
    _persist(state);

    AuthService.saveApprovedTraderProfile(
      email: userEmail,
      userId: userId,
      displayName: businessName,
      businessName: businessName,
      marketHub: marketHub,
      sellerChannel: sellerChannel,
      stallLocation: stallLocation,
      phone: phone,
    );
  }
}

final sellerApplicationsProvider =
    NotifierProvider<SellerApplicationsNotifier, List<SellerApplication>>(
  SellerApplicationsNotifier.new,
);

// --- Store Edit Requests State (Admin Verification for Store Profile Modifications) ---
class StoreEditRequestsNotifier extends Notifier<List<StoreEditRequest>> {
  static const String _storageKey = 'smartmove_cached_store_edit_requests';

  @override
  List<StoreEditRequest> build() {
    _loadPersisted();
    return const <StoreEditRequest>[];
  }

  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        final requests = list
            .map((item) =>
                StoreEditRequest.fromJson(item as Map<String, dynamic>))
            .where((r) =>
                !r.id.startsWith('edit-seed') &&
                !r.applicantEmail.toLowerCase().contains('seed') &&
                !r.applicantEmail.toLowerCase().contains('demo') &&
                !r.proposedBusinessName.toLowerCase().contains('demo') &&
                !r.currentBusinessName.toLowerCase().contains('demo'))
            .toList();
        if (requests.length != list.length) {
          _persist(requests);
        }
        if (ref.mounted) {
          state = requests;
        }
      }
    } catch (_) {}

    final live = await SupabaseDataService.fetchStoreEditRequests();
    if (live != null && live.isNotEmpty && ref.mounted) {
      state = live;
      _persist(live);
    }
  }

  Future<void> fetchLive() async {
    final live = await SupabaseDataService.fetchStoreEditRequests();
    if (live != null && live.isNotEmpty && ref.mounted) {
      state = live;
      _persist(live);
    }
  }

  Future<void> purgeDemoRequests() async {
    state = state
        .where((r) =>
            !r.id.startsWith('edit-seed') &&
            !r.applicantEmail.toLowerCase().contains('seed') &&
            !r.applicantEmail.toLowerCase().contains('demo') &&
            !r.proposedBusinessName.toLowerCase().contains('demo') &&
            !r.currentBusinessName.toLowerCase().contains('demo'))
        .toList();
    await _persist(state);
  }

  Future<void> clearAllRequests() async {
    state = const <StoreEditRequest>[];
    await _persist(state);
  }

  Future<void> _persist(List<StoreEditRequest> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = requests.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (_) {}
  }

  void submitRequest({
    required UserSession seller,
    required String proposedBusinessName,
    required String proposedMarketHub,
    String? proposedStallLocation,
    required String proposedPhone,
    required String proposedSellerChannel,
  }) {
    final req = StoreEditRequest(
      id: 'edit-${DateTime.now().millisecondsSinceEpoch}',
      sellerId: seller.id,
      applicantEmail: seller.email,
      currentBusinessName: seller.businessName ?? '',
      proposedBusinessName: proposedBusinessName,
      currentMarketHub: seller.marketHub ?? (seller.stallLocation ?? 'Local Market'),
      proposedMarketHub: proposedMarketHub,
      currentStallLocation: seller.stallLocation,
      proposedStallLocation: proposedStallLocation,
      currentPhone: seller.phone,
      proposedPhone: proposedPhone,
      currentSellerChannel: seller.sellerChannel ?? 'Local Market',
      proposedSellerChannel: proposedSellerChannel,
      status: 'pending',
      submittedAt: DateTime.now(),
    );

    state = [req, ...state];
    _persist(state);
    SupabaseDataService.insertStoreEditRequest(req);

    final summary =
        'Pending update to "$proposedBusinessName" at $proposedMarketHub';
    ref.read(authProvider.notifier).setPendingStoreEdit(true, summary);
  }

  void approveRequest(String requestId, {String? adminNotes}) {
    StoreEditRequest? approvedReq;
    state = state.map((r) {
      if (r.id == requestId) {
        approvedReq = r.copyWith(
          status: 'approved',
          reviewedAt: DateTime.now(),
          reviewedBy: ref.read(authProvider).displayName,
        );
        return approvedReq!;
      }
      return r;
    }).toList();
    _persist(state);

    if (approvedReq != null) {
      SupabaseDataService.updateStoreEditRequestStatus(
        requestId: requestId,
        status: 'approved',
        reviewerName: ref.read(authProvider).displayName,
      );
      ref.read(sellerApplicationsProvider.notifier).updateApplicationStoreDetails(
            userId: approvedReq!.sellerId,
            userEmail: approvedReq!.applicantEmail,
            businessName: approvedReq!.proposedBusinessName,
            marketHub: approvedReq!.proposedMarketHub,
            stallLocation: approvedReq!.proposedStallLocation,
            phone: approvedReq!.proposedPhone,
            sellerChannel: approvedReq!.proposedSellerChannel,
          );

      final currentUser = ref.read(authProvider);
      if (currentUser.id == approvedReq!.sellerId ||
          (currentUser.email.isNotEmpty &&
              currentUser.email.trim().toLowerCase() ==
                  approvedReq!.applicantEmail.trim().toLowerCase())) {
        ref.read(authProvider.notifier).applyApprovedStoreEdit(
              businessName: approvedReq!.proposedBusinessName,
              marketHub: approvedReq!.proposedMarketHub,
              stallLocation: approvedReq!.proposedStallLocation,
              phone: approvedReq!.proposedPhone,
              sellerChannel: approvedReq!.proposedSellerChannel,
            );
      }
    }
  }

  void rejectRequest(String requestId, {String? reason}) {
    StoreEditRequest? rejectedReq;
    state = state.map((r) {
      if (r.id == requestId) {
        rejectedReq = r.copyWith(
          status: 'rejected',
          reviewedAt: DateTime.now(),
          reviewedBy: ref.read(authProvider).displayName,
          rejectionReason: reason,
        );
        return rejectedReq!;
      }
      return r;
    }).toList();
    _persist(state);

    if (rejectedReq != null) {
      SupabaseDataService.updateStoreEditRequestStatus(
        requestId: requestId,
        status: 'rejected',
        reviewerName: ref.read(authProvider).displayName,
        rejectionReason: reason,
      );
      ref.read(sellerApplicationsProvider.notifier).updateApplicationStoreDetails(
            userId: rejectedReq!.sellerId,
            userEmail: rejectedReq!.applicantEmail,
            businessName: rejectedReq!.currentBusinessName,
            marketHub: rejectedReq!.currentMarketHub,
            stallLocation: rejectedReq!.currentStallLocation,
            phone: rejectedReq!.currentPhone ?? '',
            sellerChannel: rejectedReq!.currentSellerChannel,
          );

      final currentUser = ref.read(authProvider);
      if (currentUser.id == rejectedReq!.sellerId ||
          (currentUser.email.isNotEmpty &&
              currentUser.email.trim().toLowerCase() ==
                  rejectedReq!.applicantEmail.trim().toLowerCase())) {
        ref.read(authProvider.notifier).applyApprovedStoreEdit(
              businessName: rejectedReq!.currentBusinessName,
              marketHub: rejectedReq!.currentMarketHub,
              stallLocation: rejectedReq!.currentStallLocation,
              phone: rejectedReq!.currentPhone ?? '',
              sellerChannel: rejectedReq!.currentSellerChannel,
            );
        ref.read(authProvider.notifier).setPendingStoreEdit(false, null);
      }
    }
  }
}

final storeEditRequestsProvider =
    NotifierProvider<StoreEditRequestsNotifier, List<StoreEditRequest>>(
  StoreEditRequestsNotifier.new,
);

// --- Location State ---
class LocationNotifier extends Notifier<GeoPoint> {
  static const String _firstScanDoneKey = 'smartmove_first_location_scan_attempted_v1';

  @override
  GeoPoint build() {
    _initializeLocation();
    return GeoPoint.none; // Compulsory scan or fall to nothing
  }

  Future<void> _initializeLocation() async {
    // 1. Check if user already has a saved/chosen location
    final persisted = await LocationService.restorePersistedLocation();
    if (!ref.mounted) return;
    if (persisted != null && persisted.isSet) {
      state = persisted;
      return;
    }

    // 2. Perform compulsory location scan on first run
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      final alreadyScanned = prefs.getBool(_firstScanDoneKey) ?? false;

      if (!alreadyScanned) {
        await prefs.setBool(_firstScanDoneKey, true);
        final scanned = await LocationService.getCurrentDeviceLocation();
        if (!ref.mounted) return;
        if (scanned != null && scanned.isSet) {
          setLocation(scanned);
          return;
        }
      }
    } catch (_) {}

    // 3. Fall to nothing (GeoPoint.none) when location scan is unavailable or rejected
    if (ref.mounted) {
      state = GeoPoint.none;
    }
  }

  void setLocation(GeoPoint newPoint) {
    state = newPoint;
    if (newPoint.isSet) {
      LocationService.persistLocation(newPoint);
    }
  }

  void clearLocation() {
    state = GeoPoint.none;
    LocationService.clearPersistedLocation();
  }

  Future<bool> detectDeviceLocation() async {
    final deviceLocation = await LocationService.getCurrentDeviceLocation();
    if (deviceLocation != null && deviceLocation.isSet) {
      setLocation(deviceLocation);
      return true;
    }
    return false;
  }
}

final locationProvider = NotifierProvider<LocationNotifier, GeoPoint>(
  LocationNotifier.new,
);

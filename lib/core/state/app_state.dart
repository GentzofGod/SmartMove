import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/price_observation.dart';
import '../models/seller_application.dart';
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
  List<Product> _allProducts = [];

  @override
  List<Product> build() {
    _fetchLive();
    return [];
  }

  Future<void> _fetchLive() async {
    final live = await SupabaseDataService.fetchProducts();
    if (live != null) {
      _allProducts = live;
      state = live;
    }
  }

  void filterCategory(String category) {
    if (category == 'All') {
      state = _allProducts;
    } else {
      state = _allProducts
          .where((p) => p.category.toLowerCase() == category.toLowerCase())
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
    _allProducts = [product, ..._allProducts];
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
    _allProducts = _allProducts.where((p) => p.id != productId).toList();
    state = _allProducts;
    SupabaseDataService.deleteProduct(productId);
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
        name: 'Default Plan',
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
        tradeOffExplanation: 'Default plan',
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

// --- Trader Negotiation Chat State ---
class TraderChatMessage {
  final String id;
  final String senderName;
  final bool isTrader;
  final String text;
  final DateTime timestamp;
  final double? proposedPrice;

  const TraderChatMessage({
    required this.id,
    required this.senderName,
    required this.isTrader,
    required this.text,
    required this.timestamp,
    this.proposedPrice,
  });
}

class TraderChatNotifier extends Notifier<Map<String, List<TraderChatMessage>>> {
  @override
  Map<String, List<TraderChatMessage>> build() {
    return {};
  }

  void sendCustomerMessage({
    required String traderName,
    required String commodityName,
    required double quantity,
    required String unit,
    required double listedPrice,
    required String messageText,
    double? proposedPrice,
  }) {
    final now = DateTime.now();
    final currentHistory = List<TraderChatMessage>.from(state[traderName] ?? []);

    // Initial greeting if history was empty
    if (currentHistory.isEmpty) {
      final lowerItem = commodityName.toLowerCase();
      final isHardwareOrSpares = lowerItem.contains('lathe') ||
          lowerItem.contains('spare') ||
          lowerItem.contains('tool') ||
          lowerItem.contains('bearing') ||
          lowerItem.contains('cutter') ||
          lowerItem.contains('hardware') ||
          lowerItem.contains('machine');
      final isElectronicsOrAppliances = lowerItem.contains('cooker') ||
          lowerItem.contains('kettle') ||
          lowerItem.contains('iron') ||
          lowerItem.contains('blender') ||
          lowerItem.contains('microwave') ||
          lowerItem.contains('appliance') ||
          lowerItem.contains('electronics') ||
          lowerItem.contains('fan') ||
          lowerItem.contains('tv');
      final isProduce = lowerItem.contains('tomato') ||
          lowerItem.contains('pepper') ||
          lowerItem.contains('egg') ||
          lowerItem.contains('yam') ||
          lowerItem.contains('vegetable') ||
          lowerItem.contains('fruit');

      final welcomeText = isHardwareOrSpares
          ? 'Hello! Thank you for inquiring about $commodityName. We have genuine stock ready. How can we assist you with this specification or order?'
          : (isElectronicsOrAppliances
              ? 'Hello! We have authentic, warrantied stock of $commodityName ready for you. How can we assist you today?'
              : (isProduce
                  ? 'Welcome! We have fresh, genuine harvest of $commodityName ready for you. How can I serve you today?'
                  : 'Welcome! We have verified stock of $commodityName ready for you. How can I serve you today?'));

      currentHistory.add(
        TraderChatMessage(
          id: 'welcome-${now.millisecondsSinceEpoch}',
          senderName: traderName,
          isTrader: true,
          text: welcomeText,
          timestamp: now.subtract(const Duration(minutes: 1)),
        ),
      );
    }

    // Append customer message
    currentHistory.add(
      TraderChatMessage(
        id: 'cust-${now.millisecondsSinceEpoch}',
        senderName: 'You',
        isTrader: false,
        text: messageText,
        timestamp: now,
        proposedPrice: proposedPrice,
      ),
    );

    state = {
      ...state,
      traderName: currentHistory,
    };

    // Simulate responsive trader reply
    _simulateTraderReply(
      traderName: traderName,
      commodityName: commodityName,
      quantity: quantity,
      listedPrice: listedPrice,
      unit: unit,
      proposedPrice: proposedPrice,
      customerQuery: messageText,
    );
  }

  void _simulateTraderReply({
    required String traderName,
    required String commodityName,
    required double quantity,
    required double listedPrice,
    required String unit,
    double? proposedPrice,
    required String customerQuery,
  }) {
    final totalListed = listedPrice * quantity;
    final qtyDisplay = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString();
    String replyText;

    if (proposedPrice != null) {
      final discountPct = (totalListed - proposedPrice) / (totalListed > 0 ? totalListed : 1.0);
      if (discountPct <= 0) {
        replyText = 'Deal agreed! I appreciate your patronage for $qtyDisplay $unit of $commodityName. I will prepare your order for pickup right away.';
      } else if (discountPct <= 0.15) {
        replyText = 'Deal agreed! As a valued SmartMove customer, I accept your offer of ₦${proposedPrice.toStringAsFixed(0)} for $qtyDisplay $unit of $commodityName. Please come to my stall for prompt pickup!';
      } else {
        final fairCounter = (totalListed * 0.90).roundToDouble();
        replyText = '₦${proposedPrice.toStringAsFixed(0)} is below our cost price for Grade A $commodityName. The best discount I can offer today is ₦${fairCounter.toStringAsFixed(0)} for the $qtyDisplay $unit. Would that work for you?';
      }
    } else {
      final lower = customerQuery.toLowerCase();
      if (lower.contains('bulk') || lower.contains('discount')) {
        replyText = 'Yes! For purchases of 5 or more units, we offer up to 8% discount. How many $unit do you need in total?';
      } else if (lower.contains('quality') || lower.contains('grade')) {
        final isProduce = commodityName.toLowerCase().contains('egg') ||
            commodityName.toLowerCase().contains('tomato') ||
            commodityName.toLowerCase().contains('pepper') ||
            commodityName.toLowerCase().contains('yam') ||
            commodityName.toLowerCase().contains('fruit');
        replyText = isProduce
            ? 'All our $commodityName is Grade A certified and freshly harvested. You can inspect it when you arrive.'
            : 'All our $commodityName is authentic, high-quality specification. You are welcome to inspect it upon pickup.';
      } else if (lower.contains('pickup') || lower.contains('hold') || lower.contains('minutes')) {
        replyText = 'Certainly! I will set aside your $qtyDisplay $unit of $commodityName now. Please ask for my stall when you arrive at the market.';
      } else if (lower.contains('deliver')) {
        replyText = 'Yes, dispatch riders are available at our hub for delivery within the city. Delivery fee depends on your destination.';
      } else if (lower.contains('cash') || lower.contains('transfer')) {
        replyText = 'We accept both instant bank transfer and cash on physical pickup at our stall.';
      } else {
        replyText = 'Thank you for your message! Our $commodityName is in stock and available at ₦${listedPrice.toStringAsFixed(0)} per $unit. We look forward to fulfilling your order!';
      }
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      final updatedHistory = List<TraderChatMessage>.from(state[traderName] ?? []);
      updatedHistory.add(
        TraderChatMessage(
          id: 'trader-${DateTime.now().millisecondsSinceEpoch}',
          senderName: traderName,
          isTrader: true,
          text: replyText,
          timestamp: DateTime.now(),
        ),
      );
      state = {
        ...state,
        traderName: updatedHistory,
      };
    });
  }
}

final traderChatProvider =
    NotifierProvider<TraderChatNotifier, Map<String, List<TraderChatMessage>>>(
  TraderChatNotifier.new,
);

// --- Community Observations State ---
class CommunityNotifier extends Notifier<List<PriceObservation>> {
  @override
  List<PriceObservation> build() {
    _fetchLive();
    return [];
  }

  Future<void> _fetchLive() async {
    final live = await SupabaseDataService.fetchObservations();
    if (live != null) {
      state = live;
    }
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
  }) {
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
    );
    state = [newObs, ...state];

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
  }

  void updateListingDetails({
    required String id,
    required double price,
    String? unit,
    String? brandOrGrade,
    bool? inStock,
    String? notes,
    String? channel,
    String? sellerName,
    String? marketLocation,
  }) {
    state = [
      for (final o in state)
        if (o.id == id)
          o.copyWith(
            price: price,
            unit: unit ?? o.unit,
            brandOrGrade: brandOrGrade ?? o.brandOrGrade,
            inStock: inStock ?? o.inStock,
            notes: notes ?? o.notes,
            channel: channel ?? o.channel,
            sellerName: sellerName ?? o.sellerName,
            marketLocation: marketLocation ?? o.marketLocation,
            timestamp: DateTime.now(),
            standardizedUnitPrice: () {
              final effectiveUnit = unit ?? o.unit;
              final mult = CommodityComparisonService.calculateUnitMultiplier(
                  effectiveUnit,
                  commodityName: o.productName);
              return mult > 0 ? (price / mult) : price;
            }(),
          )
        else
          o,
    ];
  }

  void toggleListingStock(String id) {
    state = [
      for (final o in state)
        if (o.id == id)
          o.copyWith(
            inStock: !o.inStock,
            timestamp: DateTime.now(),
          )
        else
          o,
    ];
  }

  void deleteListing(String id) {
    state = state.where((o) => o.id != id).toList();
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
  }
}

final communityProvider =
    NotifierProvider<CommunityNotifier, List<PriceObservation>>(
  CommunityNotifier.new,
);

// --- Auth State ---
class AuthNotifier extends Notifier<UserSession> {
  @override
  UserSession build() {
    _restoreSession();
    return UserSession.guest;
  }

  Future<void> _restoreSession() async {
    final session = await AuthService.restorePersistedSession();
    state = session;
  }

  /// Live refresh of user role and attributes from Supabase profiles table
  Future<void> refreshProfileFromDatabase() async {
    final live = await AuthService.syncCurrentUserProfile();
    if (live != null) {
      state = live;
    }
  }

  void setSession(UserSession session) {
    state = session;
    AuthService.persistSession(session);
  }

  void updateRole(String newRole) {
    String? defaultBiz = state.businessName;
    String? defaultHub = state.marketHub;
    String? defaultChannel = state.sellerChannel;
    if (newRole == 'Trader' && (defaultBiz == null || defaultBiz.isEmpty)) {
      defaultBiz = '${state.displayName}\'s Store';
      defaultHub = defaultHub ?? 'Bodija Market';
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
  }) {
    state = state.copyWith(
      businessName: businessName ?? state.businessName,
      marketHub: marketHub ?? state.marketHub,
      sellerChannel: sellerChannel ?? state.sellerChannel,
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
  }) {
    state = state.copyWith(
      businessName: businessName,
      marketHub: marketHub,
      sellerChannel: sellerChannel,
      phone: phone,
      stallLocation: stallLocation,
      sellerApplicationStatus: SellerApplicationStatus.pending,
    );
    AuthService.persistSession(state);
  }

  void approveSellerStatus() {
    state = state.copyWith(
      role: 'Trader',
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
  @override
  List<SellerApplication> build() {
    _fetchLive();
    return _getInitialApplications();
  }

  Future<void> _fetchLive() async {
    final live = await SupabaseDataService.fetchSellerApplications();
    if (live != null && live.isNotEmpty) {
      state = live;
    }
  }

  List<SellerApplication> _getInitialApplications() {
    final now = DateTime.now();
    return [
      SellerApplication(
        id: 'app-seed-001',
        userId: 'usr-kudirat',
        applicantName: 'Alhaja Kudirat',
        applicantEmail: 'kudirat.grains@gmail.com',
        businessName: 'Alhaja Kudirat Grains & Staples',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        stallLocation: 'Stall B44, Bodija Market Wholesale Hub',
        phone: '+234 803 234 5678',
        status: SellerApplicationStatus.pending,
        submittedAt: now.subtract(const Duration(hours: 3)),
      ),
    ];
  }

  void submitApplication({
    required UserSession user,
    required String businessName,
    required String marketHub,
    required String sellerChannel,
    required String phone,
    String? stallLocation,
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
      phone: phone,
      status: SellerApplicationStatus.pending,
      submittedAt: DateTime.now(),
    );

    state = [newApp, ...state];

    // Asynchronously sync to Cloud Supabase
    SupabaseDataService.insertSellerApplication(newApp);

    // Update current user session to pending review
    ref.read(authProvider.notifier).submitSellerApplication(
          businessName: businessName,
          marketHub: marketHub,
          sellerChannel: sellerChannel,
          phone: phone,
          stallLocation: stallLocation,
        );
  }

  void approveApplication(String applicationId) {
    state = [
      for (final app in state)
        if (app.id == applicationId)
          app.copyWith(
            status: SellerApplicationStatus.approved,
            reviewedAt: DateTime.now(),
          )
        else
          app,
    ];

    // Asynchronously sync approval to Cloud Supabase
    SupabaseDataService.updateSellerApplicationStatus(
      applicationId: applicationId,
      status: SellerApplicationStatus.approved,
    );

    // If the approved application belongs to current user, upgrade them to Trader
    final currentUser = ref.read(authProvider);
    final appMatches = state.where((a) => a.id == applicationId);
    if (appMatches.isNotEmpty && appMatches.first.userId == currentUser.id) {
      ref.read(authProvider.notifier).approveSellerStatus();
    }
  }

  void rejectApplication(String applicationId, {required String reason}) {
    state = [
      for (final app in state)
        if (app.id == applicationId)
          app.copyWith(
            status: SellerApplicationStatus.rejected,
            reviewedAt: DateTime.now(),
            rejectionReason: reason,
          )
        else
          app,
    ];

    // Asynchronously sync rejection to Cloud Supabase
    SupabaseDataService.updateSellerApplicationStatus(
      applicationId: applicationId,
      status: SellerApplicationStatus.rejected,
      reason: reason,
    );

    // If the rejected application belongs to current user, mark rejected
    final currentUser = ref.read(authProvider);
    final appMatches = state.where((a) => a.id == applicationId);
    if (appMatches.isNotEmpty && appMatches.first.userId == currentUser.id) {
      ref.read(authProvider.notifier).rejectSellerStatus(reason: reason);
    }
  }
}

final sellerApplicationsProvider =
    NotifierProvider<SellerApplicationsNotifier, List<SellerApplication>>(
  SellerApplicationsNotifier.new,
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

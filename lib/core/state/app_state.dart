import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/price_observation.dart';
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

// --- Products State ---
class ProductsNotifier extends Notifier<List<Product>> {
  List<Product> _allProducts = DemoSeedData.getProducts();

  @override
  List<Product> build() {
    _fetchLive();
    return DemoSeedData.getProducts();
  }

  Future<void> _fetchLive() async {
    final live = await SupabaseDataService.fetchProducts();
    if (live != null && live.isNotEmpty) {
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

  PlanCandidate get selectedPlan =>
      candidates.firstWhere((p) => p.id == selectedPlanId,
          orElse: () => candidates.first);

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
    return _calculateState(
      budget: 15000,
      transportCost: 1200,
      timeHours: 3.0,
      maxStops: 4,
      timeCost: 0.0,
      delayNonUrgent: false,
      selectedId: 'plan-a',
      items: initialItems,
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
    state = _calculateState(
      budget: budget ?? state.budget,
      transportCost: state.transportCost,
      timeHours: state.timeAvailableHours,
      maxStops: state.maxStops,
      timeCost: state.timeCostPerHour,
      delayNonUrgent: state.delayNonUrgent,
      selectedId: state.selectedPlanId,
      items: items,
      errands: errands ?? state.activeErrands,
    );
  }

  void addShoppingItem(ShoppingItem item) {
    final updated = [...state.activeItems, item];
    state = _calculateState(
      budget: state.budget,
      transportCost: state.transportCost,
      timeHours: state.timeAvailableHours,
      maxStops: state.maxStops,
      timeCost: state.timeCostPerHour,
      delayNonUrgent: state.delayNonUrgent,
      selectedId: state.selectedPlanId,
      items: updated,
      errands: state.activeErrands,
    );
  }

  void removeShoppingItem(String itemId) {
    final updated = state.activeItems.where((i) => i.id != itemId).toList();
    state = _calculateState(
      budget: state.budget,
      transportCost: state.transportCost,
      timeHours: state.timeAvailableHours,
      maxStops: state.maxStops,
      timeCost: state.timeCostPerHour,
      delayNonUrgent: state.delayNonUrgent,
      selectedId: state.selectedPlanId,
      items: updated,
      errands: state.activeErrands,
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

    state = _calculateState(
      budget: newBudget,
      transportCost: newTransport,
      timeHours: newHours,
      maxStops: newStops,
      timeCost: state.timeCostPerHour,
      delayNonUrgent: newDelay,
      selectedId: newSelectedId,
      items: items,
      errands: errands,
    );
  }

  void updateBudget(double newBudget) {
    state = _calculateState(
      budget: newBudget,
      transportCost: state.transportCost,
      timeHours: state.timeAvailableHours,
      maxStops: state.maxStops,
      timeCost: state.timeCostPerHour,
      delayNonUrgent: state.delayNonUrgent,
      selectedId: state.selectedPlanId,
      items: state.activeItems,
      errands: state.activeErrands,
    );
  }

  void updateTransport(double newTransport) {
    state = _calculateState(
      budget: state.budget,
      transportCost: newTransport,
      timeHours: state.timeAvailableHours,
      maxStops: state.maxStops,
      timeCost: state.timeCostPerHour,
      delayNonUrgent: state.delayNonUrgent,
      selectedId: state.selectedPlanId,
      items: state.activeItems,
      errands: state.activeErrands,
    );
  }

  void updateTimeAvailable(double newHours) {
    state = _calculateState(
      budget: state.budget,
      transportCost: state.transportCost,
      timeHours: newHours,
      maxStops: state.maxStops,
      timeCost: state.timeCostPerHour,
      delayNonUrgent: state.delayNonUrgent,
      selectedId: state.selectedPlanId,
      items: state.activeItems,
      errands: state.activeErrands,
    );
  }

  void updateMaxStops(int newStops) {
    state = _calculateState(
      budget: state.budget,
      transportCost: state.transportCost,
      timeHours: state.timeAvailableHours,
      maxStops: newStops,
      timeCost: state.timeCostPerHour,
      delayNonUrgent: state.delayNonUrgent,
      selectedId: state.selectedPlanId,
      items: state.activeItems,
      errands: state.activeErrands,
    );
  }

  void updateTimeCostPerHour(double newCost) {
    state = _calculateState(
      budget: state.budget,
      transportCost: state.transportCost,
      timeHours: state.timeAvailableHours,
      maxStops: state.maxStops,
      timeCost: newCost,
      delayNonUrgent: state.delayNonUrgent,
      selectedId: state.selectedPlanId,
      items: state.activeItems,
      errands: state.activeErrands,
    );
  }

  void toggleDelayNonUrgent(bool delay) {
    state = _calculateState(
      budget: state.budget,
      transportCost: state.transportCost,
      timeHours: state.timeAvailableHours,
      maxStops: state.maxStops,
      timeCost: state.timeCostPerHour,
      delayNonUrgent: delay,
      selectedId: state.selectedPlanId,
      items: state.activeItems,
      errands: state.activeErrands,
    );
  }

  void selectPlan(String planId) {
    state = state.copyWith(selectedPlanId: planId);
  }
}

final decisionLabProvider =
    NotifierProvider<DecisionLabNotifier, DecisionLabState>(
  DecisionLabNotifier.new,
);

// --- Community Observations State ---
class CommunityNotifier extends Notifier<List<PriceObservation>> {
  @override
  List<PriceObservation> build() {
    _fetchLive();
    return DemoSeedData.getCommunityObservations();
  }

  Future<void> _fetchLive() async {
    final live = await SupabaseDataService.fetchObservations();
    if (live != null && live.isNotEmpty) {
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
  }) {
    final newObs = PriceObservation(
      id: 'obs-${DateTime.now().millisecondsSinceEpoch}',
      productId: 'p-custom',
      productName: productName,
      sellerName: sellerName,
      marketLocation: sellerName,
      price: price,
      unit: unit,
      timestamp: DateTime.now(),
      sourceType: submitterRole == 'Trader'
          ? ObservationSource.traderConfirmed
          : ObservationSource.communityReported,
      submitterName: submitterName,
      submitterRole: submitterRole,
      isVerified: submitterRole == 'Trader' || submitterRole == 'Admin',
      notes: 'Submitted via SmartMove app.',
      channel: channel,
      brandOrGrade: brandOrGrade,
      inStock: inStock,
      standardizedUnitPrice: standardizedUnitPrice ?? price,
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

  void setSession(UserSession session) {
    state = session;
    AuthService.persistSession(session);
  }

  void updateRole(String newRole) {
    state = state.copyWith(role: newRole);
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

// --- Location State ---
class LocationNotifier extends Notifier<GeoPoint> {
  @override
  GeoPoint build() {
    _restoreLocation();
    return LocationService.defaultHub;
  }

  Future<void> _restoreLocation() async {
    final persisted = await LocationService.restorePersistedLocation();
    if (persisted != null) {
      state = persisted;
    }
  }

  void setLocation(GeoPoint newPoint) {
    state = newPoint;
    LocationService.persistLocation(newPoint);
  }

  Future<bool> detectDeviceLocation() async {
    final deviceLocation = await LocationService.getCurrentDeviceLocation();
    if (deviceLocation != null) {
      setLocation(deviceLocation);
      return true;
    }
    return false;
  }
}

final locationProvider = NotifierProvider<LocationNotifier, GeoPoint>(
  LocationNotifier.new,
);

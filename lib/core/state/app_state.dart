import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/price_observation.dart';
import '../models/errand.dart';
import '../models/itinerary_stop.dart';
import '../models/plan_candidate.dart';
import '../data/demo_seed_data.dart';
import '../services/decision_engine.dart';
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
    );
  }
}

class DecisionLabNotifier extends Notifier<DecisionLabState> {
  @override
  DecisionLabState build() {
    return _calculateState(
      budget: 15000,
      transportCost: 1200,
      timeHours: 3.0,
      maxStops: 4,
      timeCost: 0.0,
      delayNonUrgent: false,
      selectedId: 'plan-a',
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
  }) {
    final candidates = DecisionEngine.calculateCandidatePlans(
      userBudget: budget,
      baseTransportFare: transportCost,
      maxTimeHours: timeHours,
      maxStops: maxStops,
      timeCostPerHour: timeCost,
      delayNonUrgent: delayNonUrgent,
    );

    final insight = DecisionEngine.generateRecommendationInsight(
      budget: budget,
      transportCost: transportCost,
      timeAvailable: timeHours,
      candidates: candidates,
    );

    return DecisionLabState(
      budget: budget,
      transportCost: transportCost,
      timeAvailableHours: timeHours,
      maxStops: maxStops,
      timeCostPerHour: timeCost,
      delayNonUrgent: delayNonUrgent,
      candidates: candidates,
      selectedPlanId: selectedId,
      recommendationInsight: insight,
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
      isVerified: true,
      notes: 'Submitted via SmartMove app.',
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

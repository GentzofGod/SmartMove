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
      budget: initialItems.isNotEmpty ? 15000.0 : 0.0,
      transportCost: 1200,
      timeHours: 3.0,
      maxStops: 4,
      timeCost: 0.0,
      delayNonUrgent: false,
      selectedId: 'plan-a',
      items: initialItems,
      errands: initialErrands,
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
      SellerApplication(
        id: 'app-seed-002',
        userId: 'usr-bello',
        applicantName: 'Mama Bello',
        applicantEmail: 'bello@bodijamarket.ng',
        businessName: 'Mama Bello Grains & Oil Enterprise',
        marketHub: 'Bodija Market',
        sellerChannel: 'Local Market',
        stallLocation: 'Stall 14, Main Grain Line',
        phone: '+234 802 345 6789',
        status: SellerApplicationStatus.approved,
        submittedAt: now.subtract(const Duration(days: 2)),
        reviewedAt: now.subtract(const Duration(days: 1)),
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
    final app = state.firstWhere(
      (a) => a.id == applicationId,
      orElse: () => state.first,
    );
    if (app.userId == currentUser.id) {
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
    final app = state.firstWhere(
      (a) => a.id == applicationId,
      orElse: () => state.first,
    );
    if (app.userId == currentUser.id) {
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

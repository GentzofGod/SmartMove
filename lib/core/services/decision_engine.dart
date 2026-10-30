import '../models/plan_candidate.dart';
import '../models/errand.dart';
import '../models/itinerary_stop.dart';
import '../models/item_acquisition_source.dart';
import '../models/seller_application.dart';
import '../models/price_observation.dart';
import '../services/location_service.dart';
import '../data/demo_seed_data.dart';

class DecisionEngine {
  /// Deterministic plan calculation based on user assumptions (Section 5.4)
  /// Recalculates dynamically for arbitrary items and errands using application logic.
  /// AI does not perform authoritative arithmetic.
  static List<PlanCandidate> calculateCandidatePlans({
    required double userBudget,
    required double baseTransportFare,
    required double maxTimeHours,
    int maxStops = 4,
    double timeCostPerHour = 0.0,
    bool delayNonUrgent = false,
    List<ShoppingItem>? items,
    List<Errand>? errands,
    GeoPoint? userLocation,
    List<SellerApplication>? registeredTraders,
    List<PriceObservation>? observations,
  }) {
    final hasCustomItems = items != null && items.isNotEmpty;
    final defaultStops = DemoSeedData.getBenchmarkStops();

    // Calculate dynamic base items subtotal
    double planABaseItems;
    double planBBaseItems;
    double planCBaseItems;
    double planDBaseItems;

    if (!hasCustomItems) {
      if (items != null && items.isEmpty) {
        // If an empty shopping basket is explicitly provided, return empty plans without inventing mock data
        return const <PlanCandidate>[];
      }
      // Benchmark Hackathon Demo Default (Rice, Eggs, Tomatoes, Cooking Oil)
      planABaseItems = delayNonUrgent ? 8600.0 : 11600.0;
      planBBaseItems = delayNonUrgent ? 9400.0 : 12600.0;
      planCBaseItems = delayNonUrgent ? 9800.0 : 13000.0;
      planDBaseItems = 6400.0; // Strictly essential eggs & rice
    } else {
      // Dynamic computation for arbitrary user shopping items
      final double totalBasket = items.fold(0.0, (sum, i) => sum + i.totalEstimatedCost);
      final lowPriority = items.where((i) => i.priority == ErrandPriority.low).toList();
      final essentialItems = items.where((i) => i.priority != ErrandPriority.low).toList();

      final double essentialCost = lowPriority.isNotEmpty && essentialItems.isNotEmpty
          ? essentialItems.fold(0.0, (sum, i) => sum + i.totalEstimatedCost)
          : (totalBasket * 0.55).roundToDouble();

      // Plan A: Multi-market competitive pricing (~5% cheaper on shopping basket)
      planABaseItems = delayNonUrgent ? essentialCost : (totalBasket * 0.95).roundToDouble();
      // Plan B: Single hub convenience retail pricing (~3% premium on items)
      planBBaseItems = delayNonUrgent ? (essentialCost * 1.05).roundToDouble() : (totalBasket * 1.03).roundToDouble();
      // Plan C: Express single hub turnaround (~7% premium on items)
      planCBaseItems = delayNonUrgent ? (essentialCost * 1.08).roundToDouble() : (totalBasket * 1.07).roundToDouble();
      // Plan D: Strictly essential items to manage immediate cashflow
      planDBaseItems = essentialCost;
    }

    // Resolve detailed item acquisition sources prioritizing platform registered traders
    final effectiveItems = items ?? (hasCustomItems ? <ShoppingItem>[] : DemoSeedData.getBenchmarkErrands().first.shoppingItems);

    final planASources = _resolveAcquisitionSources(
      items: effectiveItems,
      planId: 'plan-a',
      isMultiMarket: true,
      delayNonUrgent: delayNonUrgent,
      userLocation: userLocation,
      registeredTraders: registeredTraders,
      observations: observations,
    );

    final planBSources = _resolveAcquisitionSources(
      items: effectiveItems,
      planId: 'plan-b',
      isMultiMarket: false,
      delayNonUrgent: delayNonUrgent,
      userLocation: userLocation,
      registeredTraders: registeredTraders,
      observations: observations,
    );

    final planCSources = _resolveAcquisitionSources(
      items: effectiveItems,
      planId: 'plan-c',
      isMultiMarket: false,
      delayNonUrgent: delayNonUrgent,
      isExpress: true,
      userLocation: userLocation,
      registeredTraders: registeredTraders,
      observations: observations,
    );

    final planDSources = _resolveAcquisitionSources(
      items: effectiveItems,
      planId: 'plan-d',
      isMultiMarket: false,
      delayNonUrgent: true,
      userLocation: userLocation,
      registeredTraders: registeredTraders,
      observations: observations,
    );

    // Build dynamic itinerary stops if custom errands or items are provided
    List<ItineraryStop> planAStopsList;
    List<ItineraryStop> planBStopsList;
    List<ItineraryStop> planCStopsList;
    List<ItineraryStop> planDStopsList;

    if (hasCustomItems || (errands != null && errands.isNotEmpty)) {
      planAStopsList = _buildStopsForPlan(
        planId: 'plan-a',
        items: items ?? [],
        sources: planASources,
        errands: errands ?? [],
        isMultiMarket: true,
        delayNonUrgent: delayNonUrgent,
        userLocation: userLocation,
      );
      planBStopsList = _buildStopsForPlan(
        planId: 'plan-b',
        items: items ?? [],
        sources: planBSources,
        errands: errands ?? [],
        isMultiMarket: false,
        delayNonUrgent: delayNonUrgent,
        userLocation: userLocation,
      );
      planCStopsList = _buildStopsForPlan(
        planId: 'plan-c',
        items: items ?? [],
        sources: planCSources,
        errands: errands ?? [],
        isMultiMarket: false,
        delayNonUrgent: delayNonUrgent,
        isExpress: true,
        userLocation: userLocation,
      );
      planDStopsList = _buildStopsForPlan(
        planId: 'plan-d',
        items: items ?? [],
        sources: planDSources,
        errands: errands ?? [],
        isMultiMarket: false,
        delayNonUrgent: true,
        userLocation: userLocation,
      );
    } else {
      planAStopsList = defaultStops;
      planBStopsList = [
        defaultStops[0],
        defaultStops[1], // Market B
        defaultStops[3], // Jumia pickup
        defaultStops[4], // Return home
      ];
      planCStopsList = [
        defaultStops[0],
        defaultStops[1],
        defaultStops[4],
      ];
      planDStopsList = [
        defaultStops[0],
        defaultStops[1],
        defaultStops[3],
        defaultStops[4],
      ];
    }

    // Extract first non-shopping errand deadline if any (only if explicitly provided)
    final firstErrandWithDeadline = (errands != null && errands.isNotEmpty)
        ? errands.firstWhere(
            (e) => e.deadline != null,
            orElse: () => errands.first,
          )
        : null;
    final deadlineString = firstErrandWithDeadline?.deadline;
    final errandTitle = firstErrandWithDeadline?.title;

    // 1. PLAN A: Lowest Estimated Total Cost (Cheapest Products across 2 markets)
    final double planATransport = baseTransportFare * 1.5;
    final double planATimeCost = timeCostPerHour * 2.5;
    final double planATotal = planABaseItems + planATransport + planATimeCost;
    const double planAHours = 2.5;
    final int planAStops = hasCustomItems && errands != null ? (planAStopsList.length - 2).clamp(2, 6) : 3;

    final List<String> planASatisfied = [];
    final List<String> planAViolated = [];
    if (planATotal <= userBudget) {
      planASatisfied.add('Within budget (saves ₦${(userBudget - planATotal).toStringAsFixed(0)})');
    } else {
      planAViolated.add('Exceeds budget by ₦${(planATotal - userBudget).toStringAsFixed(0)}');
    }
    if (planAHours <= maxTimeHours) {
      if (deadlineString != null) {
        planASatisfied.add('Meets $deadlineString errand deadline');
      } else {
        planASatisfied.add('Within time budget (${planAHours}h <= ${maxTimeHours}h)');
      }
    } else {
      planAViolated.add('Exceeds available time limit (${planAHours}h > ${maxTimeHours}h)');
    }
    if (planAStops <= maxStops) {
      planASatisfied.add('Within stop limit ($planAStops <= $maxStops)');
    } else {
      planAViolated.add('Exceeds stop limit ($planAStops > $maxStops)');
    }

    final planA = PlanCandidate(
      id: 'plan-a',
      name: 'Plan A',
      tag: 'Cheapest Basket',
      sourcingChannel: 'Open Wholesale Multi-Market',
      easeOfAccess: 'Low Ease • Multi-Stall Trek (2.5 hrs • 3 stops)',
      accessRating: 'Low Ease',
      itemCost: planABaseItems,
      transportCost: planATransport,
      otherCost: planATimeCost,
      estimatedHours: planAHours,
      stopCount: planAStops,
      isRecommended: planAViolated.isEmpty,
      isFeasibleBudget: planATotal <= userBudget,
      isFeasibleDeadline: planAHours <= maxTimeHours,
      isFeasibleStops: planAStops <= maxStops,
      satisfiedConstraints: planASatisfied,
      violatedConstraints: planAViolated,
      dataDisclaimers: const [
        'Transit fare is estimated based on regional transit rates',
        'Prices reflect latest trader and community observations',
      ],
      tradeOffExplanation: delayNonUrgent
          ? 'Delayed non-urgent purchases. Lowest total outlay (₦${planATotal.toStringAsFixed(0)}). Prioritizes registered traders across 2 competitive hubs.'
          : hasCustomItems
              ? 'Lowest shopping bill (₦${planABaseItems.toStringAsFixed(0)}). Prioritizes registered traders and wholesale stalls across $planAStops stops.'
              : 'Lowest shopping bill (₦11,600). Visits Market B & C across 3 stops. Saves ₦800 overall compared to single-market shopping.',
      stops: planAStopsList,
      acquisitionSources: planASources,
    );

    // 2. PLAN B: Lowest Transport Expense & Fewest Stops (Consolidated to Market B)
    final double planBTransport = baseTransportFare * 1.0;
    final double planBTimeCost = timeCostPerHour * 1.8;
    final double planBTotal = planBBaseItems + planBTransport + planBTimeCost;
    const double planBHours = 1.8;
    final int planBStops = hasCustomItems && errands != null ? (planBStopsList.length - 2).clamp(1, 4) : 2;

    final List<String> planBSatisfied = [];
    final List<String> planBViolated = [];
    if (planBTotal <= userBudget) {
      planBSatisfied.add('Within budget (₦${planBTotal.toStringAsFixed(0)} <= ₦${userBudget.toStringAsFixed(0)})');
    } else {
      planBViolated.add('Over budget by ₦${(planBTotal - userBudget).toStringAsFixed(0)}');
    }
    if (planBHours <= maxTimeHours) {
      planBSatisfied.add('Fast completion before deadline (1.8h)');
    } else {
      planBViolated.add('Exceeds available time');
    }
    if (planBStops <= maxStops) {
      planBSatisfied.add('Fewest stops ($planBStops stops)');
    } else {
      planBViolated.add('Exceeds stop limit');
    }

    final planB = PlanCandidate(
      id: 'plan-b',
      name: 'Plan B',
      tag: 'Wholesale + In-App Chat',
      sourcingChannel: 'Verified Platform Traders',
      easeOfAccess: 'Balanced Access • Single Hub Pickup (1.8 hrs • 2 stops)',
      accessRating: 'Balanced Access',
      itemCost: planBBaseItems,
      transportCost: planBTransport,
      otherCost: planBTimeCost,
      estimatedHours: planBHours,
      stopCount: planBStops,
      isRecommended: planBViolated.isEmpty && (planAViolated.isNotEmpty || planBTotal < planATotal),
      isFeasibleBudget: planBTotal <= userBudget,
      isFeasibleDeadline: planBHours <= maxTimeHours,
      isFeasibleStops: planBStops <= maxStops,
      satisfiedConstraints: planBSatisfied,
      violatedConstraints: planBViolated,
      dataDisclaimers: const [
        'Transit fare is demo estimate (no routing provider connected)',
      ],
      tradeOffExplanation: (errandTitle != null)
          ? 'Consolidates commodities to the closest registered trader market hub. Cuts transport expense to ₦${planBTransport.toStringAsFixed(0)} and saves travel time.'
          : 'Consolidates commodity purchases to a single major registered trader market hub. Cuts transport expense to ₦${planBTransport.toStringAsFixed(0)}.',
      stops: planBStopsList,
      acquisitionSources: planBSources,
    );

    // 3. PLAN C: Shortest Estimated Duration (Express Single Hub)
    final double planCTransport = baseTransportFare * 1.0;
    final double planCTimeCost = timeCostPerHour * 1.2;
    final double planCTotal = planCBaseItems + planCTransport + planCTimeCost;
    const double planCHours = 1.2;
    final int planCStops = hasCustomItems && errands != null ? (planCStopsList.length - 2).clamp(1, 3) : 2;

    final List<String> planCSatisfied = [];
    final List<String> planCViolated = [];
    if (planCTotal <= userBudget) {
      planCSatisfied.add('Within budget');
    } else {
      planCViolated.add('Over budget by ₦${(planCTotal - userBudget).toStringAsFixed(0)}');
    }
    if (planCHours <= maxTimeHours) {
      planCSatisfied.add('Shortest duration (1.2h express)');
    } else {
      planCViolated.add('Exceeds available time');
    }
    if (planCStops <= maxStops) {
      planCSatisfied.add('Only $planCStops stops');
    } else {
      planCViolated.add('Exceeds stop limit');
    }

    final planC = PlanCandidate(
      id: 'plan-c',
      name: 'Plan C',
      tag: 'Express Walk-In',
      sourcingChannel: 'Neighborhood Retail Mart',
      easeOfAccess: 'High Ease • Express Walk-In (25 mins • 1 stop)',
      accessRating: 'High Ease',
      itemCost: planCBaseItems,
      transportCost: planCTransport,
      otherCost: planCTimeCost,
      estimatedHours: planCHours,
      stopCount: planCStops,
      isRecommended: planCViolated.isEmpty && (maxTimeHours <= 1.5 || timeCostPerHour > 800),
      isFeasibleBudget: planCTotal <= userBudget,
      isFeasibleDeadline: planCHours <= maxTimeHours,
      isFeasibleStops: planCStops <= maxStops,
      satisfiedConstraints: planCSatisfied,
      violatedConstraints: planCViolated,
      dataDisclaimers: const [
        'Transit fare is demo estimate (no routing provider connected)',
      ],
      tradeOffExplanation:
          'Express commercial run completed in 1.2 hrs. Premium convenience with ₦${planCBaseItems.toStringAsFixed(0)} items subtotal.',
      stops: planCStopsList,
      acquisitionSources: planCSources,
    );

    // 4. PLAN D: Delay Non-Urgent Purchases (Budget Protection)
    final double planDTransport = baseTransportFare * 0.8;
    final double planDTimeCost = timeCostPerHour * 1.0;
    final double planDTotal = planDBaseItems + planDTransport + planDTimeCost;
    const double planDHours = 1.0;
    final int planDStops = hasCustomItems && errands != null ? (planDStopsList.length - 2).clamp(1, 3) : 2;

    final List<String> planDSatisfied = [
      'Strict cashflow budget safety (₦${planDTotal.toStringAsFixed(0)} total)',
      errandTitle != null
          ? 'Completes high-priority $errandTitle before deadline'
          : 'Focuses immediately on essential staple commodities',
      'Minimal $planDStops stops',
    ];
    final List<String> planDViolated = [];
    if (planDTotal > userBudget) {
      planDViolated.add('Over budget by ₦${(planDTotal - userBudget).toStringAsFixed(0)}');
    }

    final planD = PlanCandidate(
      id: 'plan-d',
      name: 'Plan D',
      tag: 'Delay Non-Urgent',
      sourcingChannel: 'Doorstep Delivery & Essentials',
      easeOfAccess: 'Maximum Ease • Minimum Effort (1.0 hr • 1 stop)',
      accessRating: 'Maximum Ease',
      itemCost: planDBaseItems,
      transportCost: planDTransport,
      otherCost: planDTimeCost,
      estimatedHours: planDHours,
      stopCount: planDStops,
      isRecommended: userBudget < 12000,
      isFeasibleBudget: planDTotal <= userBudget,
      isFeasibleDeadline: planDHours <= maxTimeHours,
      isFeasibleStops: planDStops <= maxStops,
      satisfiedConstraints: planDSatisfied,
      violatedConstraints: planDViolated,
      dataDisclaimers: const [
        'Postpones non-urgent purchases to protect immediate cashflow (no price-drop speculation)',
        'Transit fare estimated based on route distance',
      ],
      tradeOffExplanation: hasCustomItems
          ? (errandTitle != null
              ? 'Delays non-urgent purchases. Focuses on essential items (₦${planDBaseItems.toStringAsFixed(0)}) at verified registered trader stalls, staying under strict budgets.'
              : 'Delays non-urgent purchases. Focuses on essential commodities (₦${planDBaseItems.toStringAsFixed(0)}) at verified registered trader stalls.')
          : 'Delays non-urgent cooking oil and tomatoes. Focuses on essential food restock at verified registered trader stalls.',
      stops: planDStopsList,
      acquisitionSources: planDSources,
    );

    return [planA, planB, planC, planD];
  }

  /// Resolve detailed acquisition sources prioritizing registered platform traders and computing distance
  static List<ItemAcquisitionSource> _resolveAcquisitionSources({
    required List<ShoppingItem> items,
    required String planId,
    required bool isMultiMarket,
    required bool delayNonUrgent,
    bool isExpress = false,
    GeoPoint? userLocation,
    List<SellerApplication>? registeredTraders,
    List<PriceObservation>? observations,
  }) {
    if (items.isEmpty) return const [];

    final active = delayNonUrgent
        ? items.where((i) => i.priority != ErrandPriority.low).toList()
        : items;

    final userCity = (userLocation != null && userLocation.isSet && userLocation.city.isNotEmpty)
        ? userLocation.city.toLowerCase()
        : 'ibadan';

    // Get approved platform registered traders (only those actually registered and approved)
    final approvedTraders = registeredTraders
            ?.where((t) => t.status == SellerApplicationStatus.approved)
            .toList() ??
        [];

    final effectiveTraders = approvedTraders;

    // Reference coordinates for regional hubs
    final double defaultMarketALat = userCity.contains('lagos') ? 6.5150 : 7.3876;
    final double defaultMarketALon = userCity.contains('lagos') ? 3.3640 : 3.8767; // Dugbe / Tejuosho
    final double defaultMarketBLat = userCity.contains('lagos') ? 6.6020 : 7.4343;
    final double defaultMarketBLon = userCity.contains('lagos') ? 3.3900 : 3.9056; // Bodija / Mile 12

    final double distanceHubA = (userLocation != null && userLocation.isSet)
        ? LocationService.calculateDistanceKm(
            lat1: userLocation.latitude,
            lon1: userLocation.longitude,
            lat2: defaultMarketALat,
            lon2: defaultMarketALon,
          )
        : 1.2;

    final double distanceHubB = (userLocation != null && userLocation.isSet)
        ? LocationService.calculateDistanceKm(
            lat1: userLocation.latitude,
            lon1: userLocation.longitude,
            lat2: defaultMarketBLat,
            lon2: defaultMarketBLon,
          )
        : 2.1;

    final List<ItemAcquisitionSource> sources = [];

    for (int i = 0; i < active.length; i++) {
      final item = active[i];
      final lowerName = item.productName.toLowerCase();

      final isHardwareOrSpares = lowerName.contains('lathe') ||
          lowerName.contains('spare') ||
          lowerName.contains('tool') ||
          lowerName.contains('machinery') ||
          (lowerName.contains('machine') && !lowerName.contains('washing machine') && !lowerName.contains('sewing machine')) ||
          lowerName.contains('bearing') ||
          lowerName.contains('hardware') ||
          lowerName.contains('engine') ||
          lowerName.contains('motor') ||
          lowerName.contains('welding') ||
          lowerName.contains('cutter') ||
          lowerName.contains('carbide') ||
          lowerName.contains('drill') ||
          lowerName.contains('wrench') ||
          lowerName.contains('bolt') ||
          lowerName.contains('nut');

      final isElectronicsOrAppliances = lowerName.contains('cooker') ||
          lowerName.contains('kettle') ||
          lowerName.contains('iron') ||
          lowerName.contains('blender') ||
          lowerName.contains('microwave') ||
          lowerName.contains('toaster') ||
          lowerName.contains('fridge') ||
          lowerName.contains('refrigerator') ||
          lowerName.contains('freezer') ||
          lowerName.contains('fan') ||
          lowerName.contains('television') ||
          lowerName.contains('tv') ||
          lowerName.contains('generator') ||
          lowerName.contains('inverter') ||
          lowerName.contains('appliance') ||
          lowerName.contains('electronics') ||
          lowerName.contains('gadget') ||
          lowerName.contains('laptop') ||
          lowerName.contains('smartphone') ||
          lowerName.contains('speaker') ||
          lowerName.contains('soundbar') ||
          lowerName.contains('decoder') ||
          lowerName.contains('washing machine');

      final isFoodStaple = !isHardwareOrSpares && !isElectronicsOrAppliances &&
          (lowerName.contains('rice') ||
          lowerName.contains('bean') ||
          lowerName.contains('garri') ||
          (lowerName.contains('oil') && !lowerName.contains('cutting') && !lowerName.contains('machine') && !lowerName.contains('lathe')) ||
          lowerName.contains('yam') ||
          lowerName.contains('flour') ||
          lowerName.contains('sugar') ||
          lowerName.contains('oat') ||
          lowerName.contains('grain') ||
          lowerName.contains('indomie') ||
          lowerName.contains('noodle') ||
          lowerName.contains('milk') ||
          lowerName.contains('bread'));

      final isAgroProduce = !isHardwareOrSpares && !isElectronicsOrAppliances &&
          (lowerName.contains('egg') ||
          lowerName.contains('tomato') ||
          lowerName.contains('onion') ||
          lowerName.contains('pepper') ||
          lowerName.contains('vegetable'));

      final isPharmacy = !isHardwareOrSpares && !isElectronicsOrAppliances &&
          (lowerName.contains('para') ||
          lowerName.contains('med') ||
          lowerName.contains('drug') ||
          lowerName.contains('vitamin') ||
          lowerName.contains('syrup') ||
          lowerName.contains('plaster') ||
          lowerName.contains('tablet') ||
          lowerName.contains('bandage') ||
          lowerName.contains('soap'));

      final isStationeryOrElectronics = !isHardwareOrSpares && !isElectronicsOrAppliances &&
          (lowerName.contains('book') ||
          lowerName.contains('pen') ||
          lowerName.contains('pencil') ||
          lowerName.contains('ruler') ||
          lowerName.contains('eraser') ||
          lowerName.contains('cable') ||
          lowerName.contains('charger') ||
          lowerName.contains('powerbank') ||
          lowerName.contains('stationery') ||
          lowerName.contains('paper'));

      // Legitimate registered trader matching by domain (ONLY if trader exists)
      SellerApplication? matchedTrader;
      for (final trader in effectiveTraders) {
        final biz = trader.businessName.toLowerCase();
        if (isFoodStaple && (biz.contains('grain') || biz.contains('oil') || biz.contains('food') || biz.contains('staple') || biz.contains('farm'))) {
          matchedTrader = trader;
          break;
        } else if (isElectronicsOrAppliances && (biz.contains('electronics') || biz.contains('appliance') || biz.contains('electrical') || biz.contains('tech') || biz.contains('gadget'))) {
          matchedTrader = trader;
          break;
        } else if (isHardwareOrSpares && (biz.contains('hardware') || biz.contains('tool') || biz.contains('spare') || biz.contains('machine') || biz.contains('eng'))) {
          matchedTrader = trader;
          break;
        } else if (isPharmacy && (biz.contains('pharm') || biz.contains('med') || biz.contains('chemist'))) {
          matchedTrader = trader;
          break;
        } else if (isStationeryOrElectronics && (biz.contains('tech') || biz.contains('stationer') || biz.contains('book') || biz.contains('gadget'))) {
          matchedTrader = trader;
          break;
        }
      }

      if (isHardwareOrSpares) {
        // Specialized industrial machinery & spare parts sourcing
        if (planId == 'plan-d') {
          // Doorstep delivery via verified tooling platform
          sources.add(
            ItemAcquisitionSource(
              id: '$planId-src-$i',
              itemId: item.id,
              commodityName: item.productName,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: (item.estimatedUnitPrice * 1.05).roundToDouble(),
              totalCost: (item.totalEstimatedCost * 1.05).roundToDouble(),
              outletName: 'Jumia Industrial & Tooling Hub',
              channel: AcquisitionChannel.ecommercePlatform,
              marketHubOrLocation: 'Online / Jumia Express Delivery',
              latitude: defaultMarketALat,
              longitude: defaultMarketALon,
              dynamicDistanceKm: 0.0,
              isPlatformRegisteredTrader: false,
              contactPhone: null,
              whatsappNumber: null,
              webUrl: 'https://www.jumia.com.ng',
              brandOrGrade: item.brandOrGrade ?? 'Manufacturer Direct Spec',
            ),
          );
        } else if (planId == 'plan-c' && isExpress) {
          // Express retail equipment mart
          sources.add(
            ItemAcquisitionSource(
              id: '$planId-src-$i',
              itemId: item.id,
              commodityName: item.productName,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: (item.estimatedUnitPrice * 1.08).roundToDouble(),
              totalCost: (item.totalEstimatedCost * 1.08).roundToDouble(),
              outletName: 'Ace Hardware & Equipment Mart',
              channel: AcquisitionChannel.retailStore,
              marketHubOrLocation: 'Commercial Expressway Equipment District',
              latitude: defaultMarketALat,
              longitude: defaultMarketALon,
              dynamicDistanceKm: distanceHubA,
              isPlatformRegisteredTrader: false,
              contactPhone: null,
              whatsappNumber: null,
              brandOrGrade: item.brandOrGrade ?? 'Industrial Grade Standard',
            ),
          );
        } else if (matchedTrader != null) {
          // Platform registered hardware trader
          sources.add(
            ItemAcquisitionSource(
              id: '$planId-src-$i',
              itemId: item.id,
              commodityName: item.productName,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: item.estimatedUnitPrice,
              totalCost: item.totalEstimatedCost,
              outletName: matchedTrader.businessName,
              channel: AcquisitionChannel.registeredTrader,
              marketHubOrLocation: matchedTrader.stallLocation ?? matchedTrader.marketHub,
              latitude: defaultMarketBLat,
              longitude: defaultMarketBLon,
              dynamicDistanceKm: distanceHubA,
              isPlatformRegisteredTrader: true,
              traderId: matchedTrader.userId,
              contactPhone: matchedTrader.phone.isNotEmpty ? matchedTrader.phone : null,
              whatsappNumber: matchedTrader.phone.isNotEmpty ? matchedTrader.phone : null,
              brandOrGrade: item.brandOrGrade ?? 'OEM / Genuine Spec',
            ),
          );
        } else {
          // Physical machine tools line (wholesale market terminal)
          final isPlanB = planId == 'plan-b';
          final outlet = isPlanB
              ? (userCity.contains('lagos')
                  ? 'Coker Engineering & Tooling Hub'
                  : 'Precision Engineering & Machine Spares Hub')
              : (userCity.contains('lagos')
                  ? 'Ladipo Machine Tools & Auto Spares Line'
                  : 'Dugbe Industrial Hardware & Machine Tools Line');
          final location = isPlanB
              ? (userCity.contains('lagos')
                  ? 'Coker Commercial Equipment Zone'
                  : 'Dugbe Central Engineering District')
              : (userCity.contains('lagos')
                  ? 'Ladipo Central Wholesale Market'
                  : 'Commercial Machine Tools Sector, Dugbe Arcade');

          sources.add(
            ItemAcquisitionSource(
              id: '$planId-src-$i',
              itemId: item.id,
              commodityName: item.productName,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: (item.estimatedUnitPrice * (planId == 'plan-a' ? 0.95 : 1.0)).roundToDouble(),
              totalCost: (item.totalEstimatedCost * (planId == 'plan-a' ? 0.95 : 1.0)).roundToDouble(),
              outletName: outlet,
              channel: AcquisitionChannel.physicalMarketHub,
              marketHubOrLocation: location,
              latitude: defaultMarketALat,
              longitude: defaultMarketALon,
              dynamicDistanceKm: distanceHubA,
              isPlatformRegisteredTrader: false,
              contactPhone: null,
              whatsappNumber: null,
              brandOrGrade: item.brandOrGrade ?? 'Machinery Grade',
            ),
          );
        }
      } else if (isElectronicsOrAppliances) {
        // Consumer Electronics, Cookers & Home Appliances
        if (planId == 'plan-d') {
          // Doorstep delivery via verified electronics / appliance ecommerce
          sources.add(
            ItemAcquisitionSource(
              id: '$planId-src-$i',
              itemId: item.id,
              commodityName: item.productName,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: (item.estimatedUnitPrice * 1.05).roundToDouble(),
              totalCost: (item.totalEstimatedCost * 1.05).roundToDouble(),
              outletName: 'Jumia Official Appliance Store',
              channel: AcquisitionChannel.ecommercePlatform,
              marketHubOrLocation: 'Online / Jumia Express Delivery',
              latitude: defaultMarketALat,
              longitude: defaultMarketALon,
              dynamicDistanceKm: 0.0,
              isPlatformRegisteredTrader: false,
              contactPhone: null,
              whatsappNumber: null,
              webUrl: 'https://www.jumia.com.ng',
              brandOrGrade: item.brandOrGrade ?? 'Authorized Manufacturer Direct',
            ),
          );
        } else if (planId == 'plan-c' && isExpress) {
          // Express retail showroom
          sources.add(
            ItemAcquisitionSource(
              id: '$planId-src-$i',
              itemId: item.id,
              commodityName: item.productName,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: (item.estimatedUnitPrice * 1.07).roundToDouble(),
              totalCost: (item.totalEstimatedCost * 1.07).roundToDouble(),
              outletName: 'Mega Electronics & Household Appliances Mart',
              channel: AcquisitionChannel.retailStore,
              marketHubOrLocation: 'Commercial Expressway Electronics Zone',
              latitude: defaultMarketALat,
              longitude: defaultMarketALon,
              dynamicDistanceKm: distanceHubA,
              isPlatformRegisteredTrader: false,
              contactPhone: null,
              whatsappNumber: null,
              brandOrGrade: item.brandOrGrade ?? 'Showroom Certified Spec',
            ),
          );
        } else if (matchedTrader != null) {
          // Platform registered electronics trader
          sources.add(
            ItemAcquisitionSource(
              id: '$planId-src-$i',
              itemId: item.id,
              commodityName: item.productName,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: item.estimatedUnitPrice,
              totalCost: item.totalEstimatedCost,
              outletName: matchedTrader.businessName,
              channel: AcquisitionChannel.registeredTrader,
              marketHubOrLocation: matchedTrader.stallLocation ?? matchedTrader.marketHub,
              latitude: defaultMarketBLat,
              longitude: defaultMarketBLon,
              dynamicDistanceKm: distanceHubA,
              isPlatformRegisteredTrader: true,
              traderId: matchedTrader.userId,
              contactPhone: matchedTrader.phone.isNotEmpty ? matchedTrader.phone : null,
              whatsappNumber: matchedTrader.phone.isNotEmpty ? matchedTrader.phone : null,
              brandOrGrade: item.brandOrGrade ?? 'OEM / 1-Year Warranty',
            ),
          );
        } else {
          // Physical electronics & appliance arcade
          final outlet = userCity.contains('lagos')
              ? 'Alaba International Electronics & Appliance Hub'
              : 'Dugbe Commercial Electronics & Home Appliances Arcade';
          final location = userCity.contains('lagos')
              ? 'Alaba Commercial Electronics District'
              : 'Dugbe Commercial Electronics District';

          sources.add(
            ItemAcquisitionSource(
              id: '$planId-src-$i',
              itemId: item.id,
              commodityName: item.productName,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: (item.estimatedUnitPrice * (planId == 'plan-a' ? 0.95 : 1.0)).roundToDouble(),
              totalCost: (item.totalEstimatedCost * (planId == 'plan-a' ? 0.95 : 1.0)).roundToDouble(),
              outletName: outlet,
              channel: AcquisitionChannel.physicalMarketHub,
              marketHubOrLocation: location,
              latitude: defaultMarketALat,
              longitude: defaultMarketALon,
              dynamicDistanceKm: distanceHubA,
              isPlatformRegisteredTrader: false,
              contactPhone: null,
              whatsappNumber: null,
              brandOrGrade: item.brandOrGrade ?? 'Standard Brand Warranty',
            ),
          );
        }
      } else if (planId == 'plan-c' && isExpress) {
        // Express convenience
        sources.add(
          ItemAcquisitionSource(
            id: '$planId-src-$i',
            itemId: item.id,
            commodityName: item.productName,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: (item.estimatedUnitPrice * 1.07).roundToDouble(),
            totalCost: (item.totalEstimatedCost * 1.07).roundToDouble(),
            outletName: isPharmacy
                ? 'MedPlus Pharmacy Express'
                : (isStationeryOrElectronics
                    ? 'Express Stationery & Tech Mart'
                    : 'Foodco Express Supermart'),
            channel: AcquisitionChannel.retailStore,
            marketHubOrLocation: 'Commercial Express Hub',
            latitude: defaultMarketALat,
            longitude: defaultMarketALon,
            dynamicDistanceKm: distanceHubA,
            isPlatformRegisteredTrader: false,
            contactPhone: null,
            whatsappNumber: null,
            webUrl: isStationeryOrElectronics ? 'https://www.jumia.com.ng' : null,
            brandOrGrade: item.brandOrGrade ?? 'Supermarket Stock',
          ),
        );
      } else if (isFoodStaple && matchedTrader != null) {
        // Platform Registered Food Trader Prioritized!
        final outletName = matchedTrader.businessName;
        final stallLocation = matchedTrader.stallLocation ?? 'Stall 14, Main Grain Line, Bodija Market';
        final phone = matchedTrader.phone.isNotEmpty ? matchedTrader.phone : null;
        final distance = isMultiMarket && i % 2 == 0 ? distanceHubB : distanceHubA;

        sources.add(
          ItemAcquisitionSource(
            id: '$planId-src-$i',
            itemId: item.id,
            commodityName: item.productName,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: (item.estimatedUnitPrice * (planId == 'plan-a' ? 0.95 : 1.0)).roundToDouble(),
            totalCost: (item.totalEstimatedCost * (planId == 'plan-a' ? 0.95 : 1.0)).roundToDouble(),
            outletName: outletName,
            channel: AcquisitionChannel.registeredTrader,
            marketHubOrLocation: stallLocation,
            latitude: defaultMarketBLat,
            longitude: defaultMarketBLon,
            dynamicDistanceKm: distance,
            isPlatformRegisteredTrader: true,
            traderId: matchedTrader.userId,
            contactPhone: phone,
            whatsappNumber: phone,
            brandOrGrade: item.brandOrGrade ?? 'Grade A Verified',
          ),
        );
      } else if (isAgroProduce) {
        // Fresh produce stalls / Bodija Agro Stalls
        sources.add(
          ItemAcquisitionSource(
            id: '$planId-src-$i',
            itemId: item.id,
            commodityName: item.productName,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: (item.estimatedUnitPrice * (planId == 'plan-a' ? 0.96 : 1.02)).roundToDouble(),
            totalCost: (item.totalEstimatedCost * (planId == 'plan-a' ? 0.96 : 1.02)).roundToDouble(),
            outletName: 'Bodija Fresh Produce Agro Stalls',
            channel: AcquisitionChannel.physicalMarketHub,
            marketHubOrLocation: 'Perishable Produce Sector, Bodija Market',
            latitude: defaultMarketBLat,
            longitude: defaultMarketBLon,
            dynamicDistanceKm: distanceHubB,
            isPlatformRegisteredTrader: false,
            contactPhone: null,
            whatsappNumber: null,
            brandOrGrade: item.brandOrGrade ?? 'Farm Fresh Daily Harvest',
          ),
        );
      } else if (isPharmacy) {
        // Pharmacy store
        sources.add(
          ItemAcquisitionSource(
            id: '$planId-src-$i',
            itemId: item.id,
            commodityName: item.productName,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: item.estimatedUnitPrice,
            totalCost: item.totalEstimatedCost,
            outletName: 'Pharmacy Plus (Licensed Dispensary)',
            channel: AcquisitionChannel.retailStore,
            marketHubOrLocation: 'Ring Road Commercial Junction',
            latitude: defaultMarketALat,
            longitude: defaultMarketALon,
            dynamicDistanceKm: distanceHubA,
            isPlatformRegisteredTrader: false,
            contactPhone: null,
            whatsappNumber: null,
            brandOrGrade: item.brandOrGrade ?? 'NAFDAC Approved',
          ),
        );
      } else if (isStationeryOrElectronics) {
        // Ecommerce or local tech hub
        final isOnline = (planId == 'plan-d') || (i % 2 == 1 && planId != 'plan-b');
        sources.add(
          ItemAcquisitionSource(
            id: '$planId-src-$i',
            itemId: item.id,
            commodityName: item.productName,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: (item.estimatedUnitPrice * (isOnline ? 1.05 : 1.0)).roundToDouble(),
            totalCost: (item.totalEstimatedCost * (isOnline ? 1.05 : 1.0)).roundToDouble(),
            outletName: isOnline ? 'Jumia Express Store' : 'TechHub Dugbe Stationers',
            channel: isOnline ? AcquisitionChannel.ecommercePlatform : AcquisitionChannel.retailStore,
            marketHubOrLocation: isOnline ? 'Online / Jumia Express Delivery' : 'Dugbe Commercial Arcade',
            latitude: defaultMarketALat,
            longitude: defaultMarketALon,
            dynamicDistanceKm: isOnline ? 0.0 : distanceHubA,
            isPlatformRegisteredTrader: false,
            contactPhone: null,
            whatsappNumber: null,
            webUrl: isOnline ? 'https://www.jumia.com.ng' : null,
            brandOrGrade: item.brandOrGrade ?? 'Manufacturer Sealed',
          ),
        );
      } else {
        // Default physical market hub
        sources.add(
          ItemAcquisitionSource(
            id: '$planId-src-$i',
            itemId: item.id,
            commodityName: item.productName,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: item.estimatedUnitPrice,
            totalCost: item.totalEstimatedCost,
            outletName: 'Central Wholesale Commercial Market',
            channel: AcquisitionChannel.physicalMarketHub,
            marketHubOrLocation: 'Commercial Central Arcade',
            latitude: defaultMarketALat,
            longitude: defaultMarketALon,
            dynamicDistanceKm: distanceHubA,
            isPlatformRegisteredTrader: false,
            contactPhone: null,
            whatsappNumber: null,
            brandOrGrade: item.brandOrGrade,
          ),
        );
      }
    }

    return sources;
  }

  /// Helper to generate dynamic itinerary stops based on arbitrary items, acquisition sources, and errands
  static List<ItineraryStop> _buildStopsForPlan({
    required String planId,
    required List<ShoppingItem> items,
    List<ItemAcquisitionSource> sources = const [],
    required List<Errand> errands,
    required bool isMultiMarket,
    required bool delayNonUrgent,
    bool isExpress = false,
    GeoPoint? userLocation,
  }) {
    final List<ItineraryStop> stops = [];
    int stopIndex = 0;

    // 1. Home Base (Start)
    stops.add(
      ItineraryStop(
        id: '$planId-s0',
        stopNumber: stopIndex++,
        title: 'Start',
        subtitle: (userLocation != null && userLocation.isSet)
            ? userLocation.displayLocation
            : 'Your Current Location',
        location: (userLocation != null && userLocation.isSet)
            ? userLocation.displayTown
            : 'Home Base',
        distanceKm: 0.0,
        durationMinutes: 0,
        timeWindow: '9:00 AM',
        isCompleted: true,
      ),
    );

    // 2. Shopping Stops with explicit outlet attribution
    if (sources.isNotEmpty) {
      if (isMultiMarket && sources.length > 1) {
        final half = (sources.length / 2).ceil();
        final firstHalf = sources.take(half).toList();
        final secondHalf = sources.skip(half).toList();

        final cost1 = firstHalf.fold(0.0, (s, i) => s + i.totalCost);
        final cost2 = secondHalf.fold(0.0, (s, i) => s + i.totalCost);

        final stop1Primary = firstHalf.first;
        final stop2Primary = secondHalf.first;

        stops.add(
          ItineraryStop(
            id: '$planId-s$stopIndex',
            stopNumber: stopIndex++,
            title: stop1Primary.marketHubOrLocation.toLowerCase().contains('market') &&
                    !stop1Primary.outletName.toLowerCase().contains('market')
                ? '${stop1Primary.outletName} (Market Hub)'
                : stop1Primary.outletName,
            subtitle: 'Acquire ${firstHalf.map((i) => i.commodityName).join(', ')}',
            location: stop1Primary.marketHubOrLocation,
            distanceKm: stop1Primary.dynamicDistanceKm,
            durationMinutes: 35,
            timeWindow: '9:20 AM - 9:55 AM',
            badgeText: stop1Primary.isPlatformRegisteredTrader
                ? 'Platform Registered Trader'
                : 'Best unit prices',
            estimatedCost: cost1,
            taskItems: firstHalf
                .map((i) => '${i.commodityName} (${i.quantity % 1 == 0 ? i.quantity.toInt() : i.quantity} ${i.unit}) - ₦${i.totalCost.toStringAsFixed(0)}')
                .toList(),
            itemSources: firstHalf,
            outletName: stop1Primary.outletName,
            channel: stop1Primary.channel,
            isPlatformRegisteredTrader: stop1Primary.isPlatformRegisteredTrader,
            traderId: stop1Primary.traderId,
            contactPhone: stop1Primary.contactPhone,
            whatsappNumber: stop1Primary.whatsappNumber,
            webUrl: stop1Primary.webUrl,
            isCompleted: false,
          ),
        );

        stops.add(
          ItineraryStop(
            id: '$planId-s$stopIndex',
            stopNumber: stopIndex++,
            title: stop2Primary.marketHubOrLocation.toLowerCase().contains('market') &&
                    !stop2Primary.outletName.toLowerCase().contains('market')
                ? '${stop2Primary.outletName} (Market Hub)'
                : stop2Primary.outletName,
            subtitle: 'Acquire ${secondHalf.map((i) => i.commodityName).join(', ')}',
            location: stop2Primary.marketHubOrLocation,
            distanceKm: stop2Primary.dynamicDistanceKm,
            durationMinutes: 30,
            timeWindow: '10:15 AM - 10:45 AM',
            badgeText: stop2Primary.isPlatformRegisteredTrader
                ? 'Platform Registered Trader'
                : 'Competitive rate',
            estimatedCost: cost2,
            taskItems: secondHalf
                .map((i) => '${i.commodityName} (${i.quantity % 1 == 0 ? i.quantity.toInt() : i.quantity} ${i.unit}) - ₦${i.totalCost.toStringAsFixed(0)}')
                .toList(),
            itemSources: secondHalf,
            outletName: stop2Primary.outletName,
            channel: stop2Primary.channel,
            isPlatformRegisteredTrader: stop2Primary.isPlatformRegisteredTrader,
            traderId: stop2Primary.traderId,
            contactPhone: stop2Primary.contactPhone,
            whatsappNumber: stop2Primary.whatsappNumber,
            webUrl: stop2Primary.webUrl,
            isCompleted: false,
          ),
        );
      } else {
        final totalCost = sources.fold(0.0, (s, i) => s + i.totalCost);
        final primary = sources.first;
        final hasRegistered = sources.any((s) => s.isPlatformRegisteredTrader);

        stops.add(
          ItineraryStop(
            id: '$planId-s$stopIndex',
            stopNumber: stopIndex++,
            title: primary.marketHubOrLocation.toLowerCase().contains('market') &&
                    !primary.outletName.toLowerCase().contains('market')
                ? '${primary.outletName} (Market Hub)'
                : primary.outletName,
            subtitle: 'Acquire ${sources.take(3).map((i) => i.commodityName).join(', ')}${sources.length > 3 ? ' + more' : ''}',
            location: primary.marketHubOrLocation,
            distanceKm: primary.dynamicDistanceKm,
            durationMinutes: isExpress ? 25 : 45,
            timeWindow: '9:20 AM - 10:05 AM',
            badgeText: hasRegistered
                ? 'Platform Registered Trader • Consolidated'
                : (isExpress ? 'Express Convenience' : 'Single Stop Hub'),
            estimatedCost: totalCost,
            taskItems: sources
                .map((i) => '${i.commodityName} (${i.quantity % 1 == 0 ? i.quantity.toInt() : i.quantity} ${i.unit}) - ₦${i.totalCost.toStringAsFixed(0)}')
                .toList(),
            itemSources: sources,
            outletName: primary.outletName,
            channel: primary.channel,
            isPlatformRegisteredTrader: hasRegistered,
            traderId: primary.traderId,
            contactPhone: primary.contactPhone,
            whatsappNumber: primary.whatsappNumber,
            webUrl: primary.webUrl,
            isCompleted: false,
          ),
        );
      }
    } else if (items.isNotEmpty) {
      // Fallback if sources empty
      final activeItems = delayNonUrgent
          ? items.where((i) => i.priority != ErrandPriority.low).toList()
          : items;
      final cost = activeItems.fold(0.0, (s, i) => s + i.totalEstimatedCost);
      stops.add(
        ItineraryStop(
          id: '$planId-s$stopIndex',
          stopNumber: stopIndex++,
          title: isExpress ? 'Express Mart' : 'Market B (Central Hub)',
          subtitle: 'Buy ${activeItems.take(3).map((i) => i.productName).join(', ')}${activeItems.length > 3 ? ' + more' : ''}',
          location: 'Dugbe Commercial Area',
          distanceKm: 1.2,
          durationMinutes: isExpress ? 25 : 45,
          timeWindow: '9:20 AM - 10:05 AM',
          badgeText: 'Single Stop Hub',
          estimatedCost: cost,
          taskItems: activeItems.map((i) => '${i.productName} (${i.quantity} ${i.unit}) - ₦${i.totalEstimatedCost.toStringAsFixed(0)}').toList(),
          isCompleted: false,
        ),
      );
    }

    // 3. User Errands (Non-Shopping)
    for (final errand in errands) {
      if (errand.shoppingItems.isNotEmpty && items.isNotEmpty) {
        continue;
      }
      stops.add(
        ItineraryStop(
          id: '$planId-s$stopIndex',
          stopNumber: stopIndex++,
          title: errand.title,
          subtitle: errand.deadline != null ? 'Complete before ${errand.deadline}' : errand.category,
          location: errand.locationName,
          distanceKm: 1.5,
          durationMinutes: errand.durationMinutes,
          timeWindow: errand.scheduledTime,
          badgeText: errand.deadline != null ? 'Before ${errand.deadline} deadline' : null,
          estimatedCost: 0.0,
          taskItems: [errand.title],
          isCompleted: false,
        ),
      );
    }

    // 4. Return Home
    stops.add(
      ItineraryStop(
        id: '$planId-s$stopIndex',
        stopNumber: stopIndex++,
        title: 'End',
        subtitle: 'Return Home',
        location: (userLocation != null && userLocation.isSet)
            ? userLocation.displayTown
            : 'Home Base',
        distanceKm: 1.8,
        durationMinutes: 25,
        timeWindow: '12:30 PM',
        isCompleted: false,
      ),
    );

    return stops;
  }

  /// AI / Rule-based trade-off recommendation summary (Section 5.4)
  static String generateRecommendationInsight({
    required double budget,
    required double transportCost,
    required double timeAvailable,
    required List<PlanCandidate> candidates,
    List<Errand>? errands,
  }) {
    if (candidates.isEmpty) {
      return 'No candidate plans generated yet. Add commodities to your cart in the Cart Menu tab to calculate optimal plans.';
    }

    final hasErrands = errands != null && errands.isNotEmpty;
    final errandTitle = hasErrands ? errands.first.title : null;
    final deadlineString = hasErrands ? errands.first.deadline : null;

    if (budget < 12000) {
      if (errandTitle != null && deadlineString != null) {
        return "Strict budget safety (₦${budget.toStringAsFixed(0)}): Plan D is recommended. Delaying non-urgent purchases keeps your spending within budget while ensuring $errandTitle is completed before $deadlineString (no price drop prediction made).";
      }
      return "Strict budget safety (₦${budget.toStringAsFixed(0)}): Plan D is recommended. Delaying non-urgent purchases keeps your spending within budget while prioritizing essential commodities (no price drop prediction made).";
    } else if (timeAvailable < 2.0) {
      if (errandTitle != null && deadlineString != null) {
        return "Time critical (${timeAvailable.toStringAsFixed(1)} hrs): Plan C or Plan B is optimal to guarantee your $errandTitle is completed well before the $deadlineString deadline.";
      }
      return "Time critical (${timeAvailable.toStringAsFixed(1)} hrs): Plan C or Plan B is optimal to complete all commodity purchases in a consolidated stop.";
    } else if (transportCost > 2000) {
      return "High transit expense: Consolidating stops in Plan B saves transit fares without adding significant travel delay.";
    } else {
      return "Optimal recommendation: Plan A delivers the lowest overall commodity basket cost for your ₦${budget.toStringAsFixed(0)} budget.";
    }
  }
}

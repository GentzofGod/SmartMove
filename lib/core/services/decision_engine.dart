import '../models/plan_candidate.dart';
import '../models/errand.dart';
import '../models/itinerary_stop.dart';
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
  }) {
    final hasCustomItems = items != null && items.isNotEmpty;
    final defaultStops = DemoSeedData.getInitialStops();

    // Calculate dynamic base items subtotal
    double planABaseItems;
    double planBBaseItems;
    double planCBaseItems;
    double planDBaseItems;

    if (!hasCustomItems) {
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

    // Build dynamic itinerary stops if custom errands or items are provided
    List<ItineraryStop> planAStopsList;
    List<ItineraryStop> planBStopsList;
    List<ItineraryStop> planCStopsList;
    List<ItineraryStop> planDStopsList;

    if (errands != null && errands.isNotEmpty) {
      planAStopsList = _buildStopsForPlan(
        planId: 'plan-a',
        items: items ?? [],
        errands: errands,
        isMultiMarket: true,
        delayNonUrgent: delayNonUrgent,
      );
      planBStopsList = _buildStopsForPlan(
        planId: 'plan-b',
        items: items ?? [],
        errands: errands,
        isMultiMarket: false,
        delayNonUrgent: delayNonUrgent,
      );
      planCStopsList = _buildStopsForPlan(
        planId: 'plan-c',
        items: items ?? [],
        errands: errands,
        isMultiMarket: false,
        delayNonUrgent: delayNonUrgent,
        isExpress: true,
      );
      planDStopsList = _buildStopsForPlan(
        planId: 'plan-d',
        items: items ?? [],
        errands: errands,
        isMultiMarket: false,
        delayNonUrgent: true,
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
      tag: 'Lowest Total Cost',
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
          ? 'Delayed non-urgent purchases. Lowest total outlay (₦${planATotal.toStringAsFixed(0)}). Visits 2 markets to secure best unit prices.'
          : hasCustomItems
              ? 'Lowest shopping bill (₦${planABaseItems.toStringAsFixed(0)}). Visits 2 markets across $planAStops stops to secure best unit prices for ${items.length} items.'
              : 'Lowest shopping bill (₦11,600). Visits Market B & C across 3 stops. Saves ₦800 overall compared to single-market shopping.',
      stops: planAStopsList,
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
      tag: 'Fewest Stops & Transport',
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
          ? 'Consolidates errands to a single market hub. Cuts transport expense to ₦${planBTransport.toStringAsFixed(0)} and saves 42 minutes, paying slightly higher unit prices.'
          : 'Consolidates commodity purchases to a single major market hub. Cuts transport expense to ₦${planBTransport.toStringAsFixed(0)} and saves 42 minutes, paying slightly higher unit prices.',
      stops: planBStopsList,
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
      tag: 'Shortest Duration',
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
              ? 'Delays non-urgent purchases. Focuses on essential items (₦${planDBaseItems.toStringAsFixed(0)}) + $errandTitle, staying under strict budgets without making unsupported claims.'
              : 'Delays non-urgent purchases. Focuses on essential commodities (₦${planDBaseItems.toStringAsFixed(0)}), comfortably staying under strict budgets.')
          : 'Delays non-urgent cooking oil and tomatoes. Focuses on essential food restock, comfortably staying under strict budgets without making unsupported price-drop claims.',
      stops: planDStopsList,
    );

    return [planA, planB, planC, planD];
  }

  /// Helper to generate dynamic itinerary stops based on arbitrary items and errands
  static List<ItineraryStop> _buildStopsForPlan({
    required String planId,
    required List<ShoppingItem> items,
    required List<Errand> errands,
    required bool isMultiMarket,
    required bool delayNonUrgent,
    bool isExpress = false,
  }) {
    final List<ItineraryStop> stops = [];
    int stopIndex = 0;

    // 1. Home Base (Start)
    stops.add(
      ItineraryStop(
        id: '$planId-s0',
        stopNumber: stopIndex++,
        title: 'Start',
        subtitle: 'Your Current Location',
        location: 'Home Base',
        distanceKm: 0.0,
        durationMinutes: 0,
        timeWindow: '9:00 AM',
        isCompleted: true,
      ),
    );

    // 2. Shopping Stops
    if (items.isNotEmpty) {
      final activeItems = delayNonUrgent
          ? items.where((i) => i.priority != ErrandPriority.low).toList()
          : items;

      if (isMultiMarket && activeItems.length > 1) {
        // Split items across 2 markets for Plan A
        final half = (activeItems.length / 2).ceil();
        final marketBItems = activeItems.take(half).toList();
        final marketCItems = activeItems.skip(half).toList();

        final costB = marketBItems.fold(0.0, (s, i) => s + i.totalEstimatedCost);
        final costC = marketCItems.fold(0.0, (s, i) => s + i.totalEstimatedCost);

        stops.add(
          ItineraryStop(
            id: '$planId-s$stopIndex',
            stopNumber: stopIndex++,
            title: 'Market B (Central)',
            subtitle: 'Buy ${marketBItems.map((i) => i.productName).join(', ')}',
            location: 'Dugbe Commercial Area',
            distanceKm: 1.2,
            durationMinutes: 35,
            timeWindow: '9:20 AM - 9:55 AM',
            badgeText: 'Best unit prices',
            estimatedCost: costB,
            taskItems: marketBItems.map((i) => '${i.productName} (${i.quantity} ${i.unit}) - ₦${i.totalEstimatedCost.toStringAsFixed(0)}').toList(),
            isCompleted: false,
          ),
        );

        stops.add(
          ItineraryStop(
            id: '$planId-s$stopIndex',
            stopNumber: stopIndex++,
            title: 'Market C (Local Hub)',
            subtitle: 'Buy ${marketCItems.map((i) => i.productName).join(', ')}',
            location: 'Bodija Market Hub',
            distanceKm: 2.1,
            durationMinutes: 30,
            timeWindow: '10:15 AM - 10:45 AM',
            badgeText: 'Competitive rate',
            estimatedCost: costC,
            taskItems: marketCItems.map((i) => '${i.productName} (${i.quantity} ${i.unit}) - ₦${i.totalEstimatedCost.toStringAsFixed(0)}').toList(),
            isCompleted: false,
          ),
        );
      } else {
        // Consolidated single hub shopping
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
    }

    // 3. User Errands (Non-Shopping)
    for (final errand in errands) {
      if (errand.shoppingItems.isNotEmpty && items.isNotEmpty) {
        // Avoid duplicate shopping entry
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
        location: 'Home Base',
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

import '../models/plan_candidate.dart';
import '../data/demo_seed_data.dart';

class DecisionEngine {
  /// Deterministic plan calculation based on user assumptions (Section 5.4)
  /// Recalculates using application logic. AI does not perform authoritative arithmetic.
  static List<PlanCandidate> calculateCandidatePlans({
    required double userBudget,
    required double baseTransportFare,
    required double maxTimeHours,
    int maxStops = 4,
    double timeCostPerHour = 0.0,
    bool delayNonUrgent = false,
  }) {
    final defaultStops = DemoSeedData.getInitialStops();

    // 1. PLAN A: Lowest Estimated Total Cost (Cheapest Products across 2 markets)
    final double planABaseItems = delayNonUrgent ? 8600.0 : 11600.0;
    final double planATransport = baseTransportFare * 1.5;
    final double planATimeCost = timeCostPerHour * 2.5;
    final double planATotal = planABaseItems + planATransport + planATimeCost;
    const double planAHours = 2.5;
    const int planAStops = 3;

    final List<String> planASatisfied = [];
    final List<String> planAViolated = [];
    if (planATotal <= userBudget) {
      planASatisfied.add('Within budget (saves ₦${(userBudget - planATotal).toStringAsFixed(0)})');
    } else {
      planAViolated.add('Exceeds budget by ₦${(planATotal - userBudget).toStringAsFixed(0)}');
    }
    if (planAHours <= maxTimeHours) {
      planASatisfied.add('Meets 2:00 PM errand deadline');
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
        'Transit fare is demo estimate (no routing provider connected)',
        'Tomato price is simulated demo data',
      ],
      tradeOffExplanation: delayNonUrgent
          ? 'Delayed non-urgent purchases. Lowest total outlay (₦${planATotal.toStringAsFixed(0)}). Visits 2 markets to secure best unit prices.'
          : 'Lowest shopping bill (₦11,600). Visits Market B & C across 3 stops. Saves ₦800 overall compared to single-market shopping.',
      stops: defaultStops,
    );

    // 2. PLAN B: Lowest Transport Expense & Fewest Stops (Consolidated to Market B)
    final double planBBaseItems = delayNonUrgent ? 9400.0 : 12600.0;
    final double planBTransport = baseTransportFare * 1.0;
    final double planBTimeCost = timeCostPerHour * 1.8;
    final double planBTotal = planBBaseItems + planBTransport + planBTimeCost;
    const double planBHours = 1.8;
    const int planBStops = 2;

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
      tradeOffExplanation:
          'Consolidates errands to a single market hub. Cuts transport expense to ₦${planBTransport.toStringAsFixed(0)} and saves 42 minutes, paying slightly higher unit prices.',
      stops: [
        defaultStops[0],
        defaultStops[1], // Market B
        defaultStops[3], // Jumia pickup
        defaultStops[4], // Return home
      ],
    );

    // 3. PLAN C: Shortest Estimated Duration (Express Single Hub)
    final double planCBaseItems = delayNonUrgent ? 9800.0 : 13000.0;
    final double planCTransport = baseTransportFare * 1.0;
    final double planCTimeCost = timeCostPerHour * 1.2;
    final double planCTotal = planCBaseItems + planCTransport + planCTimeCost;
    const double planCHours = 1.2;
    const int planCStops = 2;

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
      stops: [
        defaultStops[0],
        defaultStops[1],
        defaultStops[4],
      ],
    );

    // 4. PLAN D: Delay Non-Urgent Purchases (Budget Protection)
    final double planDBaseItems = 6400.0; // Strictly essential eggs & rice, delaying oil & tomatoes
    final double planDTransport = baseTransportFare * 0.8;
    final double planDTimeCost = timeCostPerHour * 1.0;
    final double planDTotal = planDBaseItems + planDTransport + planDTimeCost;
    const double planDHours = 1.0;
    const int planDStops = 2;

    final List<String> planDSatisfied = [
      'Strict cashflow budget safety (₦${planDTotal.toStringAsFixed(0)} total)',
      'Completes high-priority package pickup before deadline',
      'Minimal 2 stops',
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
        'Postpones cooking oil & tomatoes (no prediction that prices will fall; strictly managing immediate cashflow)',
        'Transit fare is demo estimate',
      ],
      tradeOffExplanation:
          'Delays non-urgent cooking oil and tomatoes. Focuses on essential food restock + package pickup, comfortably staying under strict budgets without making unsupported price-drop claims.',
      stops: [
        defaultStops[0],
        defaultStops[1],
        defaultStops[3],
        defaultStops[4],
      ],
    );

    return [planA, planB, planC, planD];
  }

  /// AI / Rule-based trade-off recommendation summary (Section 5.4)
  static String generateRecommendationInsight({
    required double budget,
    required double transportCost,
    required double timeAvailable,
    required List<PlanCandidate> candidates,
  }) {
    if (budget < 12000) {
      return "Strict budget safety (₦${budget.toStringAsFixed(0)}): Plan D is recommended. Delaying non-urgent purchases keeps your spending within budget while ensuring package collection is completed before 2:00 PM (no price drop prediction made).";
    } else if (timeAvailable < 2.0) {
      return "Time critical (${timeAvailable.toStringAsFixed(1)} hrs): Plan C or Plan B is optimal to guarantee your package pickup is completed well before the 2:00 PM deadline.";
    } else if (transportCost > 2000) {
      return "High transit expense: Consolidating stops in Plan B saves transit fares without adding significant travel delay.";
    } else {
      return "Optimal recommendation: Plan A delivers the lowest overall product cost for your ₦${budget.toStringAsFixed(0)} budget and comfortably meets all errands.";
    }
  }
}

import '../models/plan_candidate.dart';
import '../data/demo_seed_data.dart';

class DecisionEngine {
  /// Deterministic plan calculation based on user assumptions
  static List<PlanCandidate> calculateCandidatePlans({
    required double userBudget,
    required double baseTransportFare,
    required double maxTimeHours,
  }) {
    final defaultStops = DemoSeedData.getInitialStops();

    // Plan A: Cheapest Products (Visits 2 markets + pickup + pharmacy, 3 primary stops)
    // Minimizes product unit prices, but incurs ₦1,800 total transport fare
    final planAItemCost = 11600.0;
    final planATransportCost = baseTransportFare * 1.5; // Multiple hops
    final planATotal = planAItemCost + planATransportCost;
    final planAHours = 2.5;
    final planAFeasibleBudget = planATotal <= userBudget;
    final planAFeasibleDeadline = planAHours <= maxTimeHours;

    final planA = PlanCandidate(
      id: 'plan-a',
      name: 'Plan A',
      tag: 'Cheapest Products',
      itemCost: planAItemCost,
      transportCost: planATransportCost,
      estimatedHours: planAHours,
      stopCount: 3,
      isRecommended: planAFeasibleBudget && planAFeasibleDeadline,
      isFeasibleBudget: planAFeasibleBudget,
      isFeasibleDeadline: planAFeasibleDeadline,
      tradeOffExplanation:
          'Lowest shopping bill (₦11,600). Requires visiting Market B & C with 3 stops. Saves ₦800 overall compared to express shopping.',
      stops: defaultStops,
    );

    // Plan B: Less Transport (Consolidates groceries to Market B only)
    // Slightly higher item subtotal (₦12,600), but saves travel time and fare (₦1,200)
    final planBItemCost = 12600.0;
    final planBTransportCost = baseTransportFare;
    final planBTotal = planBItemCost + planBTransportCost;
    final planBHours = 1.8;
    final planBFeasibleBudget = planBTotal <= userBudget;
    final planBFeasibleDeadline = planBHours <= maxTimeHours;

    final planB = PlanCandidate(
      id: 'plan-b',
      name: 'Plan B',
      tag: 'Less Transport',
      itemCost: planBItemCost,
      transportCost: planBTransportCost,
      estimatedHours: planBHours,
      stopCount: 2,
      isRecommended: !planAFeasibleDeadline && planBFeasibleDeadline,
      isFeasibleBudget: planBFeasibleBudget,
      isFeasibleDeadline: planBFeasibleDeadline,
      tradeOffExplanation:
          'Single-market grocery run. Saves 42 mins travel time and reduces transport to ₦${planBTransportCost.toStringAsFixed(0)}, spending ₦1,000 more on groceries.',
      stops: [
        defaultStops[0],
        defaultStops[1], // Market B
        defaultStops[3], // Jumia pickup
        defaultStops[4], // Return home
      ],
    );

    // Plan C: Fastest / Express (Single commercial hub run)
    final planCItemCost = 13000.0;
    final planCTransportCost = baseTransportFare * 1.0;
    final planCTotal = planCItemCost + planCTransportCost;
    final planCHours = 1.2;
    final planCFeasibleBudget = planCTotal <= userBudget;
    final planCFeasibleDeadline = planCHours <= maxTimeHours;

    final planC = PlanCandidate(
      id: 'plan-c',
      name: 'Plan C',
      tag: 'Fastest',
      itemCost: planCItemCost,
      transportCost: planCTransportCost,
      estimatedHours: planCHours,
      stopCount: 2,
      isRecommended: false,
      isFeasibleBudget: planCFeasibleBudget,
      isFeasibleDeadline: planCFeasibleDeadline,
      tradeOffExplanation:
          'Express single-destination run completed in 1.2 hrs. Premium convenience with highest product cost.',
      stops: [
        defaultStops[0],
        defaultStops[1],
        defaultStops[4],
      ],
    );

    return [planA, planB, planC];
  }

  /// AI / Rule-based trade-off recommendation summary
  static String generateRecommendationInsight({
    required double budget,
    required double transportCost,
    required double timeAvailable,
    required List<PlanCandidate> candidates,
  }) {
    if (budget < 13400) {
      return "Budget constraint (₦${budget.toStringAsFixed(0)}): We recommend removing tomatoes (saves ₦2,200) or buying from a single trader to eliminate transit fares.";
    } else if (timeAvailable < 2.0) {
      return "Time critical (< 2 hrs): Plan B or Plan C is optimal to ensure your Jumia package pickup is completed before the 2:00 PM deadline.";
    } else if (transportCost > 2000) {
      return "High transit fares: Combining stops into Plan B eliminates two bus transfers, saving ₦${(transportCost * 0.8).toStringAsFixed(0)} in transport.";
    } else {
      return "Optimal recommendation: Plan A delivers the best overall value for your ₦${budget.toStringAsFixed(0)} budget while comfortably meeting the 2:00 PM deadline.";
    }
  }
}

import 'itinerary_stop.dart';

class PlanCandidate {
  final String id;
  final String name; // 'Plan A', 'Plan B', 'Plan C'
  final String tag; // 'Cheapest Products', 'Less Transport', 'Fastest'
  final double itemCost;
  final double transportCost;
  final double otherCost;
  final double estimatedHours;
  final int stopCount;
  final bool isRecommended;
  final bool isFeasibleBudget;
  final bool isFeasibleDeadline;
  final String tradeOffExplanation;
  final List<ItineraryStop> stops;

  const PlanCandidate({
    required this.id,
    required this.name,
    required this.tag,
    required this.itemCost,
    required this.transportCost,
    this.otherCost = 0.0,
    required this.estimatedHours,
    required this.stopCount,
    this.isRecommended = false,
    this.isFeasibleBudget = true,
    this.isFeasibleDeadline = true,
    required this.tradeOffExplanation,
    required this.stops,
  });

  double get totalCost => itemCost + transportCost + otherCost;

  String get formattedTotalCost =>
      '₦${totalCost.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';

  String get formattedItemCost =>
      '₦${itemCost.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';

  String get formattedTransportCost =>
      '₦${transportCost.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';
}

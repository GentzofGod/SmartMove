import 'itinerary_stop.dart';
import 'item_acquisition_source.dart';

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
  final bool isFeasibleStops;
  final List<String> satisfiedConstraints;
  final List<String> violatedConstraints;
  final List<String> dataDisclaimers;
  final String tradeOffExplanation;
  final List<ItineraryStop> stops;
  final List<ItemAcquisitionSource> acquisitionSources;
  final String? sourcingChannel;
  final String? easeOfAccess;
  final String? accessRating;

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
    this.isFeasibleStops = true,
    this.satisfiedConstraints = const [],
    this.violatedConstraints = const [],
    this.dataDisclaimers = const [],
    required this.tradeOffExplanation,
    required this.stops,
    this.acquisitionSources = const [],
    this.sourcingChannel,
    this.easeOfAccess,
    this.accessRating,
  });

  String get displaySourcingChannel =>
      sourcingChannel ??
      (id == 'plan-a'
          ? 'Open Wholesale Market'
          : id == 'plan-b'
              ? 'Verified Platform Traders'
              : id == 'plan-c'
                  ? 'Neighborhood Retail Mart'
                  : 'Doorstep Delivery & Essentials');

  String get displayEaseOfAccess =>
      easeOfAccess ??
      (id == 'plan-a'
          ? 'Low Ease • Multi-Stall Physical Trek'
          : id == 'plan-b'
              ? 'Balanced Access • Single Hub Pickup'
              : id == 'plan-c'
                  ? 'High Ease • Neighborhood Walk-in'
                  : 'Maximum Ease • Doorstep Delivery');

  String get accessLevelLabel =>
      accessRating ??
      (id == 'plan-a'
          ? 'Low Ease'
          : id == 'plan-b'
              ? 'Balanced Access'
              : id == 'plan-c'
                  ? 'High Ease'
                  : 'Maximum Ease');

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

  String get formattedOtherCost =>
      '₦${otherCost.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';

  String get formattedTravelTime =>
      estimatedHours % 1 == 0
          ? '${estimatedHours.toInt()} hrs'
          : '${estimatedHours.toStringAsFixed(1)} hrs';
}

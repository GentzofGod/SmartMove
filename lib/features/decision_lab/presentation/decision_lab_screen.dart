import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/plan_candidate.dart';
import '../../../core/models/ai_proposal.dart';
import '../../../core/models/commodity_item.dart';
import '../../../core/models/item_acquisition_source.dart';
import '../../../core/services/meta_ai_service.dart';
import '../../../core/services/safe_outlet_launcher.dart';
import 'widgets/trader_negotiation_sheet.dart';

class DecisionLabScreen extends ConsumerStatefulWidget {
  const DecisionLabScreen({super.key});

  @override
  ConsumerState<DecisionLabScreen> createState() => _DecisionLabScreenState();
}

class _DecisionLabScreenState extends ConsumerState<DecisionLabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _followUpController = TextEditingController();
  FollowUpInterpretation? _activeInterpretation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decisionState = ref.watch(decisionLabProvider);
    final candidates = decisionState.candidates;
    final selectedPlan = decisionState.selectedPlan;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Price Lab',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Multi-plan scenario comparison and basket optimization',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                const Tab(text: 'Compare Plans'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Cart Menu'),
                      if (decisionState.activeItems.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${decisionState.activeItems.length}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Compare Plans (Screen 7)
          _buildComparePlansTab(candidates, selectedPlan, decisionState),

          // Tab 2: Cart Menu (Active Basket & Item Management)
          _buildCartTab(decisionState),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: candidates.isNotEmpty && selectedPlan.id != 'plan-default'
                ? () {
                    // Lock in the selected plan to the active itinerary
                    ref.read(itineraryProvider.notifier).updateWithPlan(selectedPlan);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.primary,
                        content: Text('Accepted ${selectedPlan.name}! Itinerary updated.'),
                      ),
                    );
                    context.push('/itinerary');
                  }
                : null,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                candidates.isNotEmpty && selectedPlan.id != 'plan-default'
                    ? 'Accept ${selectedPlan.name} & View Itinerary'
                    : 'Add Items to Cart to View Itinerary',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitFollowUp(List<PlanCandidate> candidates, DecisionLabState state) {
    final text = _followUpController.text.trim();
    if (text.isEmpty) return;

    const aiService = MetaAiService();

    // Check if user entered an actionable direct command (e.g. "Add yam", "Set budget to 20k", "Fastest plan")
    final cmdResult = aiService.processConversationalCommand(
      command: text,
      currentPlans: candidates,
      currentBudget: state.budget,
      currentTransport: state.transportCost,
      currentHours: state.timeAvailableHours,
      currentItems: state.activeItems,
    );

    if (cmdResult.addedItem != null ||
        cmdResult.updatedBudget != null ||
        cmdResult.removedItemId != null ||
        cmdResult.updatedDelayNonUrgent != null ||
        cmdResult.updatedTimeHours != null ||
        cmdResult.updatedMaxStops != null) {
      ref.read(decisionLabProvider.notifier).applyAiCommand(cmdResult);
      _followUpController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cmdResult.feedbackMessage,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final result = aiService.interpretFollowUp(
      userFollowUp: text,
      currentPlans: candidates,
      currentBudget: state.budget,
      currentTransport: state.transportCost,
    );

    setState(() {
      _activeInterpretation = result;
    });
  }

  void _applyInterpretation(FollowUpInterpretation interpretation) {
    ref.read(decisionLabProvider.notifier).selectPlan(interpretation.targetPlanId);

    if (interpretation.suggestedTransport != null) {
      ref.read(decisionLabProvider.notifier).updateTransport(interpretation.suggestedTransport!);
    }
    if (interpretation.suggestedMaxHours != null) {
      ref.read(decisionLabProvider.notifier).updateTimeAvailable(interpretation.suggestedMaxHours!);
    }

    setState(() {
      _activeInterpretation = null;
      _followUpController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Applied ${interpretation.targetPlanId.toUpperCase()} with adjusted constraints!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getChannelIcon(String planId) {
    switch (planId) {
      case 'plan-a':
        return Icons.store_mall_directory_outlined;
      case 'plan-b':
        return Icons.verified_outlined;
      case 'plan-c':
        return Icons.storefront_outlined;
      case 'plan-d':
        return Icons.local_shipping_outlined;
      default:
        return Icons.shopping_basket_outlined;
    }
  }

  Color _getAccessColor(String rating) {
    switch (rating) {
      case 'Maximum Ease':
        return const Color(0xFF673AB7);
      case 'High Ease':
        return const Color(0xFF1976D2);
      case 'Balanced Access':
        return const Color(0xFF2E7D32);
      case 'Low Ease':
      default:
        return const Color(0xFFE65100);
    }
  }

  Color _getAccessBg(String rating) {
    switch (rating) {
      case 'Maximum Ease':
        return const Color(0xFFEDE7F6);
      case 'High Ease':
        return const Color(0xFFE3F2FD);
      case 'Balanced Access':
        return const Color(0xFFE8F5E9);
      case 'Low Ease':
      default:
        return const Color(0xFFFFF3E0);
    }
  }

  Widget _buildComparePlansTab(
    List<PlanCandidate> candidates,
    PlanCandidate selectedPlan,
    DecisionLabState state,
  ) {
    if (candidates.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, size: 38, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Active Plans to Compare',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add commodities to your shopping basket to generate multi-market candidate plans and compare transport trade-offs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                      label: const Text('Open Cart Menu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _tabController.animateTo(1),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Discover Commodities', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.go('/discover'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Shopping List Header Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.activeItems.isNotEmpty
                        ? 'Active Basket'
                        : 'Shopping Basket',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    state.activeItems.isNotEmpty
                        ? '${state.activeItems.length} commodities'
                        : '0 commodities',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                state.activeItems.isNotEmpty
                    ? state.activeItems
                        .map((i) => '${i.productName} (${i.quantity.toStringAsFixed(0)} ${i.unit})')
                        .join(', ')
                    : 'No items in basket yet. Search commodities, speak a list, or scan a paper note.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Sourcing & Access Comparison',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Compare prices from different sources vs. ease of access',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Deterministic Math',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontally Scrollable Plan Cards
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: candidates.map((plan) {
              final isSelected = plan.id == selectedPlan.id;
              final accessColor = _getAccessColor(plan.accessLevelLabel);
              final accessBg = _getAccessBg(plan.accessLevelLabel);

              return GestureDetector(
                onTap: () {
                  ref.read(decisionLabProvider.notifier).selectPlan(plan.id);
                },
                child: Container(
                  width: 240,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.cardBorder,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: accessBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_getChannelIcon(plan.id), size: 16, color: accessColor),
                          ),
                          if (plan.isRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Recommended',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.successText,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Text(
                        plan.displaySourcingChannel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${plan.name} • ${plan.tag}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Ease of Access Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: accessBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              plan.accessLevelLabel == 'Maximum Ease'
                                  ? Icons.home_outlined
                                  : (plan.accessLevelLabel == 'High Ease'
                                      ? Icons.bolt
                                      : (plan.accessLevelLabel == 'Balanced Access'
                                          ? Icons.verified_outlined
                                          : Icons.directions_walk)),
                              size: 11,
                              color: accessColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                plan.accessLevelLabel,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accessColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        plan.formattedTotalCost,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${plan.estimatedHours} hrs  •  ${plan.stopCount} stops',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(height: 16, color: AppColors.divider),
                      Text(
                        'Items: ${plan.formattedItemCost}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        'Transport: ${plan.formattedTransportCost}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      // Constraint pills
                      Row(
                        children: [
                          Icon(
                            plan.isFeasibleBudget ? Icons.check_circle : Icons.error,
                            size: 13,
                            color: plan.isFeasibleBudget
                                ? AppColors.successText
                                : AppColors.errorText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            plan.isFeasibleBudget ? 'Within Budget' : 'Over Budget',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: plan.isFeasibleBudget
                                  ? AppColors.successText
                                  : AppColors.errorText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Selected Plan Detailed Breakdown Card (Section 5.4)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPlan.displaySourcingChannel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${selectedPlan.name} • ${selectedPlan.tag}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedPlan.isRecommended) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Recommended',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.successText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Ease of Access Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _getAccessBg(selectedPlan.accessLevelLabel),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _getAccessColor(selectedPlan.accessLevelLabel).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedPlan.accessLevelLabel == 'Maximum Ease'
                          ? Icons.home_outlined
                          : (selectedPlan.accessLevelLabel == 'High Ease'
                              ? Icons.bolt
                              : (selectedPlan.accessLevelLabel == 'Balanced Access'
                                  ? Icons.verified_outlined
                                  : Icons.directions_walk)),
                      size: 15,
                      color: _getAccessColor(selectedPlan.accessLevelLabel),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ease of Access: ${selectedPlan.displayEaseOfAccess}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _getAccessColor(selectedPlan.accessLevelLabel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Comprehensive Cost Table
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Product Items Cost:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                        const SizedBox(width: 8),
                        Text(selectedPlan.formattedItemCost, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Transport Fares:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                        const SizedBox(width: 8),
                        Text(selectedPlan.formattedTransportCost, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    if (selectedPlan.otherCost > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(child: Text('Other Expenses (Cost of Time):', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                          const SizedBox(width: 8),
                          Text(selectedPlan.formattedOtherCost, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                    const Divider(height: 14, color: AppColors.cardBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Total Estimated Cost:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                        const SizedBox(width: 8),
                        Text(selectedPlan.formattedTotalCost, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Trip Duration & Stops:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                        const SizedBox(width: 8),
                        Text('${selectedPlan.estimatedHours} hrs  •  ${selectedPlan.stopCount} stops', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Constraints Satisfied & Violated
              const Text(
                'Constraint Feasibility',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              for (final sat in selectedPlan.satisfiedConstraints) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.successText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sat,
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              for (final vio in selectedPlan.violatedConstraints) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.errorText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vio,
                          style: const TextStyle(fontSize: 12, color: AppColors.errorText, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Simulated / Stale Data Disclaimers
              if (selectedPlan.dataDisclaimers.isNotEmpty) ...[
                const Text(
                  'Data Source Disclosures',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                for (final disc in selectedPlan.dataDisclaimers) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFF57F17)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            disc,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF5D4037)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],

              // Trade-Off Analysis Breakdown
              const Text(
                'Trade-Off Rationale',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                selectedPlan.tradeOffExplanation,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        // Acquisition Outlets, Hubs & Registered Traders Section
        _buildAcquisitionSourcesSection(context, selectedPlan),

        const SizedBox(height: 16),

        // Meta Muse Spark Grounded Trade-off Explainer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F5E9), Color(0xFFE0F2F1)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Meta Muse Spark Trade-Off Insight',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Records-Grounded',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  if (candidates.isEmpty) {
                    return const Text(
                      'No candidate plans generated yet. Add commodities in the Cart Menu tab to compare plans.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    );
                  }
                  const aiService = MetaAiService();
                  final planA = candidates.firstWhere((p) => p.id == 'plan-a', orElse: () => candidates.first);
                  final planB = candidates.firstWhere((p) => p.id == 'plan-b', orElse: () => candidates.length > 1 ? candidates[1] : candidates.first);
                  final planC = candidates.firstWhere((p) => p.id == 'plan-c', orElse: () => candidates.first);
                  final planD = candidates.firstWhere((p) => p.id == 'plan-d', orElse: () => candidates.first);

                  final sparkExplanation = aiService.explainTradeOffs(
                    planA: planA,
                    planB: planB,
                    planC: planC,
                    planD: planD,
                    budget: state.budget,
                  );

                  return Text(
                    sparkExplanation,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Proactive Optimization Tips generated by Meta AI
        _buildOptimizationTips(state.optimizationTips),

        // Interactive "Ask Muse Spark" Follow-Up Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ask Muse Spark to Refine Plan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Interpret your natural-language trade-offs and suggest adjustments:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              // Suggestion Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text(
                      'I want to spend less on transport even if shopping bill is slightly higher',
                      style: TextStyle(fontSize: 11),
                    ),
                    backgroundColor: AppColors.surface,
                    onPressed: () {
                      _followUpController.text =
                          'I want to spend less on transport even if the shopping bill is slightly higher';
                      _submitFollowUp(candidates, state);
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'I need to finish faster before deadline',
                      style: TextStyle(fontSize: 11),
                    ),
                    backgroundColor: AppColors.surface,
                    onPressed: () {
                      _followUpController.text = 'I need to finish faster before deadline';
                      _submitFollowUp(candidates, state);
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'Budget is tight, delay non-urgent items',
                      style: TextStyle(fontSize: 11),
                    ),
                    backgroundColor: AppColors.surface,
                    onPressed: () {
                      _followUpController.text = 'Budget is tight, delay non-urgent items';
                      _submitFollowUp(candidates, state);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _followUpController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. "I want to spend less on transport..."',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _submitFollowUp(candidates, state),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    onPressed: () => _submitFollowUp(candidates, state),
                  ),
                ],
              ),

              // Active Interpretation Display with Confirmation Button
              if (_activeInterpretation != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC5E1A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: const [
                                Icon(Icons.auto_awesome, color: AppColors.primary, size: 15),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Muse Spark Interpretation Proposal',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _activeInterpretation = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _activeInterpretation!.interpretationExplanation,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: () => _applyInterpretation(_activeInterpretation!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: Text(
                            'Apply Recommendation (${_activeInterpretation!.targetPlanId.toUpperCase()})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Adjust Cart Action
        OutlinedButton.icon(
          icon: const Icon(Icons.shopping_cart_outlined, size: 16),
          onPressed: () {
            _tabController.animateTo(1);
          },
          label: const Text('Manage Commodities in Cart Menu'),
        ),
      ],
    );
  }

  Widget _buildAcquisitionSourcesSection(BuildContext context, PlanCandidate selectedPlan) {
    if (selectedPlan.acquisitionSources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.store_mall_directory_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acquisition Outlets & Registered Traders',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Itemized sources prioritized by platform trust, distance, and price',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedPlan.acquisitionSources.length,
            separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.divider),
            itemBuilder: (ctx, idx) {
              final source = selectedPlan.acquisitionSources[idx];
              final isTrader = source.isPlatformRegisteredTrader;
              final isEcommerce = source.channel == AcquisitionChannel.ecommercePlatform;
              final qtyDisplay = source.quantity % 1 == 0
                  ? source.quantity.toInt().toString()
                  : source.quantity.toString();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isTrader ? const Color(0xFFF9FDF9) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isTrader
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : AppColors.cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Item and price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                source.commodityName,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$qtyDisplay ${source.unit} • ₦${source.unitPrice.toStringAsFixed(0)} / ${source.unit}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₦${source.totalCost.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            if (source.dynamicDistanceKm > 0)
                              Text(
                                '${source.dynamicDistanceKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Outlet & Badges
                    Row(
                      children: [
                        Icon(
                          isTrader
                              ? Icons.verified
                              : (isEcommerce ? Icons.language : Icons.place_outlined),
                          size: 14,
                          color: isTrader ? AppColors.badgeSuccessText : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            source.outletName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isTrader ? AppColors.primaryDark : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isTrader) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.badgeSuccessBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Platform Trader',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.badgeSuccessText,
                              ),
                            ),
                          ),
                        ] else if (isEcommerce) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE7F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'E-Commerce',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5E35B1),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (source.marketHubOrLocation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        source.marketHubOrLocation,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Action buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (isTrader) ...[
                          ElevatedButton.icon(
                            icon: const Icon(Icons.handshake_outlined, size: 14),
                            label: const Text('Negotiate (In-App Chat)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => TraderNegotiationSheet.show(context, source: source),
                          ),
                          if ((source.whatsappNumber != null && SafeOutletLauncher.isValidPhoneNumber(source.whatsappNumber)) ||
                              (source.contactPhone != null && SafeOutletLauncher.isValidPhoneNumber(source.contactPhone)))
                            OutlinedButton.icon(
                              icon: const Icon(Icons.call_outlined, size: 14),
                              label: const Text('Call / WhatsApp', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                if (source.whatsappNumber != null && SafeOutletLauncher.isValidPhoneNumber(source.whatsappNumber)) {
                                  SafeOutletLauncher.openWhatsApp(
                                    source.whatsappNumber!,
                                    prefilledMessage: 'Hello ${source.outletName}, I am contacting you from SmartMove regarding ${source.commodityName}.',
                                  );
                                } else if (source.contactPhone != null && SafeOutletLauncher.isValidPhoneNumber(source.contactPhone)) {
                                  SafeOutletLauncher.callTraderPhone(source.contactPhone!);
                                }
                              },
                            ),
                        ] else if (isEcommerce && source.webUrl != null) ...[
                          ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_browser, size: 14),
                            label: const Text('Visit Online Store', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF673AB7),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => SafeOutletLauncher.openExternalWebUrl(
                              context,
                              url: source.webUrl!,
                              outletName: source.outletName,
                            ),
                          ),
                        ] else ...[
                          if (source.webUrl != null)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.map_outlined, size: 14),
                              label: const Text('Locate on Maps', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => SafeOutletLauncher.openExternalWebUrl(
                                context,
                                url: source.webUrl!,
                                outletName: source.outletName,
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              icon: const Icon(Icons.directions_outlined, size: 14),
                              label: const Text('Directions / Stall Info', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Locating ${source.outletName} at ${source.marketHubOrLocation}...'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          if (source.contactPhone != null && SafeOutletLauncher.isValidPhoneNumber(source.contactPhone))
                            OutlinedButton.icon(
                              icon: const Icon(Icons.phone_outlined, size: 14),
                              label: const Text('Call', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => SafeOutletLauncher.callTraderPhone(source.contactPhone!),
                            ),
                        ],
                        OutlinedButton.icon(
                          icon: const Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
                          label: const Text('Compare Alternatives', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Meta AI is discovering live vendor alternatives for ${source.commodityName}...',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                            const aiService = MetaAiService();
                            final loc = ref.read(locationProvider);
                            final userCity = loc.city.isNotEmpty ? loc.city : (loc.town.isNotEmpty ? loc.town : 'Ibadan');
                            final comparison = await aiService.conductLiveAiVendorComparison(
                              source.commodityName,
                              city: userCity,
                            );
                            if (context.mounted) {
                              messenger.hideCurrentSnackBar();
                              SafeOutletLauncher.showMultiVendorComparisonSheet(
                                context,
                                comparison: comparison,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartTab(DecisionLabState state) {
    final items = state.activeItems;
    final totalOutlay = items.fold(0.0, (sum, i) => sum + i.totalEstimatedCost);
    final essentialOutlay = items
        .where((i) => i.priority == CommodityPriority.essential)
        .fold(0.0, (sum, i) => sum + i.totalEstimatedCost);
    final nonUrgentOutlay = items
        .where((i) => i.priority != CommodityPriority.essential)
        .fold(0.0, (sum, i) => sum + i.totalEstimatedCost);
    final isOverBudget = state.budget > 0 && totalOutlay > state.budget;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Cart Outlay & Budget Overview Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverBudget ? AppColors.errorText.withValues(alpha: 0.4) : AppColors.cardBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_basket, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Active Basket Outlay',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '₦${totalOutlay.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: InkWell(
                      onTap: () => _showEditBudgetDialog(context, state.budget),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Budget: ₦${state.budget.toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.edit, size: 12, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Essential Outlay', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppColors.successText, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('₦${essentialOutlay.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.successText)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warningText.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Non-Urgent', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppColors.warningText, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('₦${nonUrgentOutlay.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warningText)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (isOverBudget) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.errorText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Basket exceeds budget by ₦${(totalOutlay - state.budget).toStringAsFixed(0)}. Toggle items to Non-Urgent or raise budget.',
                          style: const TextStyle(fontSize: 11, color: AppColors.errorText, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Actions Bar: Add Commodity & Clear
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Commodities (${items.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items.isNotEmpty) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.errorText,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      ref.read(decisionLabProvider.notifier).clearCart();
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 15),
                    label: const Text('Clear', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 4),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 34),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showAddCommodityDialog(context),
                  icon: const Icon(Icons.add, size: 15, color: Colors.white),
                  label: const Text('Add Commodity', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Empty State or List
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_cart_outlined, size: 40, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your Cart is Empty',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add commodities to dynamically generate and compare candidate plans without fake defaults.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddCommodityDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Your First Commodity'),
                ),
              ],
            ),
          )
        else
          ...items.map((item) {
            final isEssential = item.priority == CommodityPriority.essential;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEssential ? AppColors.primary.withValues(alpha: 0.25) : AppColors.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₦${item.estimatedUnitPrice.toStringAsFixed(0)} / ${item.unit}${item.brandOrGrade != null ? ' • ${item.brandOrGrade}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '₦${(item.estimatedUnitPrice * item.quantity).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () {
                              ref.read(decisionLabProvider.notifier).toggleItemPriority(item.id);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isEssential ? AppColors.successBg : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isEssential ? AppColors.primary.withValues(alpha: 0.3) : AppColors.cardBorder,
                                ),
                              ),
                              child: Text(
                                isEssential ? 'Essential' : 'Non-Urgent',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isEssential ? AppColors.successText : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Quantity Stepper
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 28,
                              width: 28,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.remove, size: 14),
                                onPressed: () {
                                  ref.read(decisionLabProvider.notifier).updateItemQuantity(item.id, item.quantity - 1);
                                },
                              ),
                            ),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            Container(
                              height: 28,
                              width: 28,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.add, size: 14),
                                onPressed: () {
                                  ref.read(decisionLabProvider.notifier).updateItemQuantity(item.id, item.quantity + 1);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete item button
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textTertiary),
                        onPressed: () {
                          ref.read(decisionLabProvider.notifier).removeShoppingItem(item.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 16),
        // Switch to Compare Plans CTA
        if (items.isNotEmpty)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _tabController.animateTo(0);
              },
              icon: const Icon(Icons.auto_graph, color: Colors.white),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Compare Generated Plans',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }


    void _showAddCommodityDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'kg');
    final priceCtrl = TextEditingController(text: '1500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Commodity to Cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Commodity Name (e.g. Rice, Yam, Eggs)', isDense: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(labelText: 'Unit (kg, crate, bag)', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Est. Unit Price (₦)', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                final unit = unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'item';
                final price = double.tryParse(priceCtrl.text.trim()) ?? 1000.0;
                ref.read(decisionLabProvider.notifier).addShoppingItem(
                      ShoppingItem(
                        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
                        productName: name,
                        quantity: qty,
                        unit: unit,
                        estimatedUnitPrice: price,
                        priority: CommodityPriority.essential,
                      ),
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  void _showEditBudgetDialog(BuildContext context, double currentBudget) {
    final ctrl = TextEditingController(text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '20000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Spending Budget', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Budget in Naira (₦)', prefixText: '₦ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final val = double.tryParse(ctrl.text.replaceAll(',', '').trim());
              if (val != null && val > 0) {
                ref.read(decisionLabProvider.notifier).updateBudget(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizationTips(List<AiOptimizationTip> tips) {
    if (tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.tips_and_updates_outlined, color: Color(0xFFE65100), size: 18),
            SizedBox(width: 8),
            Text(
              'Meta AI Proactive Optimizations',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final tip in tips)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFFE65100), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tip.message,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      if (tip.actionLabel != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () {
                              if (tip.targetPlanId != null) {
                                ref.read(decisionLabProvider.notifier).selectPlan(tip.targetPlanId!);
                              }
                              if (tip.delayNonUrgent != null) {
                                ref.read(decisionLabProvider.notifier).toggleDelayNonUrgent(tip.delayNonUrgent!);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.primary,
                                  content: Text('Applied "${tip.actionLabel}"!'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              tip.actionLabel!,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

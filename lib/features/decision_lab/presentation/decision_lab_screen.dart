import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/plan_candidate.dart';
import '../../../core/models/ai_proposal.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/meta_ai_service.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
    final currentLocation = ref.watch(locationProvider);
    final candidates = decisionState.candidates;
    final selectedPlan = decisionState.selectedPlan;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Decision Lab',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Explore different plans and see the impact',
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
              tabs: const [
                Tab(text: 'Compare Plans'),
                Tab(text: 'What If?'),
                Tab(text: 'Scenarios'),
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

          // Tab 2: What If? Slider Simulation (Screen 8)
          _buildWhatIfTab(decisionState, currentLocation),

          // Tab 3: Pre-set Scenarios
          _buildScenariosTab(decisionState),
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
            onPressed: () {
              // Lock in the selected plan to the active itinerary
              ref.read(itineraryProvider.notifier).updateWithPlan(selectedPlan);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.primary,
                  content: Text('Accepted ${selectedPlan.name}! Itinerary updated.'),
                ),
              );
              context.push('/itinerary');
            },
            child: Text(
              'Accept ${selectedPlan.name} & View Itinerary',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
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

  Widget _buildComparePlansTab(
    List<PlanCandidate> candidates,
    PlanCandidate selectedPlan,
    DecisionLabState state,
  ) {
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
                children: const [
                  Text(
                    'Your Shopping List',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '4 items + 1 errand',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Rice (2kg), Eggs (1 crate), Tomatoes (2kg), Cooking Oil (1L)',
                style: TextStyle(
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
            const Text(
              'Compare Plans',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Authoritative Math',
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
              return GestureDetector(
                onTap: () {
                  ref.read(decisionLabProvider.notifier).selectPlan(plan.id);
                },
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
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
                          Text(
                            plan.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
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
                      const SizedBox(height: 2),
                      Text(
                        plan.tag,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        plan.formattedTotalCost,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${plan.estimatedHours} hrs  •  ${plan.stopCount} stops',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(height: 18, color: AppColors.divider),
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
                    child: Text(
                      '${selectedPlan.name} (${selectedPlan.tag})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
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

        // Adjust Preferences Action
        OutlinedButton(
          onPressed: () {
            _tabController.animateTo(1);
          },
          child: const Text('Adjust My Preferences in "What If?"'),
        ),
      ],
    );
  }

  Widget _buildWhatIfTab(DecisionLabState state, GeoPoint currentLocation) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Change a factor and see how it affects your plan in real time.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // Slider 1: Budget
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
                  const Text(
                    'Budget',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '₦${state.budget.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: state.budget,
                min: 8000,
                max: 30000,
                divisions: 22,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.cardBorder,
                onChanged: (val) {
                  ref.read(decisionLabProvider.notifier).updateBudget(val);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('₦8,000', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  Text('₦30,000', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Slider 2: Transport Cost
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transport Cost',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'From ${currentLocation.displayLocation}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₦${state.transportCost.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: state.transportCost,
                min: 500,
                max: 4000,
                divisions: 14,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.cardBorder,
                onChanged: (val) {
                  ref.read(decisionLabProvider.notifier).updateTransport(val);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('₦500', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  Text('₦4,000', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Slider 3: Time Available
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
                  const Text(
                    'Time Available',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${state.timeAvailableHours.toStringAsFixed(1)} hrs',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: state.timeAvailableHours,
                min: 1.0,
                max: 6.0,
                divisions: 10,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.cardBorder,
                onChanged: (val) {
                  ref.read(decisionLabProvider.notifier).updateTimeAvailable(val);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('1.0 hr', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  Text('6.0 hrs', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Slider 4: Maximum Number of Stops
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
                  const Text(
                    'Max Stops Limit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${state.maxStops} stops',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: state.maxStops.toDouble(),
                min: 2.0,
                max: 5.0,
                divisions: 3,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.cardBorder,
                onChanged: (val) {
                  ref.read(decisionLabProvider.notifier).updateMaxStops(val.round());
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('2 stops (consolidated)', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  Text('5 stops (flexible)', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Slider 5: Optional Cost of Time
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
                      children: const [
                        Text(
                          'Optional Cost of Time',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Weights faster routes higher',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.timeCostPerHour > 0
                        ? '₦${state.timeCostPerHour.toStringAsFixed(0)} / hr'
                        : '₦0 (Disabled)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: state.timeCostPerHour > 0 ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: state.timeCostPerHour,
                min: 0.0,
                max: 2000.0,
                divisions: 8,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.cardBorder,
                onChanged: (val) {
                  ref.read(decisionLabProvider.notifier).updateTimeCostPerHour(val);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('₦0 (Ignore)', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  Text('₦2,000 / hr', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Switch: Delay Non-Urgent Purchases
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Delay Non-Urgent Purchases',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Postpone non-essential items to preserve immediate cashflow (no price-drop claims made).',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.delayNonUrgent,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  ref.read(decisionLabProvider.notifier).toggleDelayNonUrgent(val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Result Card (Screen 8)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryTint, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Best Candidate Plan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.selectedPlan.name} (${state.selectedPlan.tag})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${state.selectedPlan.formattedTotalCost}  •  ${state.selectedPlan.estimatedHours} hrs  •  ${state.selectedPlan.stopCount} stops',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _tabController.animateTo(0);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Compare'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // AI Guidance Tip Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE399)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFB78103)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.recommendationInsight,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A4B04),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScenariosTab(DecisionLabState state) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Quickly test common real-world conditions:',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _buildScenarioCard(
          title: 'Tight Budget Scenario',
          description: 'Simulates a reduced budget of ₦11,000 to see which non-urgent items to cut.',
          onApply: () {
            ref.read(decisionLabProvider.notifier).updateBudget(11000);
            _tabController.animateTo(0);
          },
        ),
        const SizedBox(height: 12),
        _buildScenarioCard(
          title: 'Rush Hour / Expensive Transport',
          description: 'Simulates transit fare surge to ₦2,500 to evaluate if single-stop trips save money.',
          onApply: () {
            ref.read(decisionLabProvider.notifier).updateTransport(2500);
            _tabController.animateTo(0);
          },
        ),
        const SizedBox(height: 12),
        _buildScenarioCard(
          title: 'Time Crunch (< 1.5 hrs)',
          description: 'Simulates limited time to make sure package pickup is strictly completed by 2:00 PM.',
          onApply: () {
            ref.read(decisionLabProvider.notifier).updateTimeAvailable(1.5);
            _tabController.animateTo(0);
          },
        ),
      ],
    );
  }

  Widget _buildScenarioCard({
    required String title,
    required String description,
    required VoidCallback onApply,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: OutlinedButton(
              onPressed: onApply,
              child: const Text('Simulate Scenario'),
            ),
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

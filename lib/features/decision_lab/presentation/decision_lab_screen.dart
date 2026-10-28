import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/plan_candidate.dart';

class DecisionLabScreen extends ConsumerStatefulWidget {
  const DecisionLabScreen({super.key});

  @override
  ConsumerState<DecisionLabScreen> createState() => _DecisionLabScreenState();
}

class _DecisionLabScreenState extends ConsumerState<DecisionLabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          _buildWhatIfTab(decisionState),

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

        // Trade-Off Analysis Breakdown
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
                  Icon(Icons.compare_arrows_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Trade-Off Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                selectedPlan.tradeOffExplanation,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Meta AI Recommendation Box
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
                children: const [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Meta AI Rehearsal Insight',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                state.recommendationInsight,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
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

  Widget _buildWhatIfTab(DecisionLabState state) {
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
                  const Text(
                    'Transport Cost',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
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
              Column(
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${state.selectedPlan.formattedTotalCost}  •  ${state.selectedPlan.estimatedHours} hrs  •  ${state.selectedPlan.stopCount} stops',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
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
}

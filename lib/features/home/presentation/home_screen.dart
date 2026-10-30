import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/models/errand.dart';
import '../../discover/presentation/product_detail_sheet.dart';
import 'widgets/location_picker_sheet.dart';
import 'widgets/meta_ai_scenario_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final decisionState = ref.watch(decisionLabProvider);
    final currentLocation = ref.watch(locationProvider);
    final userSession = ref.watch(authProvider);
    final recentProducts = products.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Location Bar (Screen 5 from master board)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => LocationPickerSheet.show(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: currentLocation.isSet
                              ? (currentLocation.isDeviceLocation
                                  ? AppColors.primary
                                  : AppColors.cardBorder)
                              : AppColors.badgeWarningText,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentLocation.isSet
                                ? (currentLocation.isDeviceLocation
                                    ? Icons.my_location_rounded
                                    : Icons.location_on_rounded)
                                : Icons.add_location_alt_outlined,
                            size: 14,
                            color: currentLocation.isSet ? AppColors.primary : AppColors.badgeWarningText,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 175),
                            child: Text(
                              currentLocation.isSet ? currentLocation.displayLocation : 'Set Your Town',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: currentLocation.isSet ? AppColors.textPrimary : AppColors.badgeWarningText,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (userSession.isSuperAdmin) ...[
                        InkWell(
                          key: const ValueKey('btn_superadmin_home_chip'),
                          onTap: () => context.push('/superadmin'),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF673AB7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.shield_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'SuperAdmin',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      InkWell(
                        onTap: () => context.push('/notifications'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => context.push('/profile'),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: userSession.isSuperAdmin
                              ? const Color(0xFF673AB7)
                              : AppColors.primary,
                          child: Text(
                            userSession.displayName.isNotEmpty
                                ? userSession.displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Greeting
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning, ${userSession.displayName}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    userSession.isGuest
                        ? (currentLocation.isSet
                            ? "Guest • Exploring near ${currentLocation.displayTown}"
                            : "Guest • Tap location above to set your town")
                        : (userSession.isSuperAdmin
                            ? "SuperAdmin • ${currentLocation.displayLocation}"
                            : (currentLocation.isSet
                                ? currentLocation.displayLocation
                                : "Location Not Set")),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (!currentLocation.isSet) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD54F)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me_outlined, color: AppColors.badgeWarningText, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'No location set. Scan GPS or pick your town for verified local commodity prices.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => LocationPickerSheet.show(context),
                        child: const Text('Scan / Set', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              // Meta AI Scenario Rehearsal Card (1-Tap Simulation)
              const MetaAiScenarioCard(),
              const SizedBox(height: 18),

              // Commodity Price Optimizer Banner Card
              InkWell(
                onTap: () => context.push('/decision-lab'),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primaryTint, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.insights_rounded,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Commodity Price Optimizer",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Icon(Icons.shopping_bag_outlined,
                              size: 16, color: AppColors.textSecondary),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Active Basket: 4 items  •  ₦11,600 est.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.badgeSuccessBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_outline_rounded,
                                      size: 12, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Saves ~₦1,800 across verified local sellers',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stat Metrics Row: Budget, Remaining Budget, Est. Time (Non-decorative, actual calculated constraints)
              Builder(
                builder: (context) {
                  final remainingBudget = (decisionState.budget - decisionState.selectedPlan.totalCost).clamp(0.0, double.infinity);
                  return Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          label: 'Budget',
                          value: '₦${decisionState.budget.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                          icon: Icons.account_balance_wallet_outlined,
                          iconBg: const Color(0xFFFFF0B3),
                          iconColor: const Color(0xFFB78103),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          label: 'Remaining',
                          value: '₦${remainingBudget.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                          icon: Icons.savings_outlined,
                          iconBg: AppColors.primaryTint,
                          iconColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          label: 'Est. Time',
                          value: '${decisionState.selectedPlan.estimatedHours} hrs',
                          icon: Icons.schedule_outlined,
                          iconBg: const Color(0xFFDEEBFF),
                          iconColor: const Color(0xFF0052CC),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Saved Shopping Lists (Section 5.1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saved Shopping Lists',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: () => context.go('/discover'),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // Quick load weekly essentials list into Decision Lab
                        ref.read(decisionLabProvider.notifier).setPlanContext(
                          items: [
                            ShoppingItem(
                              id: 'si-w1',
                              productName: 'Rice (1kg)',
                              quantity: 2,
                              unit: '1kg',
                              estimatedUnitPrice: 1650,
                            ),
                            ShoppingItem(
                              id: 'si-w2',
                              productName: 'Eggs (crate)',
                              quantity: 1,
                              unit: 'crate of 30',
                              estimatedUnitPrice: 5200,
                            ),
                          ],
                          budget: 15000,
                        );
                        context.go('/decision-lab');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Loaded "Weekly Provisions" basket into Price Lab!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bookmark_outline_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Weekly Basket',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Rice & Eggs • ₦8,500', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        ref.read(decisionLabProvider.notifier).setPlanContext(
                          items: [
                            ShoppingItem(
                              id: 'si-b1',
                              productName: 'Eggs (crate)',
                              quantity: 1,
                              unit: 'crate of 30',
                              estimatedUnitPrice: 5200,
                            ),
                            ShoppingItem(
                              id: 'si-b2',
                              productName: 'Cooking Oil (1L)',
                              quantity: 1,
                              unit: '1L',
                              estimatedUnitPrice: 2850,
                            ),
                          ],
                          budget: 10000,
                        );
                        context.go('/decision-lab');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Loaded "Family Breakfast" basket into Price Lab!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bookmark_outline_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Breakfast List',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Eggs & Oil • ₦8,050', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recent Price Changes Section (Section 5.1: Live market data or clean empty state)
              if (recentProducts.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Price Changes',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => context.go('/discover'),
                      child: const Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Product Cards List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = recentProducts[index];
                    final isPositive = p.percentageChange > 0;
                    return InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ProductDetailSheet(product: p),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.shopping_basket_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${p.formattedPrice} • ${p.bestSeller}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: p.sourceType == ObservationSource.simulatedDemo
                                              ? AppColors.cardBorder
                                              : AppColors.badgeSuccessBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          p.sourceType.displayLabel,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: p.sourceType == ObservationSource.simulatedDemo
                                              ? AppColors.textSecondary
                                              : AppColors.badgeSuccessText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          p.updateTime,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPositive ? AppColors.successBg : AppColors.errorBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${isPositive ? "+" : ""}${p.percentageChange.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isPositive ? AppColors.successText : AppColors.errorText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Price Changes',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => context.go('/discover'),
                      child: const Text(
                        'Explore',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          size: 28,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No Live Commodity Quotes Yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Prices will appear here as verified traders and shoppers upload real market data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // "Plan your next trip" CTA Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE8F5E9),
                      Color(0xFFF1F8E9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Compare Commodity Prices',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Compare standardized prices across online retailers, local markets, and SMBs to maximize your savings.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => context.go('/discover'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Compare Commodity Prices',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              // Simulated Data Disclosure
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.info_outline, size: 13, color: AppColors.textSecondary),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'SmartMove — Powered by Meta AI & Community Price Intelligence',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

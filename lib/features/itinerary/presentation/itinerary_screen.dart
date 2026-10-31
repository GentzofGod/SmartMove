import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/item_acquisition_source.dart';
import '../../../core/services/safe_outlet_launcher.dart';
import '../../decision_lab/presentation/widgets/trader_negotiation_sheet.dart';
import 'map_navigation_sheet.dart';

class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(itineraryProvider);
    final decisionState = ref.watch(decisionLabProvider);
    final userLocation = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acquisition Process',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${stops.length} ${stops.length == 1 ? "merchant / source" : "merchants / sources"}  •  ${decisionState.selectedPlan.formattedTotalCost} total',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Sourcing Channel & Ease of Access Banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        decisionState.selectedPlan.displaySourcingChannel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        decisionState.selectedPlan.displayEaseOfAccess,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List of Acquisition Process Cards
          Expanded(
            child: stops.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          const Text(
                            'No Acquisition Steps Yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add commodities in the Cart Menu tab and choose an option to view acquisition steps.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.go('/decision-lab'),
                            child: const Text('Go to Price Lab'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    itemCount: stops.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      final isOnline = stop.webUrl != null &&
                          stop.webUrl!.isNotEmpty &&
                          (stop.channel == AcquisitionChannel.ecommercePlatform ||
                              (stop.outletName?.toLowerCase().contains('jumia') ?? false) ||
                              (stop.outletName?.toLowerCase().contains('konga') ?? false));

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: stop.isCompleted
                                ? AppColors.primaryTint
                                : AppColors.cardBorder,
                            width: stop.isCompleted ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Seller Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          ref
                                              .read(itineraryProvider.notifier)
                                              .toggleStopCompletion(stop.id);
                                        },
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            color: stop.isCompleted
                                                ? AppColors.primary
                                                : Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: stop.isCompleted
                                                  ? AppColors.primary
                                                  : AppColors.cardBorder,
                                              width: 2,
                                            ),
                                          ),
                                          child: stop.isCompleted
                                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                                              : null,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          stop.outletName ?? stop.title,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: stop.isCompleted
                                                ? AppColors.textTertiary
                                                : AppColors.textPrimary,
                                            decoration: stop.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (stop.badgeText != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: stop.isPlatformRegisteredTrader
                                          ? AppColors.badgeSuccessBg
                                          : AppColors.primaryTint,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      stop.badgeText!,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: stop.isPlatformRegisteredTrader
                                            ? AppColors.badgeSuccessText
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Subtitle description
                            Text(
                              stop.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Seller Address & Real Distance Row (No hours/minutes)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    stop.location,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (stop.distanceKm > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTint,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${stop.distanceKm.toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // Commodity task items
                            if (stop.taskItems.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Divider(height: 12, color: AppColors.divider),
                              ...stop.taskItems.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Per-Card Sourcing Action Buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Physical seller -> Start Navigation button
                                if (!isOnline) ...[
                                  ElevatedButton.icon(
                                    key: ValueKey('btn_start_nav_${stop.id}'),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => MapNavigationSheet(
                                          destinationTitle: stop.outletName ?? stop.title,
                                          destinationAddress: stop.location,
                                          buyerAddress: userLocation.isSet
                                              ? userLocation.displayTown
                                              : 'Your Current Location',
                                          distanceKm: stop.distanceKm,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.navigation_rounded, size: 13),
                                    label: const Text(
                                      'Start Navigation',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ] else ...[
                                  // Online seller -> Visit Online Store
                                  ElevatedButton.icon(
                                    key: ValueKey('btn_visit_store_${stop.id}'),
                                    onPressed: () => SafeOutletLauncher.openExternalWebUrl(
                                      context,
                                      url: stop.webUrl!,
                                      outletName: stop.outletName ?? stop.title,
                                    ),
                                    icon: const Icon(Icons.open_in_browser, size: 13),
                                    label: const Text(
                                      'Visit Online Store',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF673AB7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],

                                // Registered Trader: Negotiate
                                if (stop.isPlatformRegisteredTrader && stop.itemSources.isNotEmpty) ...[
                                  OutlinedButton.icon(
                                    onPressed: () => TraderNegotiationSheet.show(
                                      context,
                                      source: stop.itemSources.first,
                                    ),
                                    icon: const Icon(Icons.handshake_outlined, size: 13, color: AppColors.primary),
                                    label: const Text(
                                      'Negotiate',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],

                                // WhatsApp / Call
                                if ((stop.whatsappNumber != null &&
                                        SafeOutletLauncher.isValidPhoneNumber(stop.whatsappNumber)) ||
                                    (stop.contactPhone != null &&
                                        SafeOutletLauncher.isValidPhoneNumber(stop.contactPhone))) ...[
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      if (stop.whatsappNumber != null) {
                                        SafeOutletLauncher.openWhatsApp(
                                          stop.whatsappNumber!,
                                          prefilledMessage:
                                              'Hello ${stop.outletName}, I am contacting you from SmartMove regarding my shopping order.',
                                        );
                                      } else if (stop.contactPhone != null) {
                                        SafeOutletLauncher.callTraderPhone(
                                          stop.contactPhone!,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.call_outlined, size: 13, color: AppColors.textPrimary),
                                    label: const Text(
                                      'WhatsApp / Call',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Action: Edit Options in Decision Lab
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.tune, size: 16),
                onPressed: () => context.go('/decision-lab'),
                label: const Text(
                  '+ Edit Options in Decision Lab',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

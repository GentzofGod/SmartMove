import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/safe_outlet_launcher.dart';
import '../../decision_lab/presentation/widgets/trader_negotiation_sheet.dart';
import 'map_navigation_sheet.dart';

class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(itineraryProvider);
    final decisionState = ref.watch(decisionLabProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Itinerary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${stops.length} ${stops.length == 1 ? "stop" : "stops"}  •  ${decisionState.selectedPlan.formattedTravelTime}  •  ${decisionState.selectedPlan.formattedTotalCost} total',
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
                    Icons.route_outlined,
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
          // Timeline List of Stops
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                final isFirst = index == 0;
                final isLast = index == stops.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline Indicator Column
                      Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
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
                            child: Center(
                              child: stop.isCompleted
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : Text(
                                      isFirst ? 'S' : (isLast ? 'E' : '$index'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isFirst || isLast
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: stop.isCompleted
                                    ? AppColors.primary
                                    : AppColors.cardBorder,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Stop Detail Card
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: InkWell(
                            onTap: () {
                              ref
                                  .read(itineraryProvider.notifier)
                                  .toggleStopCompletion(stop.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: stop.isCompleted
                                      ? AppColors.primaryTint
                                      : AppColors.cardBorder,
                                  width: stop.isCompleted ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          stop.title,
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
                                      if (stop.badgeText != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.successBg,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            stop.badgeText!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.successText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stop.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule,
                                          size: 13,
                                          color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        stop.timeWindow,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (stop.distanceKm > 0) ...[
                                        const SizedBox(width: 8),
                                        const Text('•',
                                            style: TextStyle(
                                                color: AppColors.textTertiary)),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${stop.distanceKm} km',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (stop.taskItems.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Divider(
                                        height: 12, color: AppColors.divider),
                                    ...stop.taskItems.map(
                                      (item) => Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
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
                                                  fontSize: 11,
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
                                  if (stop.outletName != null &&
                                      stop.outletName!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: stop.isPlatformRegisteredTrader
                                            ? const Color(0xFFF1F8E9)
                                            : AppColors.surface,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: stop.isPlatformRegisteredTrader
                                              ? AppColors.primary
                                                  .withValues(alpha: 0.3)
                                              : AppColors.cardBorder,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            stop.isPlatformRegisteredTrader
                                                ? Icons.verified
                                                : Icons.storefront_outlined,
                                            size: 13,
                                            color: stop
                                                    .isPlatformRegisteredTrader
                                                ? AppColors.badgeSuccessText
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              stop.outletName!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: stop
                                                        .isPlatformRegisteredTrader
                                                    ? AppColors.primaryDark
                                                    : AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (stop
                                              .isPlatformRegisteredTrader) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 5,
                                                vertical: 1.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.badgeSuccessBg,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Platform Trader',
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors
                                                      .badgeSuccessText,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (stop.isPlatformRegisteredTrader &&
                                      stop.itemSources.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        InkWell(
                                          onTap: () =>
                                              TraderNegotiationSheet.show(
                                            context,
                                            source: stop.itemSources.first,
                                          ),
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.handshake_outlined,
                                                  size: 11,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Negotiate',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if ((stop.whatsappNumber != null && SafeOutletLauncher.isValidPhoneNumber(stop.whatsappNumber)) ||
                                            (stop.contactPhone != null && SafeOutletLauncher.isValidPhoneNumber(stop.contactPhone)))
                                          InkWell(
                                            onTap: () {
                                              if (stop.whatsappNumber != null) {
                                                SafeOutletLauncher
                                                    .openWhatsApp(
                                                  stop.whatsappNumber!,
                                                  prefilledMessage:
                                                      'Hello ${stop.outletName}, I am contacting you from SmartMove regarding my planned shopping stop.',
                                                );
                                              } else if (stop.contactPhone !=
                                                  null) {
                                                SafeOutletLauncher
                                                    .callTraderPhone(
                                                  stop.contactPhone!,
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.surface,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AppColors.cardBorder,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.call_outlined,
                                                    size: 11,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'WhatsApp / Call',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ] else if (stop.webUrl != null &&
                                      stop.webUrl!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () =>
                                          SafeOutletLauncher.openExternalWebUrl(
                                        context,
                                        url: stop.webUrl!,
                                        outletName:
                                            stop.outletName ?? stop.title,
                                      ),
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF673AB7),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              Icons.open_in_browser,
                                              size: 11,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Visit Web Store',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Actions Row
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const MapNavigationSheet(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text(
                      'Start Navigation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => context.go('/decision-lab'),
                    child: const Text('+ Edit Plan in Decision Lab'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

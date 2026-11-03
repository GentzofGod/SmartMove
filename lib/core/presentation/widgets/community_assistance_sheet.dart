import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../models/price_observation.dart';
import '../../models/item_acquisition_source.dart';
import '../../services/location_service.dart';
import '../../state/app_state.dart';
import '../../../features/decision_lab/presentation/widgets/trader_negotiation_sheet.dart';

/// Bottom sheet providing direction assistance and contact options for
/// unverified community price sightings that lack fixed GPS pins or formal registered stalls.
class CommunityAssistanceSheet extends ConsumerWidget {
  final PriceObservation observation;

  const CommunityAssistanceSheet({
    super.key,
    required this.observation,
  });

  static Future<void> show(
    BuildContext context, {
    required PriceObservation observation,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommunityAssistanceSheet(observation: observation),
    );
  }

  Future<void> _launchWhatsApp(BuildContext context, String phone, String text) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open WhatsApp for $cleanPhone')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to launch WhatsApp messenger')),
        );
      }
    }
  }

  Future<void> _launchCall(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start call to $cleanPhone')),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporterName = observation.submitterName.isNotEmpty
        ? observation.submitterName
        : 'Community Member';
    final hasContact = observation.submitterContact != null &&
        observation.submitterContact!.trim().isNotEmpty;
    final reporterContact = observation.submitterContact?.trim() ?? '+2348030001234';

    final notesText = (observation.notes != null &&
            observation.notes!.trim().isNotEmpty &&
            !observation.notes!.toLowerCase().contains('submitted via'))
        ? observation.notes!.trim()
        : 'No specific landmark notes were provided by the reporter.';

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag pill
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFFFB74D)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.people_outline_rounded,
                                        size: 13, color: Color(0xFFE65100)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Community Sighting',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                observation.timeAgo,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            observation.productName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${observation.formattedPrice} per ${observation.unit}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Helpful Explanation Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDCE775)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 18, color: Color(0xFF827717)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This price was spotted by a shopper in the open market ($reporterName). Unregistered open-air market stalls lack permanent GPS pins. Use the contact options below to get exact directions or verify stock.',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Color(0xFF33691E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Landmark Notes Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.place_outlined,
                              size: 15, color: AppColors.textSecondary),
                          SizedBox(width: 6),
                          Text(
                            'Market Area & Landmark Notes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Location: ${observation.marketLocation.isNotEmpty ? observation.marketLocation : "Local Market"}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notesText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (hasContact) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Reporter Contact: ${observation.submitterContact}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'How would you like to get help?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // Action 1: In-App Chat with Community Scout / Reporter
                ListTile(
                  key: const ValueKey('btn_chat_community_scout'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    hasContact
                        ? 'Chat with $reporterName'
                        : 'Chat with Market Scout',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    hasContact
                        ? 'Message the reporter directly for stall landmark directions.'
                        : 'Ask an active scout in ${observation.marketLocation} to guide you.',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                  onTap: () {
                    Navigator.pop(context);
                    final userLoc = ref.read(locationProvider);
                    final dist = LocationService.resolveDistanceKm(
                      userLocation: userLoc,
                      destLat: observation.latitude,
                      destLon: observation.longitude,
                      destLocationName: observation.marketLocation,
                    );
                    final source = ItemAcquisitionSource(
                      id: 'scout-${observation.marketLocation.hashCode}',
                      itemId: 'obs-${observation.id}',
                      commodityName: observation.productName,
                      quantity: 1.0,
                      unit: observation.unit,
                      unitPrice: observation.price,
                      totalCost: observation.price,
                      outletName: hasContact
                          ? '$reporterName (Community Scout)'
                          : '${observation.marketLocation} Community Scout',
                      channel: AcquisitionChannel.registeredTrader,
                      marketHubOrLocation: observation.marketLocation,
                      latitude: observation.latitude,
                      longitude: observation.longitude,
                      dynamicDistanceKm: dist,
                      isPlatformRegisteredTrader: false,
                      inStock: observation.inStock,
                      brandOrGrade: observation.brandOrGrade,
                    );
                    TraderNegotiationSheet.show(context, source: source);
                  },
                ),
                const SizedBox(height: 10),

                // Action 2: WhatsApp / Call Scout Helpline
                ListTile(
                  key: const ValueKey('btn_whatsapp_market_scout'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.phone_in_talk_outlined,
                        color: Color(0xFF2E7D32), size: 20),
                  ),
                  title: const Text(
                    'Call / WhatsApp Local Market Helper',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Connect with local community guide helpline for ${observation.marketLocation}.',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat,
                            size: 18, color: Color(0xFF2E7D32)),
                        onPressed: () {
                          final text =
                              'Hello SmartMove Helper, please guide me to the stall selling ${observation.productName} for ${observation.formattedPrice} at ${observation.marketLocation}.';
                          _launchWhatsApp(context, reporterContact, text);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.call,
                            size: 18, color: Color(0xFF2E7D32)),
                        onPressed: () =>
                            _launchCall(context, reporterContact),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Action 3: Ask Market Channel Community
                ListTile(
                  key: const ValueKey('btn_broadcast_market_inquiry'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign_outlined,
                        color: Color(0xFF5E35B1), size: 20),
                  ),
                  title: const Text(
                    'Ask on Community Market Feed',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Post a quick question to see if other shoppers saw this stall today.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.send_rounded,
                      color: Color(0xFF5E35B1), size: 18),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF311B92),
                        content: Text(
                          'Posted inquiry for "${observation.productName}" to ${observation.marketLocation} community shoppers!',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

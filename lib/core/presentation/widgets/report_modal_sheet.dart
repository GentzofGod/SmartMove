import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../models/price_observation.dart';
import '../../state/app_state.dart';

class ReportModalSheet extends ConsumerStatefulWidget {
  final PriceObservation observation;

  const ReportModalSheet({
    super.key,
    required this.observation,
  });

  static Future<bool?> show(BuildContext context, PriceObservation observation) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportModalSheet(observation: observation),
    );
  }

  @override
  ConsumerState<ReportModalSheet> createState() => _ReportModalSheetState();
}

class _ReportModalSheetState extends ConsumerState<ReportModalSheet> {
  // 0: Product Issue, 1: Seller Issue
  int _reportTarget = 0;
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  static const List<String> _productReasons = [
    'Inaccurate or Fake Price (Misleading / Predatory)',
    'Permanently Out of Stock / Phantom Listing',
    'Counterfeit, Damaged, or Spoiled Quality',
    'Wrong Unit, Measure, or Packaging Discrepancy',
    'Wrong Product Category or Duplicate Entry',
    'Other Product Issue',
  ];

  static const List<String> _sellerReasons = [
    'Refused to Honor Advertised / Listed Price',
    'Fake or Non-Existent Stall / Physical Address',
    'Unreachable, Unresponsive, or Phone Number Invalid',
    'Rude, Abusive, or Unprofessional Trader Conduct',
    'Suspicious Scammer or Imposter Behavior',
    'Other Seller Issue',
  ];

  @override
  void initState() {
    super.initState();
    _selectedReason = _productReasons.first;
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _onTargetChanged(int target) {
    setState(() {
      _reportTarget = target;
      _selectedReason = target == 0 ? _productReasons.first : _sellerReasons.first;
    });
  }

  void _submitReport() {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);

    final userSession = ref.read(authProvider);
    final reporterName = userSession.isGuest
        ? 'Shopper (Guest)'
        : (userSession.displayName.isNotEmpty ? userSession.displayName : userSession.email);

    final reportType = _reportTarget == 0 ? 'Product Issue' : 'Seller Issue';

    ref.read(communityProvider.notifier).reportListing(
          observationId: widget.observation.id,
          reportType: reportType,
          reason: _selectedReason!,
          details: _detailsController.text.trim(),
          reporterName: reporterName,
        );

    Navigator.pop(context, true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2E7D32),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Report submitted for "${widget.observation.productName}". Our moderation team will investigate.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final obs = widget.observation;
    final currentReasons = _reportTarget == 0 ? _productReasons : _sellerReasons;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_rounded, color: Color(0xFFC62828), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Report Listing or Seller',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Help keep SmartMove transparent, fair, and reliable.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Item Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obs.productName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${obs.formattedPrice}/${obs.unit} • ${obs.sellerName} (${obs.marketLocation})',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!obs.isVerified && obs.submitterRole != 'Trader' && obs.submitterName.isNotEmpty)
                          Text(
                            'Reported by: ${obs.submitterName}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF3949AB)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Target Toggle: Report Product vs Report Seller
            const Text(
              'What are you reporting?',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _onTargetChanged(0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _reportTarget == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _reportTarget == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 15,
                              color: _reportTarget == 0 ? const Color(0xFFC62828) : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Product Issue',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _reportTarget == 0 ? FontWeight.w800 : FontWeight.w600,
                                  color: _reportTarget == 0 ? const Color(0xFFC62828) : AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _onTargetChanged(1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _reportTarget == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _reportTarget == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 15,
                              color: _reportTarget == 1 ? const Color(0xFFC62828) : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Seller Issue',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _reportTarget == 1 ? FontWeight.w800 : FontWeight.w600,
                                  color: _reportTarget == 1 ? const Color(0xFFC62828) : AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reason selector
            Text(
              _reportTarget == 0 ? 'Select Product Reason:' : 'Select Seller Reason:',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            ...currentReasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return InkWell(
                onTap: () => setState(() => _selectedReason = reason),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: isSelected
                            ? const Color(0xFFC62828)
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? const Color(0xFFC62828) : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),

            // Additional Details
            const Text(
              'Additional Details (Optional):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _detailsController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Visited the stall at 11 AM, trader quoted ₦4,500 instead of ₦3,800...',
                hintStyle: TextStyle(fontSize: 11.5, color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC62828)),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitReport,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.flag_rounded, size: 16),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Report',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC62828),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

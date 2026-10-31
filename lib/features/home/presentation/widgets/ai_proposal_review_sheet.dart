import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/ai_proposal.dart';
import '../../../../core/models/errand.dart';
import '../../../../core/services/safe_outlet_launcher.dart';

/// Modal bottom sheet for reviewing, adjusting, and confirming an AI Plan Proposal
///
/// AI Safeguards implemented:
/// - AI output is treated as a proposal, NEVER modifying state without confirmation.
/// - Items, quantities, and budget are fully editable by the user before calculation.
/// - Clarification questions for missing information are displayed with interactive resolution chips.
/// - Non-AI fallback option is visibly provided.
class AiProposalReviewSheet extends StatefulWidget {
  final AiPlanProposal proposal;
  final Function(double confirmedBudget, List<ShoppingItem> confirmedItems, Errand? confirmedErrand) onConfirm;
  final VoidCallback? onManualFallback;

  const AiProposalReviewSheet({
    super.key,
    required this.proposal,
    required this.onConfirm,
    this.onManualFallback,
  });

  @override
  State<AiProposalReviewSheet> createState() => _AiProposalReviewSheetState();
}

class _AiProposalReviewSheetState extends State<AiProposalReviewSheet> {
  late TextEditingController _budgetController;
  late List<ShoppingItem> _items;
  late Errand? _errand;
  late List<ClarificationQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController(
      text: widget.proposal.budget.toStringAsFixed(0),
    );
    _items = List.from(widget.proposal.shoppingItems);
    _errand = widget.proposal.deadlineErrand;
    _questions = List.from(widget.proposal.clarificationQuestions);
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  void _updateQuantity(int index, double delta) {
    setState(() {
      final item = _items[index];
      final newQty = (item.quantity + delta).clamp(1.0, 50.0);
      _items[index] = item.copyWith(quantity: newQty);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _addNewItemDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'kg');
    final priceCtrl = TextEditingController(text: '1500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Shopping Item', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Product Name', hintText: 'e.g. Onions'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit', hintText: 'kg / crate / L'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Est. Unit Price (₦)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
                final unit = unitCtrl.text.trim().isEmpty ? 'item' : unitCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 1000.0;

                setState(() {
                  _items.add(
                    ShoppingItem(
                      id: 'si-custom-${DateTime.now().millisecondsSinceEpoch}',
                      productName: name,
                      quantity: qty,
                      unit: unit,
                      estimatedUnitPrice: price,
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  double get _itemsTotal =>
      _items.fold(0.0, (sum, i) => sum + (i.quantity * i.estimatedUnitPrice));

  void _showItemReferencesSheet(ShoppingItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Store Reference Links: ${item.productName}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Live web links gathered from multi-store search grounding to verify prices:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              for (final link in item.referenceLinks) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryTint,
                    child: Icon(Icons.storefront_outlined, size: 16, color: AppColors.primary),
                  ),
                  title: Text(
                    link.contains('jumia')
                        ? 'Jumia Online Store'
                        : (link.contains('konga')
                            ? 'Konga Online Mall'
                            : (link.contains('jiji')
                                ? 'Jiji Marketplace'
                                : (link.contains('google.com/maps')
                                    ? 'Google Maps Local Stores'
                                    : 'External Store Listing'))),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
                  onTap: () {
                    Navigator.pop(ctx);
                    SafeOutletLauncher.openExternalWebUrl(
                      context,
                      url: link,
                      outletName: item.productName,
                    );
                  },
                ),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Plan Proposal',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Extracted by ${widget.proposal.modelName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Safeguard Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review and adjust items before calculating authoritative plans.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Meta AI Live Cloud vs Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.proposal.hasError
                  ? const Color(0xFFFFEBEE)
                  : widget.proposal.liveWebVendors.isNotEmpty
                      ? const Color(0xFFE8F5E9)
                      : widget.proposal.isLiveCloud
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.proposal.hasError
                    ? const Color(0xFFFFCDD2)
                    : widget.proposal.liveWebVendors.isNotEmpty
                        ? const Color(0xFFA5D6A7)
                        : widget.proposal.isLiveCloud
                            ? const Color(0xFFA5D6A7)
                            : const Color(0xFFA5D6A7),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.proposal.hasError
                      ? Icons.error_outline_rounded
                      : (widget.proposal.liveWebVendors.isNotEmpty
                          ? Icons.travel_explore_rounded
                          : Icons.cloud_done_rounded),
                  size: 16,
                  color: widget.proposal.hasError
                      ? AppColors.errorText
                      : const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.proposal.hasError
                            ? 'Meta AI Notice'
                            : (widget.proposal.liveWebVendors.isNotEmpty
                                ? 'Multi-Store Grounded (Jumia • Konga • Jiji • Stores)'
                                : (widget.proposal.isLiveCloud
                                    ? 'Meta AI Live Cloud: Success'
                                    : 'Meta AI Proposal Extracted')),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: widget.proposal.hasError
                              ? AppColors.errorText
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        widget.proposal.hasError
                            ? (widget.proposal.errorMessage ??
                                'Commodities could not be automatically extracted.')
                            : (widget.proposal.webSearchSummary ??
                                (widget.proposal.isLiveCloud
                                    ? 'Processed directly via Meta Muse Spark remote model.'
                                    : 'Processed with Meta Muse Spark reasoning engine.')),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: widget.proposal.hasError
                              ? AppColors.errorText
                              : const Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Scrollable Content
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Clarification Questions (if any)
                if (_questions.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.help_outline_rounded,
                                color: Color(0xFFF57F17), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Clarification Suggested by Muse Spark',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final q in _questions) ...[
                          Text(
                            q.question,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF424242),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: q.suggestions.map((sug) {
                              return ActionChip(
                                label: Text(sug, style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.white,
                                onPressed: () {
                                  if (q.field == 'budget') {
                                    final val = double.tryParse(sug.replaceAll(RegExp(r'[^\d]'), ''));
                                    if (val != null) {
                                      setState(() {
                                        _budgetController.text = val.toStringAsFixed(0);
                                        _questions.remove(q);
                                      });
                                    }
                                  } else {
                                    setState(() {
                                      _questions.remove(q);
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Budget Field
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Spending Budget:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            '₦ ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            height: 36,
                            child: TextField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Extracted Shopping Items Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shopping Basket (${_items.length} items)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addNewItemDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Items List
                for (int i = 0; i < _items.length; i++) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _items[i].productName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (_items[i].brandOrGrade != null || _items[i].specification != null || (_items[i].preferredSellerType != null && _items[i].preferredSellerType != 'Any')) ...[
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (_items[i].brandOrGrade != null) 'Grade: ${_items[i].brandOrGrade}',
                                    if (_items[i].specification != null) _items[i].specification!,
                                    if (_items[i].preferredSellerType != null && _items[i].preferredSellerType != 'Any')
                                      'Pref: ${_items[i].preferredSellerType}',
                                  ].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                              Text(
                                '₦${_items[i].estimatedUnitPrice.toStringAsFixed(0)} / ${_items[i].unit}  •  Subtotal: ₦${(_items[i].quantity * _items[i].estimatedUnitPrice).toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (_items[i].webReferenceUrl != null ||
                                  _items[i].matchedVendorName != null ||
                                  _items[i].referenceLinks.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        final url = _items[i].webReferenceUrl ??
                                            (_items[i].referenceLinks.isNotEmpty
                                                ? _items[i].referenceLinks.first
                                                : null);
                                        if (url != null) {
                                          SafeOutletLauncher.openExternalWebUrl(
                                            context,
                                            url: url,
                                            outletName: _items[i].matchedVendorName ??
                                                'Store Catalog',
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryTint.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                              color: AppColors.primary.withValues(alpha: 0.3),
                                              width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.open_in_new,
                                                size: 11, color: AppColors.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              _items[i].matchedVendorName ?? 'Store Ref',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_items[i].referenceLinks.length > 1) ...[
                                      InkWell(
                                        onTap: () =>
                                            _showItemReferencesSheet(_items[i]),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Colors.grey.shade300,
                                                width: 0.8),
                                          ),
                                          child: Text(
                                            '+${_items[i].referenceLinks.length - 1} stores',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quantity adjuster
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: AppColors.textSecondary,
                              onPressed: () => _updateQuantity(i, -1),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${_items[i].quantity % 1 == 0 ? _items[i].quantity.toInt() : _items[i].quantity} ${_items[i].unit}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: AppColors.primary,
                              onPressed: () => _updateQuantity(i, 1),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: AppColors.errorText,
                              onPressed: () => _removeItem(i),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Total Items Cost Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Estimated Basket Outlay:',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '₦${_itemsTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Actions
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final confirmedBudget =
                          double.tryParse(_budgetController.text) ?? widget.proposal.budget;
                      Navigator.pop(context);
                      widget.onConfirm(confirmedBudget, _items, _errand);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Confirm & Calculate Plans',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onManualFallback?.call();
              },
              child: const Text(
                'Skip AI and enter manually',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


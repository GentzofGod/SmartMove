import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/ai_proposal.dart';
import '../../../../core/models/errand.dart';
import '../../../../core/services/safe_outlet_launcher.dart';
import '../../../../core/services/web_search_grounding_service.dart';
import '../../../../core/services/meta_ai_service.dart';

/// Modal bottom sheet for reviewing, adjusting, and confirming an AI Plan Proposal
///
/// Features:
/// - Derived prices from different sources (Jumia, Konga, Jiji, Local Markets) on each product
/// - Interactive source switching to compare prices and pick the best choice
/// - Smooth, unblocked scrolling with streamlined compact headers
/// - Clean, non-overflowing hierarchical item cards
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
    _ensureSourceQuotesForItems();
  }

  void _ensureSourceQuotesForItems() async {
    bool hasUpdates = false;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].availableSourceQuotes.isEmpty) {
        final quotes = await WebSearchGroundingService.fetchLiveWebVendors(
          _items[i].productName,
          benchmarkPrice: _items[i].estimatedUnitPrice,
        );
        if (quotes.isNotEmpty && mounted) {
          _items[i] = _items[i].copyWith(
            availableSourceQuotes: quotes,
            matchedVendorName: _items[i].matchedVendorName ?? quotes.first.vendorName,
            webReferenceUrl: _items[i].webReferenceUrl ?? quotes.first.targetUrl,
          );
          hasUpdates = true;
        }
      }
    }
    if (hasUpdates && mounted) {
      setState(() {});
    }
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

  void _selectSourceForItem(int itemIndex, LiveWebVendorResult vendor) {
    setState(() {
      final current = _items[itemIndex];
      final newPrice = vendor.detectedPrice ?? current.estimatedUnitPrice;
      _items[itemIndex] = current.copyWith(
        estimatedUnitPrice: newPrice,
        matchedVendorName: vendor.vendorName,
        webReferenceUrl: vendor.targetUrl,
      );
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
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
                final unit = unitCtrl.text.trim().isEmpty ? 'item' : unitCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 1000.0;
                Navigator.pop(ctx);

                final newItem = ShoppingItem(
                  id: 'si-custom-${DateTime.now().millisecondsSinceEpoch}',
                  productName: name,
                  quantity: qty,
                  unit: unit,
                  estimatedUnitPrice: price,
                );

                setState(() {
                  _items.add(newItem);
                });

                final quotes = await WebSearchGroundingService.fetchLiveWebVendors(
                  name,
                  benchmarkPrice: price,
                );
                if (quotes.isNotEmpty && mounted) {
                  final idx = _items.indexWhere((it) => it.id == newItem.id);
                  if (idx != -1) {
                    setState(() {
                      _items[idx] = _items[idx].copyWith(
                        availableSourceQuotes: quotes,
                        matchedVendorName: quotes.first.vendorName,
                        webReferenceUrl: quotes.first.targetUrl,
                      );
                    });
                  }
                }
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

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final double budgetVal = double.tryParse(_budgetController.text) ?? widget.proposal.budget;
    final bool isOverBudget = _itemsTotal > budgetVal && budgetVal > 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Plan Proposal',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(
                                widget.proposal.modelName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (widget.proposal.liveWebVendors.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFA5D6A7), width: 0.8),
                                  ),
                                  child: const Text(
                                    '✓ Multi-Source Grounded',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Expanded Scrollable Area for shopping items
          Expanded(
            child: ListView(
              children: [
                // Clarification Questions (dismissible)
                if (_questions.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.help_outline_rounded,
                                    color: Color(0xFFF57F17), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Clarification Suggested',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => setState(() => _questions.clear()),
                              child: const Icon(Icons.close, size: 16, color: Color(0xFFE65100)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final q in _questions) ...[
                          Text(
                            q.question,
                            style: const TextStyle(
                              fontSize: 11.5,
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
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                ],

                // Compact Budget & Outlay Bar
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Budget: ₦',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Flexible(
                              child: SizedBox(
                                height: 26,
                                child: TextField(
                                  controller: _budgetController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                    isDense: true,
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Total: ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '₦${_formatPrice(_itemsTotal)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isOverBudget ? AppColors.errorText : AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Extracted Shopping Items Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Shopping Items (${_items.length})',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addNewItemDialog,
                      icon: const Icon(Icons.add, size: 15),
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
                  _buildItemCard(i, _items[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Action Buttons
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
                    label: const Text(
                      'Confirm & Calculate Plans',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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

  Widget _buildItemCard(int index, ShoppingItem item) {
    final quotes = item.availableSourceQuotes;
    final subtotal = item.quantity * item.estimatedUnitPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Product Name & Delete button (full width, never overflows)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _removeItem(index),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Price / Subtotal on left, Quantity stepper on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '₦${_formatPrice(item.estimatedUnitPrice)}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          ' / ${item.unit}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Subtotal: ₦${_formatPrice(subtotal)}',
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
              const SizedBox(width: 8),

              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _updateQuantity(index, -1),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Icon(Icons.remove, size: 15, color: AppColors.textSecondary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    InkWell(
                      key: const Key('stepper-add-btn'),
                      onTap: () => _updateQuantity(index, 1),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Icon(Icons.add, size: 15, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Row 3: Prices Offered Across Different Sources
          if (quotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Prices Offered Across Sources:',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  'Tap to select',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: quotes.map((vendor) {
                  final isSelected = item.matchedVendorName == vendor.vendorName ||
                      (item.matchedVendorName == null && quotes.first == vendor);
                  final priceText = vendor.detectedPrice != null
                      ? '₦${_formatPrice(vendor.detectedPrice!)}'
                      : vendor.priceDisplay;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _selectSourceForItem(index, vendor),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '${vendor.vendorName.split(' ').first}: $priceText',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),

            // Links to inspect store page and open multi-vendor comparison
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final url = item.webReferenceUrl ??
                          (quotes.isNotEmpty ? quotes.first.targetUrl : null);
                      if (url != null) {
                        SafeOutletLauncher.openExternalWebUrl(
                          context,
                          url: url,
                          outletName: item.matchedVendorName ?? item.productName,
                          searchQuery: WebSearchGroundingService.cleanSearchQuery(item.productName),
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 12),
                    label: Text(
                      'View ${item.matchedVendorName ?? 'Store'}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final comparison = await const MetaAiService().conductLiveAiVendorComparison(
                        item.productName,
                        city: 'Local',
                      );
                      if (mounted) {
                        SafeOutletLauncher.showMultiVendorComparisonSheet(
                          context,
                          comparison: comparison,
                        );
                      }
                    },
                    icon: const Icon(Icons.tune_rounded, size: 12),
                    label: const Text(
                      'Compare All',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

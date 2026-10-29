import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/services/meta_ai_service.dart';
import '../../../../core/models/errand.dart';
import 'ai_proposal_review_sheet.dart';
import 'muse_voice_input_sheet.dart';

class MetaAiScenarioCard extends ConsumerStatefulWidget {
  const MetaAiScenarioCard({super.key});

  @override
  ConsumerState<MetaAiScenarioCard> createState() => _MetaAiScenarioCardState();
}

class _MetaAiScenarioCardState extends ConsumerState<MetaAiScenarioCard> {
  bool _isProcessing = false;

  static const String hackathonPrimaryPrompt =
      'I have ₦15,000. I need rice, eggs, tomatoes, and cooking oil. Compare prices across online stores and local markets to find the best deal.';

  /// AI Safeguard: Parses prompt into proposal and opens Review Sheet for user approval
  Future<void> _processAiPlan(String prompt) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      const aiService = MetaAiService();
      final proposal = await aiService.parseToProposal(prompt);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (proposal.isLiveCloud) {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF2E7D32),
            content: Text('✓ Meta AI Live Cloud: Proposal generated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE65100),
            content: Text('⚡ Meta AI Fallback Active: ${proposal.fallbackReason ?? "Local deterministic engine used"}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Open AI Proposal Review Sheet (User Confirmation Safeguard)
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AiProposalReviewSheet(
          proposal: proposal,
          onConfirm: (confirmedBudget, confirmedItems, confirmedErrand) {
            _applyConfirmedProposal(confirmedBudget, confirmedItems, confirmedErrand);
          },
          onManualFallback: () {
            context.push('/decision-lab');
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not complete Meta AI proposal extraction.'),
            backgroundColor: AppColors.errorText,
          ),
        );
      }
    }
  }

  void _applyConfirmedProposal(
    double budget,
    List<ShoppingItem> items,
    Errand? errand,
  ) {
    // Update Decision Lab with confirmed commodity items and budget
    ref.read(decisionLabProvider.notifier).setPlanContext(
      items: items,
      budget: budget,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text(
          'Confirmed: ${items.length} commodities loaded into Price Lab (Budget: ₦${budget.toStringAsFixed(0)})',
        ),
      ),
    );

    context.push('/decision-lab');
  }

  void _openVoiceTranscribeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MuseVoiceInputSheet(
        onTranscriptConfirmed: (text) {
          _processAiPlan(text);
        },
      ),
    );
  }

  void _showCustomPromptDialog() {
    final controller = TextEditingController(text: hackathonPrimaryPrompt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Meta Muse Spark Planner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter commodities to compare, quantities, target location, and budget:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. I have ₦25,000 for 50kg rice, 5L vegetable oil, and tomatoes in Bodija...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.flash_on, size: 14, color: AppColors.primary),
                    label: const Text('₦25k: Yam, Beans & Garri', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      controller.text = 'I have ₦25,000. I need 3 tubers of Abuja yam, 5kg brown beans, and 1 paint bucket of yellow garri in Dugbe.';
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.shopping_basket, size: 14, color: AppColors.primary),
                    label: const Text('₦18k: Rice, Eggs & Cooking Oil', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      controller.text = 'I have ₦18,000. I need 5kg Mama Gold rice, 1 crate of eggs, and 2L Kings vegetable oil in Bodija.';
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.storefront_outlined, size: 14, color: AppColors.primary),
                    label: const Text('₦12k: Provisions & Milk', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      controller.text = 'I have ₦12,000 for 1 tin Peak milk powder, 2 loaves of sliced bread, and 1kg sugar.';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = controller.text.trim();
                    Navigator.pop(ctx);
                    if (text.isNotEmpty) {
                      _processAiPlan(text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text(
                    'Generate Proposal & Review',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9),
            Color(0xFFE0F2F1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
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
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
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
                        'Meta AI Trip Rehearsal',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Muse Spark & Voice',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Scenario quote
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hackathonPrimaryPrompt,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              // 1-Tap Scenario Button
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _processAiPlan(hackathonPrimaryPrompt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isProcessing ? 'Analyzing...' : '1-Tap Plan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Voice Transcribe Button (Microphone)
              SizedBox(
                height: 42,
                width: 42,
                child: IconButton(
                  onPressed: _isProcessing ? null : _openVoiceTranscribeSheet,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.mic_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  tooltip: 'Spoken Request (Muse Voice Transcribe)',
                ),
              ),
              const SizedBox(width: 6),

              // Custom Text Prompt
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _showCustomPromptDialog,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Custom Prompt',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

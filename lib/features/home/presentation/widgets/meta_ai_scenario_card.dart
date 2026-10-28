import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/services/meta_ai_service.dart';
import '../../../../core/models/errand.dart';
import '../../../../core/models/plan_candidate.dart';
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
      'I have ₦15,000. I need rice, eggs, tomatoes, and cooking oil. I also need to collect a package before 2 PM. Help me plan everything.';

  /// AI Safeguard: Parses prompt into proposal and opens Review Sheet for user approval
  Future<void> _processAiPlan(String prompt) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      const aiService = MetaAiService();
      final proposal = await aiService.parseToProposal(prompt);

      if (!mounted) return;
      setState(() => _isProcessing = false);

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
            context.push('/errands');
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
    // Create grocery errand with confirmed items
    final groceryErrand = Errand(
      id: 'e-ai-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Buy Groceries (Meta Muse Spark)',
      locationName: 'Local Commercial Markets',
      scheduledTime: '9:00 AM',
      priority: ErrandPriority.high,
      category: 'groceries',
      shoppingItems: items,
    );
    ref.read(errandsProvider.notifier).addErrand(groceryErrand);

    if (errand != null) {
      ref.read(errandsProvider.notifier).addErrand(errand);
    }

    // Update Decision Lab budget
    ref.read(decisionLabProvider.notifier).updateBudget(budget);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Proposal confirmed! Decision Lab calculated candidate plans.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View Lab',
          textColor: Colors.white,
          onPressed: () => context.go('/decision-lab'),
        ),
      ),
    );
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
                'Enter what you want to buy, budget, deadlines, and errands:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. I have ₦20,000 for rice, cooking oil, and dry cleaning...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
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
              Row(
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
                  const Text(
                    'Meta AI Trip Rehearsal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
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
                flex: 3,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                            color: Colors.white, size: 20),
                    label: Text(
                      _isProcessing ? 'Analyzing...' : '1-Tap Plan Scenario',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Voice Transcribe Button (Microphone)
              SizedBox(
                height: 42,
                width: 44,
                child: IconButton(
                  onPressed: _isProcessing ? null : _openVoiceTranscribeSheet,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
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
              const SizedBox(width: 8),

              // Custom Text Prompt
              Expanded(
                flex: 2,
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
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text(
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
            ],
          ),
        ],
      ),
    );
  }
}

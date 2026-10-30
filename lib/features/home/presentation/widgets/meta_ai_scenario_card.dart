import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/services/meta_ai_service.dart';
import '../../../../core/models/errand.dart';
import 'ai_proposal_review_sheet.dart';
import 'muse_voice_input_sheet.dart';
import 'paper_note_scanner_sheet.dart';

class MetaAiScenarioCard extends ConsumerStatefulWidget {
  const MetaAiScenarioCard({super.key});

  @override
  ConsumerState<MetaAiScenarioCard> createState() => _MetaAiScenarioCardState();
}

class _MetaAiScenarioCardState extends ConsumerState<MetaAiScenarioCard> {
  bool _isProcessing = false;
  final TextEditingController _inlinePromptController = TextEditingController();

  @override
  void dispose() {
    _inlinePromptController.dispose();
    super.dispose();
  }

  /// AI Safeguard: Parses prompt into proposal and opens Review Sheet for user approval
  Future<void> _processAiPlan(String prompt) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      const aiService = MetaAiService();
      final proposal = await aiService.parseToProposal(prompt);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (proposal.hasError) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    proposal.errorMessage ??
                        'Meta AI could not process your request. Please enter items directly in Price Lab.',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Price Lab',
              textColor: Colors.white,
              onPressed: () => context.push('/decision-lab'),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      if (proposal.isLiveCloud) {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF2E7D32),
            content: Text('✓ Meta AI Live Cloud: Proposal generated successfully!'),
            duration: Duration(seconds: 2),
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

  void _openPaperNoteScannerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaperNoteScannerSheet(
        onTranscriptConfirmed: (text) {
          _processAiPlan(text);
        },
      ),
    );
  }

  void _showCustomPromptDialog() {
    final controller = TextEditingController();

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
                  hintText: 'e.g. 5kg rice, 2L cooking oil, 1 crate of eggs in Bodija...',
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
                        'Meta AI Assistant',
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
                  'Muse Spark, Voice & Vision',
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

          // 1. The Prompt Box (comes first!)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inlinePromptController,
                    onSubmitted: (value) {
                      final text = value.trim();
                      if (text.isNotEmpty) {
                        _processAiPlan(text);
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Ask Meta AI (e.g. 5kg rice, 2L oil in Bodija)...',
                      hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
                    onPressed: () {
                      final text = _inlinePromptController.text.trim();
                      if (text.isNotEmpty) {
                        _processAiPlan(text);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Action Buttons: Voice, Scan, Custom Prompt
          Row(
            children: [
              // Voice Button
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    key: const ValueKey('btn_voice_transcribe'),
                    onPressed: _isProcessing ? null : _openVoiceTranscribeSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Voice Note',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Scan Note Button
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    key: const ValueKey('btn_scan_paper_note'),
                    onPressed: _isProcessing ? null : _openPaperNoteScannerSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Scan Note',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Custom Text Prompt Button
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    key: const ValueKey('btn_custom_prompt'),
                    onPressed: _isProcessing ? null : _showCustomPromptDialog,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Custom Prompt',
                        style: TextStyle(
                          fontSize: 11.5,
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

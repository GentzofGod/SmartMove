import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/models/errand.dart';
import '../../../core/models/plan_candidate.dart';
import '../../../core/services/meta_ai_service.dart';
import '../../home/presentation/widgets/ai_proposal_review_sheet.dart';
import '../../home/presentation/widgets/muse_voice_input_sheet.dart';

class ErrandsScreen extends ConsumerStatefulWidget {
  const ErrandsScreen({super.key});

  @override
  ConsumerState<ErrandsScreen> createState() => _ErrandsScreenState();
}

class _ErrandsScreenState extends ConsumerState<ErrandsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _aiPromptController = TextEditingController();
  bool _isAiParsing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  Future<void> _handleMetaAiParse(String prompt) async {
    if (prompt.trim().isEmpty) return;

    setState(() {
      _isAiParsing = true;
    });

    try {
      const aiService = MetaAiService();
      final proposal = await aiService.parseToProposal(prompt);

      if (!mounted) return;
      setState(() {
        _isAiParsing = false;
      });

      // AI Safeguard: Require user review and confirmation before mutating state
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AiProposalReviewSheet(
          proposal: proposal,
          onConfirm: (confirmedBudget, confirmedItems, confirmedErrand) {
            final groceryErrand = Errand(
              id: 'e-ai-${DateTime.now().millisecondsSinceEpoch}',
              title: 'Buy groceries (Meta Muse Spark)',
              locationName: 'Local Markets',
              scheduledTime: '9:00 AM',
              priority: ErrandPriority.high,
              category: 'groceries',
              shoppingItems: confirmedItems,
            );
            ref.read(errandsProvider.notifier).addErrand(groceryErrand);

            if (confirmedErrand != null) {
              ref.read(errandsProvider.notifier).addErrand(confirmedErrand);
            }

            ref.read(decisionLabProvider.notifier).updateBudget(confirmedBudget);
            _aiPromptController.clear();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.primary,
                  content: Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Confirmed! Items and errands added to itinerary.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAiParsing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract AI proposal.'),
            backgroundColor: AppColors.errorText,
          ),
        );
      }
    }
  }

  void _openVoiceInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MuseVoiceInputSheet(
        onTranscriptConfirmed: (text) {
          _aiPromptController.text = text;
          _handleMetaAiParse(text);
        },
      ),
    );
  }

  void _showAddErrandDialog(BuildContext context) {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final timeController = TextEditingController(text: '10:00 AM');
    ErrandPriority selectedPriority = ErrandPriority.medium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Errand',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Errand Title (e.g. Collect dry cleaning)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'Location / Market',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: timeController,
                          decoration: InputDecoration(
                            labelText: 'Scheduled Time',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<ErrandPriority>(
                        value: selectedPriority,
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedPriority = val);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: ErrandPriority.high,
                            child: Text('High Priority'),
                          ),
                          DropdownMenuItem(
                            value: ErrandPriority.medium,
                            child: Text('Medium Priority'),
                          ),
                          DropdownMenuItem(
                            value: ErrandPriority.low,
                            child: Text('Low Priority'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleController.text.trim().isNotEmpty) {
                          ref.read(errandsProvider.notifier).addErrand(
                                Errand(
                                  id: 'errand-${DateTime.now().millisecondsSinceEpoch}',
                                  title: titleController.text.trim(),
                                  locationName: locationController.text.trim().isNotEmpty
                                      ? locationController.text.trim()
                                      : 'Central City',
                                  scheduledTime: timeController.text.trim(),
                                  priority: selectedPriority,
                                  category: 'general',
                                ),
                              );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Add to Itinerary'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final errands = ref.watch(errandsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Errands',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddErrandDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Errand'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Today
              _buildErrandsList(
                errands.where((e) => !e.isCompleted).toList(),
                context,
                showAiBar: true,
              ),
              // Tab 2: Upcoming
              _buildErrandsList(
                errands.where((e) => e.priority == ErrandPriority.low).toList(),
                context,
                showAiBar: false,
              ),
              // Tab 3: Completed
              _buildErrandsList(
                errands.where((e) => e.isCompleted).toList(),
                context,
                showAiBar: false,
              ),
            ],
          ),

          // Bottom Floating Route Summary Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Optimized Route',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '3 stops  •  2.5 hrs  •  ₦1,200 transport',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => context.push('/itinerary'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          'View Itinerary',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrandsList(List<Errand> list, BuildContext context,
      {required bool showAiBar}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.done_all_rounded, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              'No errands in this tab',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        if (showAiBar) ...[
          // Meta AI Prompt Assistant Input
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFE0F2F1)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: const [
                          Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Meta Muse Spark & Voice',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        _aiPromptController.text =
                            'I have ₦15,000. I need rice, eggs, tomatoes, oil and collect package before 2 PM';
                      },
                      child: const Text(
                        'Paste demo scenario',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aiPromptController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'e.g. "I have ₦15,000. Need rice & collect package by 2 PM"',
                          hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.mic_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: 'Muse Voice Transcribe',
                      onPressed: _openVoiceInput,
                    ),
                    const SizedBox(width: 4),
                    _isAiParsing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            onPressed: () =>
                                _handleMetaAiParse(_aiPromptController.text),
                          ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // List of Errands
        ...list.map((errand) => _buildErrandCard(errand, context)),
      ],
    );
  }

  Widget _buildErrandCard(Errand errand, BuildContext context) {
    Color priorityBg;
    Color priorityText;
    String priorityLabel;

    switch (errand.priority) {
      case ErrandPriority.high:
        priorityBg = AppColors.errorBg;
        priorityText = AppColors.errorText;
        priorityLabel = 'Priority: High';
        break;
      case ErrandPriority.medium:
        priorityBg = AppColors.warningBg;
        priorityText = AppColors.warningText;
        priorityLabel = 'Priority: Medium';
        break;
      case ErrandPriority.low:
        priorityBg = AppColors.infoBg;
        priorityText = AppColors.infoText;
        priorityLabel = 'Priority: Low';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Checkbox(
                      value: errand.isCompleted,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        ref
                            .read(errandsProvider.notifier)
                            .toggleErrandCompletion(errand.id);
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            errand.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: errand.isCompleted
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                              decoration: errand.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${errand.locationName}  •  ${errand.scheduledTime}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priorityLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: priorityText,
                  ),
                ),
              ),
            ],
          ),

          // If errand has shopping items, render item pills
          if (errand.shoppingItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: errand.shoppingItems.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    '${item.productName} (${item.quantity.toInt()}${item.unit})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Deadline warning pill if applicable
          if (errand.deadline != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.alarm, size: 12, color: AppColors.warningText),
                  const SizedBox(width: 4),
                  Text(
                    'Deadline: Before ${errand.deadline}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warningText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

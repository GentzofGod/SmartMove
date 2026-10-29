import 'errand.dart';

/// Represents a detected user intent or planning preference
enum PlanningPreference {
  lowestCost,
  fewestStops,
  shortestDuration,
  delayNonUrgent,
  balanced,
}

/// A clarification question generated when input is missing critical constraints
class ClarificationQuestion {
  final String field;
  final String question;
  final List<String> suggestions;

  const ClarificationQuestion({
    required this.field,
    required this.question,
    this.suggestions = const [],
  });
}

/// Structured AI proposal extracted from spoken or typed input
/// Treated as a proposal, NOT authoritative truth, requiring user confirmation.
class AiPlanProposal {
  final double budget;
  final List<ShoppingItem> shoppingItems;
  final Errand? deadlineErrand;
  final String rawInput;
  final String modelName;
  final PlanningPreference detectedPreference;
  final List<ClarificationQuestion> clarificationQuestions;
  final bool hasAmbiguity;
  final String? voiceTranscriptionDetails;

  const AiPlanProposal({
    required this.budget,
    required this.shoppingItems,
    this.deadlineErrand,
    required this.rawInput,
    this.modelName = 'Meta Muse Spark 1.3',
    this.detectedPreference = PlanningPreference.lowestCost,
    this.clarificationQuestions = const [],
    this.hasAmbiguity = false,
    this.voiceTranscriptionDetails,
  });

  AiPlanProposal copyWith({
    double? budget,
    List<ShoppingItem>? shoppingItems,
    Errand? deadlineErrand,
    String? rawInput,
    String? modelName,
    PlanningPreference? detectedPreference,
    List<ClarificationQuestion>? clarificationQuestions,
    bool? hasAmbiguity,
    String? voiceTranscriptionDetails,
  }) {
    return AiPlanProposal(
      budget: budget ?? this.budget,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      deadlineErrand: deadlineErrand ?? this.deadlineErrand,
      rawInput: rawInput ?? this.rawInput,
      modelName: modelName ?? this.modelName,
      detectedPreference: detectedPreference ?? this.detectedPreference,
      clarificationQuestions:
          clarificationQuestions ?? this.clarificationQuestions,
      hasAmbiguity: hasAmbiguity ?? this.hasAmbiguity,
      voiceTranscriptionDetails:
          voiceTranscriptionDetails ?? this.voiceTranscriptionDetails,
    );
  }
}

/// Result of interpreting a follow-up conversation in Decision Lab
class FollowUpInterpretation {
  final String userMessage;
  final String interpretationExplanation;
  final String targetPlanId;
  final double? suggestedBudget;
  final double? suggestedTransport;
  final double? suggestedMaxHours;
  final int? suggestedMaxStops;
  final bool suggestedDelayNonUrgent;

  const FollowUpInterpretation({
    required this.userMessage,
    required this.interpretationExplanation,
    required this.targetPlanId,
    this.suggestedBudget,
    this.suggestedTransport,
    this.suggestedMaxHours,
    this.suggestedMaxStops,
    this.suggestedDelayNonUrgent = false,
  });
}


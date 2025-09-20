import 'message.dart';

/// Machine-readable trace describing which messages were included/excluded
/// from the final prompt and why. Useful for debugging and observability.
class InclusionTrace {
  /// IDs of messages included in the prompt.
  final List<String> selectedMessageIds;

  /// Map of excluded message id -> reason (human-readable code).
  final Map<String, String> excludedReasons;

  /// Summaries produced during strategy execution or by the summarizer. Each
  /// entry contains keys like `chunkId`, `summary`, `before`, `after`.
  final List<Map<String, dynamic>> summaries;

  /// Name of the strategy used to select messages (e.g. `SlidingWindow`).
  final String strategyUsed;

  /// Timestamp when the decision was made.
  final DateTime timestamp;

  InclusionTrace({
    required this.selectedMessageIds,
    required this.excludedReasons,
    required this.summaries,
    required this.strategyUsed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();
}

/// Payload ready to send to an LLM. Contains the final prompt text, included
/// messages, optional summary used in the prompt, an estimated token count,
/// and a trace for observability.
class PromptPayload {
  final String promptText;
  final List<Message> includedMessages;
  final String? summary;
  final int estimatedTokens;
  final InclusionTrace trace;

  PromptPayload({
    required this.promptText,
    required this.includedMessages,
    this.summary,
    required this.estimatedTokens,
    required this.trace,
  });
}

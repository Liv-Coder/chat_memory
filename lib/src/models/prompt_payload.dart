import 'message.dart';

class InclusionTrace {
  final List<String> selectedMessageIds;
  final Map<String, String> excludedReasons;
  final List<Map<String, dynamic>> summaries;
  final String strategyUsed;
  final DateTime timestamp;

  InclusionTrace({
    required this.selectedMessageIds,
    required this.excludedReasons,
    required this.summaries,
    required this.strategyUsed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();
}

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

import '../../core/models/message.dart';
import '../../core/utils/token_counter.dart';

/// Result returned by a ContextStrategy
///
/// Contains selected messages, those excluded, any summaries produced, and a
/// human-identifiable strategy name.
class StrategyResult {
  final List<Message> included;
  final List<Message> excluded;
  final List<SummaryInfo> summaries;
  final String name;

  StrategyResult({
    required this.included,
    required this.excluded,
    required this.summaries,
    required this.name,
  });
}

/// Metadata about a summarization step: `chunkId` identifies the chunk,
/// `summary` contains the text, and `tokenEstimateBefore`/`After` capture
/// token counts for observability.
class SummaryInfo {
  final String chunkId;
  final String summary;
  final int tokenEstimateBefore;
  final int tokenEstimateAfter;

  SummaryInfo({
    required this.chunkId,
    required this.summary,
    required this.tokenEstimateBefore,
    required this.tokenEstimateAfter,
  });
}

/// Abstract interface for context strategies.
///
/// Implementations decide which messages to include in the final prompt,
/// which to exclude, and may optionally produce summaries for excluded chunks.
abstract class ContextStrategy {
  /// Apply the strategy to the provided list of messages.
  /// `messages` are ordered oldest -> newest.
  Future<StrategyResult> apply({
    required List<Message> messages,
    required int tokenBudget,
    required TokenCounter tokenCounter,
  });
}

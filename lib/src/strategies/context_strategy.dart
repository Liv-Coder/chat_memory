import '../models/message.dart';
import '../utils/token_counter.dart';

/// Result returned by a ContextStrategy
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
abstract class ContextStrategy {
  /// Apply the strategy to the provided list of messages.
  /// `messages` are ordered oldest -> newest.
  Future<StrategyResult> apply({
    required List<Message> messages,
    required int tokenBudget,
    required TokenCounter tokenCounter,
  });
}

import 'summarizer.dart';
import '../models/message.dart';
import '../strategies/context_strategy.dart';
import '../utils/token_counter.dart';

/// Simple deterministic summarizer: join messages and truncate to a target char length.
class DeterministicSummarizer implements Summarizer {
  final int maxChars;

  DeterministicSummarizer({this.maxChars = 200});

  @override
  Future<SummaryInfo> summarize(
    List<Message> messages,
    TokenCounter tokenCounter,
  ) async {
    final combined = messages.map((m) => m.content).join(' ');
    final summary = combined.length > maxChars
        ? combined.substring(0, maxChars) + '…'
        : combined;
    final before = tokenCounter.estimateTokens(combined);
    final after = tokenCounter.estimateTokens(summary);
    return SummaryInfo(
      chunkId: DateTime.now().microsecondsSinceEpoch.toString(),
      summary: summary,
      tokenEstimateBefore: before,
      tokenEstimateAfter: after,
    );
  }
}

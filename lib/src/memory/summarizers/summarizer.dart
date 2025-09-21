import '../../core/models/message.dart';
import '../strategies/context_strategy.dart';
import '../../core/utils/token_counter.dart';

abstract class Summarizer {
  /// Summarize a list of messages into a SummaryInfo. Implementations may use tokenCounter.
  Future<SummaryInfo> summarize(
    List<Message> messages,
    TokenCounter tokenCounter,
  );
}

import 'dart:async';

import 'context_strategy.dart';
import '../../core/models/message.dart';
import '../../core/utils/token_counter.dart';

/// Sliding window strategy: include the most recent messages until tokenBudget is reached.
class SlidingWindowStrategy implements ContextStrategy {
  final int lookbackMessages;

  SlidingWindowStrategy({this.lookbackMessages = 50});

  @override
  Future<StrategyResult> apply({
    required List<Message> messages,
    required int tokenBudget,
    required TokenCounter tokenCounter,
  }) async {
    // Start from newest and include until budget reached
    final included = <Message>[];
    final excluded = <Message>[];
    final summaries = <SummaryInfo>[];

    int totalTokens = 0;

    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      final est = tokenCounter.estimateTokens(m.content);
      if (totalTokens + est <= tokenBudget &&
          included.length < lookbackMessages) {
        included.insert(0, m); // keep chronological order
        totalTokens += est;
      } else {
        excluded.add(m);
      }
    }

    return StrategyResult(
      included: included,
      excluded: excluded,
      summaries: summaries,
      name: 'SlidingWindow',
    );
  }
}

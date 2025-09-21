import 'package:test/test.dart';
import 'package:chat_memory/src/strategies/summarization_strategy.dart';
import 'package:chat_memory/src/summarizers/deterministic_summarizer.dart';
import '../test_utils.dart';

void main() {
  group('SummarizationStrategy', () {
    test('no messages returns empty result', () async {
      final strat = SummarizationStrategy(
        config: SummarizationStrategyConfig(maxTokens: 100),
        summarizer: DeterministicSummarizer(maxChars: 50),
        tokenCounter: FakeTokenCounter(),
      );

      final res = await strat.apply(
        messages: [],
        tokenBudget: 100,
        tokenCounter: FakeTokenCounter(),
      );
      expect(res.included, isEmpty);
      expect(res.excluded, isEmpty);
      expect(res.summaries, isEmpty);
    });

    test('preserve recent messages and summarize older', () async {
      final counter = FakeTokenCounter(charsPerToken: 4);
      final messages = TestMessageFactory.createTestMessages(20);
      final strat = SummarizationStrategy(
        config: SummarizationStrategyConfig(
          maxTokens: 10,
          minRecentMessages: 3,
          maxSummaryChunkSize: 5,
        ),
        summarizer: DeterministicSummarizer(maxChars: 30),
        tokenCounter: counter,
      );

      final res = await strat.apply(
        messages: messages,
        tokenBudget: 10,
        tokenCounter: counter,
      );
      expect(res.included.isNotEmpty, true);
      // If there are excluded messages, summaries should be produced.
      if (res.excluded.isNotEmpty) {
        expect(res.summaries, isNotEmpty);
      }
    });

    test('factory presets produce different configs', () {
      final cons = SummarizationStrategyFactory.conservative(
        maxTokens: 200,
        summarizer: DeterministicSummarizer(),
        tokenCounter: FakeTokenCounter(),
      );
      final agg = SummarizationStrategyFactory.aggressive(
        maxTokens: 200,
        summarizer: DeterministicSummarizer(),
        tokenCounter: FakeTokenCounter(),
      );
      final bal = SummarizationStrategyFactory.balanced(
        maxTokens: 200,
        summarizer: DeterministicSummarizer(),
        tokenCounter: FakeTokenCounter(),
      );

      expect(
        cons.config.minRecentMessages,
        greaterThan(bal.config.minRecentMessages),
      );
      expect(
        agg.config.minRecentMessages,
        lessThan(bal.config.minRecentMessages),
      );
    });
  });
}

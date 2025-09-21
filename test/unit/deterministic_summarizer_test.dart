import 'package:test/test.dart';
import 'package:chat_memory/chat_memory.dart';

void main() {
  group('DeterministicSummarizer', () {
    test('truncates long combined content to maxChars', () async {
      final summarizer = DeterministicSummarizer(maxChars: 10);
      final messages = [
        Message(
          id: '1',
          role: MessageRole.user,
          content: 'abcdefghij',
          timestamp: DateTime.utc(2025),
        ),
        Message(
          id: '2',
          role: MessageRole.user,
          content: 'klmnop',
          timestamp: DateTime.utc(2025),
        ),
      ];

      final tokenCounter = HeuristicTokenCounter(charsPerToken: 1);
      final info = await summarizer.summarize(messages, tokenCounter);
      expect(info.summary.length, lessThanOrEqualTo(11)); // 10 chars + ellipsis
      expect(
        info.tokenEstimateBefore,
        greaterThanOrEqualTo(info.tokenEstimateAfter),
      );
    });

    test('returns reasonable estimates for short content', () async {
      final summarizer = DeterministicSummarizer(maxChars: 200);
      final messages = [
        Message(
          id: '1',
          role: MessageRole.user,
          content: 'Hello world',
          timestamp: DateTime.utc(2025),
        ),
      ];
      final tokenCounter = HeuristicTokenCounter(charsPerToken: 4);
      final info = await summarizer.summarize(messages, tokenCounter);
      expect(info.summary, contains('Hello'));
      expect(info.tokenEstimateBefore >= info.tokenEstimateAfter, isTrue);
    });
  });
}

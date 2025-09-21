import 'package:test/test.dart';
import 'package:chat_memory/chat_memory.dart';

void main() {
  group('HeuristicTokenCounter', () {
    test('empty string -> 0 tokens', () {
      final counter = HeuristicTokenCounter();
      expect(counter.estimateTokens(''), equals(0));
    });

    test('basic estimation cases', () {
      final counter = HeuristicTokenCounter(charsPerToken: 4);
      expect(counter.estimateTokens('a'), equals(1));
      expect(counter.estimateTokens('abcd'), equals(1));
      expect(counter.estimateTokens('abcdefgh'), equals(2));
    });

    test('whitespace normalization does not change estimate', () {
      final counter = HeuristicTokenCounter(charsPerToken: 4);
      final a = 'hello   world';
      final b = 'hello world';
      expect(counter.estimateTokens(a), equals(counter.estimateTokens(b)));
    });

    test('handles unicode and long text', () {
      final counter = HeuristicTokenCounter(charsPerToken: 4);
      final text = 'Hello   world\n\n\u{1F600}';
      final estimate = counter.estimateTokens(text);
      expect(estimate, greaterThan(0));
      final long = 'a' * 1000;
      expect(counter.estimateTokens(long) > 0, isTrue);
    });
  });
}

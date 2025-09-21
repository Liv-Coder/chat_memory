import 'package:test/test.dart';
import 'package:chat_memory/chat_memory.dart';

void main() {
  group('SlidingWindowStrategy', () {
    test('includes newest messages until token budget reached', () async {
      final tokenCounter = HeuristicTokenCounter(charsPerToken: 4);
      final strategy = SlidingWindowStrategy(lookbackMessages: 10);

      final messages = List.generate(5, (i) {
        return Message(
          id: 'm$i',
          role: MessageRole.user,
          content: 'msg$i',
          timestamp: DateTime.utc(2025, 1, 1).add(Duration(minutes: i)),
        );
      });

      // tokenBudget of 3 should include only the last 3 messages
      final result = await strategy.apply(
        messages: messages,
        tokenBudget: 3,
        tokenCounter: tokenCounter,
      );
      expect(result.included.length, equals(3));
      expect(
        result.included.map((m) => m.id).toList(),
        equals(['m2', 'm3', 'm4']),
      );
      expect(result.excluded.map((m) => m.id).toList(), equals(['m1', 'm0']));
    });

    test('respects lookbackMessages limit', () async {
      final tokenCounter = HeuristicTokenCounter(charsPerToken: 4);
      final strategy = SlidingWindowStrategy(lookbackMessages: 2);

      final messages = List.generate(
        5,
        (i) => Message(
          id: 'm$i',
          role: MessageRole.user,
          content: 'x',
          timestamp: DateTime.utc(2025, 1, 1).add(Duration(minutes: i)),
        ),
      );

      final result = await strategy.apply(
        messages: messages,
        tokenBudget: 100,
        tokenCounter: tokenCounter,
      );
      expect(result.included.length, equals(2));
      expect(result.included.map((m) => m.id).toList(), equals(['m3', 'm4']));
      expect(result.excluded.length, equals(3));
    });

    test('includes all when budget large', () async {
      final counter = HeuristicTokenCounter(charsPerToken: 4);
      final strategy = SlidingWindowStrategy(lookbackMessages: 10);

      final messages = List.generate(5, (i) {
        return Message(
          id: 'm$i',
          role: MessageRole.user,
          content: 'message $i',
          timestamp: DateTime.utc(2025, 9, 21, 12, i),
        );
      });

      final result = await strategy.apply(
        messages: messages,
        tokenBudget: 1000,
        tokenCounter: counter,
      );
      expect(result.included.length, equals(5));
      expect(result.excluded, isEmpty);
      expect(result.name, contains('SlidingWindow'));
    });
  });
}

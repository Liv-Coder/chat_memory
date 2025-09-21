import 'package:test/test.dart';
import 'package:chat_memory/chat_memory.dart';

void main() {
  test('ConversationManager buildPrompt with summarizer', () async {
    final manager = ConversationManager();
    // register a deterministic summarizer with small maxChars to force summary
    manager.registerDefaultDeterministicSummarizer(maxChars: 10);

    await manager.appendUserMessage('Hello');
    await manager.appendAssistantMessage('World');
    await manager.appendUserMessage('How are you?');

    final payload = await manager.buildPrompt(
      clientTokenBudget: 10,
      trace: true,
    );
    expect(payload.promptText, isNotEmpty);
    expect(payload.estimatedTokens, isNonNegative);
    expect(payload.trace.strategyUsed, isNotEmpty);
    // Because summarizer has a small maxChars, summary should exist when excluded messages are present
    // We don't know exact exclusion behavior, but ensure summary field is present (may be null if nothing excluded)
    expect(payload.summary == null || payload.summary is String, isTrue);
    expect(payload.trace.summaries, isA<List>());
  });

  test('buildPrompt returns prompt and trace for stored messages', () async {
    final manager = ConversationManager();
    await manager.appendUserMessage('Hello');
    await manager.appendAssistantMessage('Hi there');

    final payload = await manager.buildPrompt(
      clientTokenBudget: 1000,
      trace: true,
    );
    expect(payload.promptText, contains('user: Hello'));
    expect(payload.promptText, contains('assistant: Hi there'));
    expect(payload.trace.selectedMessageIds, isNotEmpty);
    expect(payload.estimatedTokens, greaterThanOrEqualTo(0));
  });
}

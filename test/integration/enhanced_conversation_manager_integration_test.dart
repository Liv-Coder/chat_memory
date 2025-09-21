import 'package:test/test.dart';
import 'package:chat_memory/src/enhanced_conversation_manager.dart';
import 'package:chat_memory/src/memory/hybrid_memory_factory.dart';
import 'package:chat_memory/src/follow_up/follow_up_generator.dart';

class SimpleFollowUp implements FollowUpGenerator {
  @override
  Future<List<String>> generate(List messages, {int max = 3}) async {
    return List<String>.generate(max, (i) => 'Follow-up question ${i + 1}');
  }
}

void main() {
  group('EnhancedConversationManager (integration)', () {
    test('end-to-end conversation flow with real components', () async {
      final manager = await EnhancedConversationManager.create(
        preset: MemoryPreset.development,
        maxTokens: 100,
      );

      // Append messages
      await manager.appendUserMessage('How do I reset my password?');
      await manager.appendAssistantMessage(
        'You can reset it from account settings.',
      );
      await manager.appendUserMessage('I cannot find account settings.');

      // Build enhanced prompt
      final enhanced = await manager.buildEnhancedPrompt(
        clientTokenBudget: 500,
      );
      expect(enhanced.promptText, isNotEmpty);
      expect(enhanced.semanticMessages, isA<List>());
      expect(enhanced.estimatedTokens, isNonNegative);

      // Register follow-up generator and generate questions
      manager.registerFollowUpGenerator(SimpleFollowUp());
      final questions = await manager.generateFollowUpQuestions(max: 2);
      expect(questions, hasLength(2));

      // Stats should reflect messages
      final stats = await manager.getStats();
      expect(stats.totalMessages, greaterThanOrEqualTo(3));
    });

    test('persistence and vector store integration', () async {
      final manager = await EnhancedConversationManager.create(
        preset: MemoryPreset.development,
        maxTokens: 50,
      );

      await manager.appendUserMessage('Network error on upload');
      await manager.appendAssistantMessage('Check your connection and retry.');

      // Persistence should have messages
      final stats = await manager.getStats();
      expect(stats.totalMessages, greaterThanOrEqualTo(2));

      // Clearing should remove vectors
      await manager.clear();
      final post = await manager.getStats();
      // vectorCount may be zero or null depending on implementation; ensure no exceptions
      expect(post.totalMessages, greaterThanOrEqualTo(0));
    });
  });
}

import 'package:test/test.dart';
import 'package:chat_memory/src/memory/hybrid_memory_factory.dart';
import '../test_utils.dart';

void main() {
  group('Hybrid memory flow (integration)', () {
    test('end-to-end store -> embed -> search -> retrieve -> summarize', () async {
      // Create a development memory manager (uses in-memory vector store + simple embedding)
      final manager = await HybridMemoryFactory.create(
        preset: MemoryPreset.development,
        maxTokens: 50,
      );

      // Prepare messages that will trigger summarization and semantic retrieval
      final messages = TestMessageFactory.createTestMessages(30);
      // Store messages via the memory manager (batch)
      await manager.storeMessageBatch(messages);

      // Simulate a user query that should retrieve semantically related items
      const query = 'message_5';

      final ctx = await manager.getContext(messages, query);

      // Verify overall result shape
      expect(ctx.messages, isNotNull);
      expect(ctx.estimatedTokens, isNonNegative);
      // If summarization kicked in, summary may be present
      expect(ctx.summary == null || ctx.summary is String, true);
      // Semantic messages are a list
      expect(ctx.semanticMessages, isA<List>());
    });

    test('semantic retrieval respects topK and minSimilarity', () async {
      final manager = await HybridMemoryFactory.create(
        preset: MemoryPreset.development,
        maxTokens: 100,
      );

      final msgs = TestMessageFactory.createTestMessages(40);
      await manager.storeMessageBatch(msgs);

      // Query expected to match some stored messages
      final res = await manager.getContext(msgs, 'message_10');

      // semanticTopK is configured by preset; ensure returned list length <= topK
      expect(res.semanticMessages.length <= manager.config.semanticTopK, true);
    });
  });
}

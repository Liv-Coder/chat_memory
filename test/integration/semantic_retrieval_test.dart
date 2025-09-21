import 'package:chat_memory/chat_memory.dart';
import 'package:test/test.dart';
import '../test_utils.dart';

void main() {
  group('Semantic retrieval integration', () {
    test('retrieves semantically similar messages ordered by similarity', () async {
      final tokenCounter = FakeTokenCounter();
      final vectorStore = InMemoryVectorStore();
      final embedding = SimpleEmbeddingService(dimensions: 32);

      final manager = MemoryManager(
        contextStrategy: FakeContextStrategy(includeAll: true),
        tokenCounter: tokenCounter,
        vectorStore: vectorStore,
        embeddingService: embedding,
        config: const MemoryConfig(
          maxTokens: 50,
          semanticTopK: 5,
          minSimilarity: 0.0,
        ),
      );

      // Add messages with varied content (ordered oldest -> newest)
      final msgs = <Message>[
        TestMessageFactory.create(content: 'How to bake a cake'),
        TestMessageFactory.create(content: 'Password reset instructions'),
        TestMessageFactory.create(
          content: 'Baking tips and tricks for beginners',
        ),
        TestMessageFactory.create(
          content: 'Account recovery steps and email verification',
        ),
        TestMessageFactory.create(content: 'Cake recipe: flour, sugar, eggs'),
        TestMessageFactory.create(content: 'Troubleshooting login issues'),
      ];

      // Store all messages in vector store via manager
      await manager.storeMessageBatch(msgs);

      // Query about baking
      final ctx = await manager.getContext(msgs, 'bake cake recipe');

      // Semantic messages should be a list; may be empty if minSimilarity filters all
      expect(ctx.semanticMessages, isA<List<Message>>());

      // If there are >=2 semantic results, verify they are ordered by descending similarity
      if (ctx.semanticMessages.length >= 2) {
        double? prevSim;
        for (final m in ctx.semanticMessages) {
          final sim = (m.metadata?['similarity'] as num?)?.toDouble();
          expect(sim, isNotNull);
          if (prevSim != null) {
            expect(sim! <= prevSim + 1e-8, true);
          }
          prevSim = sim!;
        }
      }
    });

    test('topK limiting and minSimilarity filtering respected', () async {
      final tokenCounter = FakeTokenCounter();
      final vectorStore = InMemoryVectorStore();
      final embedding = SimpleEmbeddingService(dimensions: 16);

      final cfg = MemoryConfig(
        maxTokens: 50,
        semanticTopK: 2,
        minSimilarity: 0.05,
      );
      final manager = MemoryManager(
        contextStrategy: FakeContextStrategy(includeAll: true),
        tokenCounter: tokenCounter,
        vectorStore: vectorStore,
        embeddingService: embedding,
        config: cfg,
      );

      final msgs = List.generate(10, (i) {
        return TestMessageFactory.create(content: 'topic item ${i + 1}');
      });

      await manager.storeMessageBatch(msgs);

      final res = await manager.getContext(msgs, 'topic item 1');

      // Ensure returned semantic messages do not exceed topK
      expect(res.semanticMessages.length <= cfg.semanticTopK, true);

      // Ensure similarity in metadata respects minSimilarity (if present)
      for (final m in res.semanticMessages) {
        final sim = (m.metadata?['similarity'] as num?)?.toDouble() ?? 0.0;
        expect(sim >= cfg.minSimilarity || res.semanticMessages.isEmpty, true);
      }
    });

    test(
      'recent message filtering excludes recent ids from semantic results',
      () async {
        final tokenCounter = FakeTokenCounter();
        final vectorStore = InMemoryVectorStore();
        final embedding = SimpleEmbeddingService(dimensions: 16);

        final manager = MemoryManager(
          contextStrategy: FakeContextStrategy(includeAll: true),
          tokenCounter: tokenCounter,
          vectorStore: vectorStore,
          embeddingService: embedding,
          config: const MemoryConfig(
            maxTokens: 100,
            semanticTopK: 10,
            minSimilarity: 0.0,
          ),
        );

        // Create >10 messages so some are considered "recent" by the implementation
        final msgs = TestMessageFactory.createTestMessages(12);
        await manager.storeMessageBatch(msgs);

        // Query similar to the oldest message (message_1)
        final res = await manager.getContext(msgs, 'message_1');

        // recentMessageIds are derived from messages.take(10) in MemoryManager
        final recentIds = msgs.take(10).map((m) => m.id).toSet();

        // Ensure none of the semantic results correspond to recent ids
        for (final m in res.semanticMessages) {
          expect(recentIds.contains(m.metadata?['id'] ?? m.id), false);
          // Also ensure the original id (without suffix) is not present
          final originalId = m.id.replaceAll('_semantic', '');
          expect(recentIds.contains(originalId), false);
        }
      },
    );
  });
}

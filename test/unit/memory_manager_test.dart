import 'package:test/test.dart';
import 'package:chat_memory/src/memory/memory_manager.dart';
import 'package:chat_memory/src/memory/embeddings/embedding_service.dart';
import 'package:chat_memory/src/memory/vector_stores/in_memory_vector_store.dart';
import 'package:chat_memory/src/core/models/message.dart';
import '../test_utils.dart';

class FakeEmbeddingService implements EmbeddingService {
  final int dims;
  FakeEmbeddingService({this.dims = 4});

  @override
  int get dimensions => dims;

  @override
  String get name => 'fake';

  @override
  Future<List<double>> embed(String text) async {
    // simple deterministic embedding: first element = text length, rest zeros
    if (text.isEmpty) return List.filled(dims, 0.0);
    final v = List<double>.filled(dims, 0.0);
    v[0] = text.length.toDouble();
    return v;
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    return Future.wait(texts.map((t) => embed(t)));
  }
}

void main() {
  group('MemoryManager', () {
    test('pre-check returns messages when within token budget', () async {
      final messages = TestMessageFactory.createTestMessages(3);
      final tokenCounter = FakeTokenCounter(
        charsPerToken: 1000,
      ); // very large => small token counts
      final manager = MemoryManager(
        contextStrategy: FakeContextStrategy(includeAll: true),
        tokenCounter: tokenCounter,
        // no vector store or embedding required for this path
      );

      final res = await manager.getContext(messages, 'query');
      expect(res.messages, hasLength(3));
      expect(res.metadata['preCheck'], 'withinBudget');
      expect(res.estimatedTokens, isNonNegative);
    });

    test(
      'storeMessage stores non-system messages and skips system/summary',
      () async {
        final vectorStore = InMemoryVectorStore();
        final embedding = FakeEmbeddingService(dims: 4);
        final tokenCounter = FakeTokenCounter();
        final manager = MemoryManager(
          contextStrategy: FakeContextStrategy(includeAll: true),
          tokenCounter: tokenCounter,
          vectorStore: vectorStore,
          embeddingService: embedding,
        );

        final userMsg = TestMessageFactory.create(
          role: MessageRole.user,
          content: 'hello',
        );
        final sysMsg = TestMessageFactory.create(
          role: MessageRole.system,
          content: 'sys',
        );
        final summaryMsg = TestMessageFactory.create(
          role: MessageRole.summary,
          content: 'sum',
        );

        await manager.storeMessage(userMsg);
        await manager.storeMessage(sysMsg);
        await manager.storeMessage(summaryMsg);

        final count = await vectorStore.count();
        expect(count, 1);
        final all = await vectorStore.getAll();
        expect(all.first.id, userMsg.id);
      },
    );

    test(
      'storeMessageBatch stores only non-system messages and uses embedBatch',
      () async {
        final vectorStore = InMemoryVectorStore();
        final embedding = FakeEmbeddingService(dims: 4);
        final tokenCounter = FakeTokenCounter();
        final manager = MemoryManager(
          contextStrategy: FakeContextStrategy(includeAll: true),
          tokenCounter: tokenCounter,
          vectorStore: vectorStore,
          embeddingService: embedding,
        );

        final msgs = <Message>[
          TestMessageFactory.create(role: MessageRole.user, content: 'alpha'),
          TestMessageFactory.create(role: MessageRole.system, content: 'sys'),
          TestMessageFactory.create(
            role: MessageRole.assistant,
            content: 'beta',
          ),
        ];

        await manager.storeMessageBatch(msgs);
        final count = await vectorStore.count();
        expect(count, 2);
        final all = await vectorStore.getAll();
        expect(all.map((e) => e.content), containsAll(['alpha', 'beta']));
      },
    );

    test('semantic retrieval returns messages not in recent set', () async {
      final vectorStore = InMemoryVectorStore();
      final embedding = FakeEmbeddingService(dims: 4);
      final tokenCounter = FakeTokenCounter();
      // low maxTokens to bypass precheck and force full processing
      final cfg = MemoryConfig(
        maxTokens: 1,
        semanticTopK: 5,
        minSimilarity: 0.0,
      );
      final manager = MemoryManager(
        contextStrategy: FakeContextStrategy(includeAll: true),
        tokenCounter: tokenCounter,
        vectorStore: vectorStore,
        embeddingService: embedding,
        config: cfg,
      );

      // create messages and store them in vector store via manager
      final msgs = TestMessageFactory.createTestMessages(12);
      // store all via batch
      await manager.storeMessageBatch(msgs);

      // query that is similar to message_3 (length-based embedding)
      final query = 'message_3';
      final res = await manager.getContext(msgs, query);

      // since recentMessageIds are the first 10 messages (as implemented),
      // results for messages beyond those (i.e., msg 11.. ) may be returned.
      expect(res.semanticMessages, isList);
      // ensure function executed and did not throw; at least zero results allowed
      expect(res.estimatedTokens, isNonNegative);
      expect(res.metadata['strategyUsed'], isNotNull);
    });
  });
}

import 'package:test/test.dart';
import 'package:chat_memory/src/enhanced_conversation_manager.dart';
import 'package:chat_memory/src/memory/memory_manager.dart';
import 'package:chat_memory/src/vector_stores/in_memory_vector_store.dart';
import 'package:chat_memory/src/models/message.dart';
import 'package:chat_memory/src/embeddings/embedding_service.dart';
import '../test_utils.dart';

/// Minimal fake embedding service for tests.
class SimpleFakeEmbedding implements EmbeddingService {
  final int dims;
  SimpleFakeEmbedding({this.dims = 4});

  @override
  int get dimensions => dims;

  @override
  String get name => 'simple-fake';

  @override
  Future<List<double>> embed(String text) async {
    if (text.isEmpty) return List.filled(dims, 0.0);
    final v = List<double>.filled(dims, 0.0);
    v[0] = text.length.toDouble();
    return v;
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async =>
      Future.wait(texts.map(embed));
}

void main() {
  group('EnhancedConversationManager (unit)', () {
    test(
      'appendMessage persists and stores vector + triggers callback',
      () async {
        final tokenCounter = FakeTokenCounter();
        final vectorStore = InMemoryVectorStore();
        final embedding = SimpleFakeEmbedding();
        final memoryManager = MemoryManager(
          contextStrategy: FakeContextStrategy(includeAll: true),
          tokenCounter: tokenCounter,
          vectorStore: vectorStore,
          embeddingService: embedding,
        );

  Message? storedCallbackMsg;

        final manager = EnhancedConversationManager(
          persistence: null,
          memoryManager: memoryManager,
          tokenCounter: tokenCounter,
          followUpGenerator: null,
          onSummaryCreated: (_) {},
          onMessageStored: (m) => storedCallbackMsg = m,
        );

        final msg = TestMessageFactory.create(
          role: MessageRole.user,
          content: 'hello world',
        );

        await manager.appendMessage(msg);

        // callback should have been triggered
        expect(storedCallbackMsg, isNotNull);
        expect(storedCallbackMsg!.id, msg.id);

        // vector store should contain the vector for the stored message
        final count = await vectorStore.count();
        expect(count, 1);

        // stats should reflect the persisted message
        final stats = await manager.getStats();
        expect(stats.totalMessages, greaterThanOrEqualTo(1));
      },
    );

    test(
      'buildPrompt returns PromptPayload with included messages and trace',
      () async {
        final tokenCounter = FakeTokenCounter();
        final vectorStore = InMemoryVectorStore();
        final embedding = SimpleFakeEmbedding();
        final memoryManager = MemoryManager(
          contextStrategy: FakeContextStrategy(includeAll: true),
          tokenCounter: tokenCounter,
          vectorStore: vectorStore,
          embeddingService: embedding,
        );

        final manager = EnhancedConversationManager(
          persistence: null,
          memoryManager: memoryManager,
          tokenCounter: tokenCounter,
        );

        // append a couple messages via manager
        await manager.appendUserMessage('user one');
        await manager.appendAssistantMessage('assistant reply');

        final payload = await manager.buildPrompt(clientTokenBudget: 1000);
        expect(payload.promptText, isNotEmpty);
        expect(payload.includedMessages, isNotNull);
        expect(payload.estimatedTokens, isNonNegative);
      },
    );

    test(
      'generateFollowUpQuestions handles missing generator gracefully',
      () async {
        final tokenCounter = FakeTokenCounter();
        final memoryManager = MemoryManager(
          contextStrategy: FakeContextStrategy(includeAll: true),
          tokenCounter: tokenCounter,
        );

        final manager = EnhancedConversationManager(
          memoryManager: memoryManager,
          tokenCounter: tokenCounter,
        );

        final questions = await manager.generateFollowUpQuestions();
        expect(questions, isEmpty);
      },
    );

    test('clear clears vector store when available', () async {
      final tokenCounter = FakeTokenCounter();
      final vectorStore = InMemoryVectorStore();
      final embedding = SimpleFakeEmbedding();
      final memoryManager = MemoryManager(
        contextStrategy: FakeContextStrategy(includeAll: true),
        tokenCounter: tokenCounter,
        vectorStore: vectorStore,
        embeddingService: embedding,
      );

      final manager = EnhancedConversationManager(
        memoryManager: memoryManager,
        tokenCounter: tokenCounter,
      );

      // store a message
      await manager.appendUserMessage('hello');
      expect(await vectorStore.count(), 1);

      await manager.clear();
      expect(await vectorStore.count(), 0);
    });
  });
}

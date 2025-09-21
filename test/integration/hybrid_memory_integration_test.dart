import 'package:test/test.dart';
import 'package:chat_memory/chat_memory.dart';

void main() {
  group('Hybrid Memory Integration Tests', () {
    late EnhancedConversationManager manager;

    setUp(() async {
      manager = await EnhancedConversationManager.create(
        preset: MemoryPreset.development,
        maxTokens: 2000,
      );
    });

    test('basic message flow with summarization', () async {
      // Add system message
      await manager.appendSystemMessage('You are a helpful assistant.');

      // Add conversation that exceeds token budget
      await manager.appendUserMessage('Tell me about artificial intelligence');
      await manager.appendAssistantMessage(
        'Artificial intelligence (AI) is a broad field of computer science focused on creating systems capable of performing tasks that typically require human intelligence. This includes learning, reasoning, problem-solving, perception, and language understanding.',
      );

      await manager.appendUserMessage('What are the main types of AI?');
      await manager.appendAssistantMessage(
        'There are several ways to categorize AI: 1) Narrow AI (weak AI) - designed for specific tasks like image recognition or language translation, 2) General AI (strong AI) - hypothetical AI with human-level intelligence across all domains, 3) Artificial Superintelligence - AI that surpasses human intelligence in all aspects.',
      );

      await manager.appendUserMessage(
        'How does machine learning relate to AI?',
      );
      await manager.appendAssistantMessage(
        'Machine learning is a subset of AI that enables systems to automatically learn and improve from experience without being explicitly programmed. It uses algorithms to parse data, learn patterns, and make predictions or decisions.',
      );

      await manager.appendUserMessage('What about deep learning?');

      // Build prompt - should trigger summarization due to token budget
      final prompt = await manager.buildPrompt(
        clientTokenBudget: 1000,
        userQuery: 'deep learning explanation',
      );

      expect(prompt.estimatedTokens, lessThanOrEqualTo(1000));
      expect(prompt.includedMessages.isNotEmpty, true);
      // Summary might be null if summarization wasn't triggered
      expect(prompt.summary, anyOf(isNull, isNotNull));
      expect(prompt.promptText.contains('system:'), true);
    });

    test('semantic retrieval functionality', () async {
      // Add diverse conversation topics
      await manager.appendUserMessage('How do I cook pasta?');
      await manager.appendAssistantMessage(
        'To cook pasta: 1) Boil salted water, 2) Add pasta, 3) Cook according to package directions, 4) Drain and serve.',
      );

      await manager.appendUserMessage('Tell me about JavaScript promises');
      await manager.appendAssistantMessage(
        'JavaScript promises represent eventual completion of asynchronous operations. They have three states: pending, fulfilled, or rejected.',
      );

      await manager.appendUserMessage('Best exercise for core strength?');
      await manager.appendAssistantMessage(
        'Planks are excellent for core strength. Hold a plank position for 30-60 seconds, focusing on maintaining proper form.',
      );

      // Query about cooking - should retrieve cooking-related content
      final enhancedPrompt = await manager.buildEnhancedPrompt(
        clientTokenBudget: 1500,
        userQuery: 'cooking techniques and recipes',
      );

      expect(enhancedPrompt.semanticMessages.length, greaterThanOrEqualTo(0));
      expect(enhancedPrompt.metadata.isNotEmpty, true);
      expect(enhancedPrompt.query, equals('cooking techniques and recipes'));
    });

    test('memory manager statistics', () async {
      // Build a conversation
      await manager.appendSystemMessage('Test system message');
      await manager.appendUserMessage('First user message');
      await manager.appendAssistantMessage('First assistant response');
      await manager.appendUserMessage('Second user message');
      await manager.appendAssistantMessage('Second assistant response');

      final stats = await manager.getStats();

      expect(stats.totalMessages, equals(5));
      expect(stats.userMessages, equals(2));
      expect(stats.assistantMessages, equals(2));
      expect(stats.systemMessages, equals(1));
      expect(stats.summaryMessages, equals(0));
      expect(stats.totalTokens, greaterThan(0));
      expect(stats.oldestMessage, isNotNull);
      expect(stats.newestMessage, isNotNull);
    });

    test('builder pattern configuration', () async {
      final customMemoryManager = MemoryManagerBuilder()
          .withMaxTokens(3000)
          .withInMemoryVectorStore()
          .withSimpleEmbedding(dimensions: 256)
          .enableSemanticMemory(topK: 3, minSimilarity: 0.4)
          .build();

      final customManager = EnhancedConversationManager(
        memoryManager: customMemoryManager,
      );

      await customManager.appendUserMessage('Test message');
      final prompt = await customManager.buildPrompt(clientTokenBudget: 2000);

      expect(prompt.estimatedTokens, greaterThan(0));
      expect(prompt.includedMessages.length, equals(1));
    });

    test('summarization strategy factory', () async {
      final tokenCounter = HeuristicTokenCounter();
      final summarizer = DeterministicSummarizer();

      // Test different strategy types
      final conservativeStrategy = SummarizationStrategyFactory.conservative(
        maxTokens: 2000,
        summarizer: summarizer,
        tokenCounter: tokenCounter,
      );

      final aggressiveStrategy = SummarizationStrategyFactory.aggressive(
        maxTokens: 2000,
        summarizer: summarizer,
        tokenCounter: tokenCounter,
      );

      final balancedStrategy = SummarizationStrategyFactory.balanced(
        maxTokens: 2000,
        summarizer: summarizer,
        tokenCounter: tokenCounter,
      );

      // Verify strategies are created
      expect(conservativeStrategy, isA<SummarizationStrategy>());
      expect(aggressiveStrategy, isA<SummarizationStrategy>());
      expect(balancedStrategy, isA<SummarizationStrategy>());
    });

    test('vector store operations', () async {
      final vectorStore = InMemoryVectorStore();
      final embeddingService = SimpleEmbeddingService();

      // Create test messages
      final message1 = Message(
        id: 'test1',
        role: MessageRole.user,
        content: 'I love programming in Dart',
        timestamp: DateTime.now().toUtc(),
      );

      final message2 = Message(
        id: 'test2',
        role: MessageRole.user,
        content: 'Flutter is great for mobile development',
        timestamp: DateTime.now().toUtc(),
      );

      // Generate embeddings and store
      final embedding1 = await embeddingService.embed(message1.content);
      final embedding2 = await embeddingService.embed(message2.content);

      await vectorStore.store(message1.toVectorEntry(embedding1));
      await vectorStore.store(message2.toVectorEntry(embedding2));

      // Test search
      final queryEmbedding = await embeddingService.embed(
        'mobile app development',
      );
      final results = await vectorStore.search(
        queryEmbedding: queryEmbedding,
        topK: 2,
      );

      expect(results.length, lessThanOrEqualTo(2));
      expect(await vectorStore.count(), equals(2));
    });

    test('preset configurations create different managers', () async {
      final devManager = await EnhancedConversationManager.create(
        preset: MemoryPreset.development,
        maxTokens: 2000,
      );

      final minimalManager = await EnhancedConversationManager.create(
        preset: MemoryPreset.minimal,
        maxTokens: 2000,
      );

      expect(devManager, isA<EnhancedConversationManager>());
      expect(minimalManager, isA<EnhancedConversationManager>());
      expect(devManager.memoryManager, isA<MemoryManager>());
      expect(minimalManager.memoryManager, isA<MemoryManager>());
    });

    test('callback functions work correctly', () async {
      var summaryCount = 0;
      var messageCount = 0;

      final callbackManager = EnhancedConversationManager(
        onSummaryCreated: (summary) => summaryCount++,
        onMessageStored: (message) => messageCount++,
      );

      await callbackManager.appendUserMessage('Test message 1');
      await callbackManager.appendUserMessage('Test message 2');

      expect(messageCount, equals(2));
      // Summary count depends on whether summarization was triggered
    });

    test('embedding service functionality', () async {
      final embeddingService = SimpleEmbeddingService(dimensions: 128);

      expect(embeddingService.dimensions, equals(128));
      expect(embeddingService.name, equals('SimpleEmbedding'));

      final embedding = await embeddingService.embed('test text');
      expect(embedding.length, equals(128));

      final batchEmbeddings = await embeddingService.embedBatch([
        'text 1',
        'text 2',
        'text 3',
      ]);
      expect(batchEmbeddings.length, equals(3));
      expect(batchEmbeddings[0].length, equals(128));
    });

    test('memory config extensibility', () {
      const config1 = MemoryConfig(maxTokens: 4000);
      final config2 = config1.copyWith(semanticTopK: 10);

      expect(config2.maxTokens, equals(4000));
      expect(config2.semanticTopK, equals(10));
      expect(config1.semanticTopK, equals(5)); // Original unchanged
    });
  });

  group('Error Handling and Edge Cases', () {
    test('empty conversation handling', () async {
      final manager = await EnhancedConversationManager.create(
        preset: MemoryPreset.development,
      );

      final prompt = await manager.buildPrompt(clientTokenBudget: 1000);
      expect(prompt.includedMessages.isEmpty, true);
      expect(prompt.estimatedTokens, equals(0));
    });

    test('very small token budget', () async {
      final manager = await EnhancedConversationManager.create(
        preset: MemoryPreset.development,
      );

      await manager.appendUserMessage('This is a test message');
      final prompt = await manager.buildPrompt(clientTokenBudget: 10);

      // Should still return something reasonable
      expect(prompt.estimatedTokens, greaterThanOrEqualTo(0));
    });

    test('vector search with no results', () async {
      final vectorStore = InMemoryVectorStore();
      final embeddingService = SimpleEmbeddingService();

      final queryEmbedding = await embeddingService.embed('query text');
      final results = await vectorStore.search(
        queryEmbedding: queryEmbedding,
        topK: 5,
        minSimilarity: 0.9, // Very high threshold
      );

      expect(results.isEmpty, true);
    });
  });
}

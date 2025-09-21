import 'package:test/test.dart';
import 'package:chat_memory/src/processing/message_processor.dart';
import 'package:chat_memory/src/processing/message_chunker.dart';
import 'package:chat_memory/src/processing/embedding_pipeline.dart';
import 'package:chat_memory/src/processing/processing_config.dart';
import 'package:chat_memory/src/memory/embeddings/simple_embedding_service.dart';
import 'package:chat_memory/src/memory/vector_stores/in_memory_vector_store.dart';
import 'package:chat_memory/src/memory/session_store.dart';
import 'package:chat_memory/src/memory/memory_manager.dart';
import 'package:chat_memory/src/core/models/message.dart';
import 'package:chat_memory/src/core/utils/token_counter.dart';
import '../test_utils.dart';

void main() {
  group('Processing Pipeline Integration', () {
    late MessageProcessor processor;
    late MessageChunker chunker;
    late EmbeddingPipeline embeddingPipeline;
    late SessionStore sessionStore;
    late InMemoryVectorStore vectorStore;

    setUp(() {
      final tokenCounter = HeuristicTokenCounter();
      final embeddingService = SimpleEmbeddingService(dimensions: 128);
      vectorStore = InMemoryVectorStore();

      chunker = MessageChunker(tokenCounter: tokenCounter);
      embeddingPipeline = EmbeddingPipeline(embeddingService: embeddingService);
      sessionStore = SessionStore(
        vectorStore: vectorStore,
        embeddingService: embeddingService,
        config: const MemoryConfig(enableSemanticMemory: true),
      );

      processor = MessageProcessor(
        chunker: chunker,
        embeddingPipeline: embeddingPipeline,
        sessionStore: sessionStore,
      );
    });

    test('end-to-end processing with development preset', () async {
      final messages = [
        TestMessageFactory.create(
          content:
              'This is a comprehensive test message that will be processed through the entire pipeline including chunking, embedding generation, and storage in the vector database.',
        ),
        TestMessageFactory.create(
          content:
              'Second test message with different content to verify batch processing capabilities.',
        ),
      ];

      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.development,
      );

      final result = await processor.processMessages(
        messages,
        config.processingConfig,
      );

      // Verify processing completed successfully
      expect(result.processedMessages.length, equals(2));
      expect(result.errors.isEmpty, isTrue);
      expect(result.stats.successfulMessages, equals(2));
      expect(result.stats.processingTimeMs, greaterThan(0));

      // Verify chunking occurred
      expect(result.chunks.isNotEmpty, isTrue);
      expect(result.chunks.length, greaterThanOrEqualTo(2));

      // Verify embeddings were generated
      expect(result.embeddingResult, isNotNull);
      expect(result.embeddingResult!.embeddings.isNotEmpty, isTrue);
      expect(result.embeddingResult!.isSuccess, isTrue);

      // Verify data was stored in vector store
      final vectorCount = await vectorStore.count();
      expect(vectorCount, greaterThan(0));
    });

    test('production preset handles larger messages efficiently', () async {
      final largeMessage = TestMessageFactory.create(
        content: '''
        This is a very large message that contains multiple paragraphs and should be intelligently chunked.
        
        The first paragraph discusses the importance of effective message processing in modern AI systems.
        It covers topics such as chunking strategies, embedding generation, and vector storage optimization.
        
        The second paragraph delves into specific implementation details including circuit breaker patterns,
        retry logic with exponential backoff, and adaptive batch sizing for optimal performance.
        
        The third paragraph explores monitoring and observability features including metrics collection,
        detailed logging, and performance profiling capabilities that are essential for production systems.
        
        The final paragraph summarizes the benefits of using a sophisticated processing pipeline
        for handling conversational AI workloads at scale with reliability and efficiency.
        ''',
      );

      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.production,
      );

      final result = await processor.processMessages([
        largeMessage,
      ], config.processingConfig);

      expect(result.errors.isEmpty, isTrue);
      expect(result.chunks.length, greaterThan(1)); // Should be chunked
      expect(result.embeddingResult!.embeddings.isNotEmpty, isTrue);

      // Production preset should handle this efficiently
      expect(
        result.stats.processingTimeMs,
        lessThan(10000),
      ); // Under 10 seconds
    });

    test('high throughput preset processes many messages', () async {
      final messages = List.generate(
        50,
        (i) => TestMessageFactory.create(
          content: 'Test message number $i with unique content for processing.',
        ),
      );

      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.highThroughput,
      );

      final stopwatch = Stopwatch()..start();
      final result = await processor.processMessages(
        messages,
        config.processingConfig,
      );
      stopwatch.stop();

      expect(result.errors.isEmpty, isTrue);
      expect(result.processedMessages.length, equals(50));
      expect(result.embeddingResult!.embeddings.length, equals(50));

      // High throughput should be fast
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(30000),
      ); // Under 30 seconds

      // Verify all data was stored
      final vectorCount = await vectorStore.count();
      expect(vectorCount, equals(50));
    });

    test('low latency preset prioritizes speed', () async {
      final message = TestMessageFactory.create(
        content: 'Short message for low latency processing.',
      );

      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.lowLatency,
      );

      final stopwatch = Stopwatch()..start();
      final result = await processor.processMessages([
        message,
      ], config.processingConfig);
      stopwatch.stop();

      expect(result.errors.isEmpty, isTrue);
      expect(result.processedMessages.length, equals(1));

      // Low latency should be very fast for single message
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Under 1 second
    });

    test('memory optimized preset handles resource constraints', () async {
      final messages = List.generate(
        20,
        (i) => TestMessageFactory.create(
          content: 'Message $i for memory optimization testing.',
        ),
      );

      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.memoryOptimized,
      );

      final result = await processor.processMessages(
        messages,
        config.processingConfig,
      );

      expect(result.errors.isEmpty, isTrue);
      expect(result.processedMessages.length, equals(20));

      // Memory optimized should create smaller chunks
      final avgChunkSize = result.chunks.isNotEmpty
          ? result.chunks.map((c) => c.content.length).reduce((a, b) => a + b) /
                result.chunks.length
          : 0;
      expect(avgChunkSize, lessThan(100)); // Small chunks for memory efficiency
    });

    test('pipeline handles mixed content types', () async {
      final messages = [
        TestMessageFactory.create(content: 'Short message'),
        TestMessageFactory.create(
          content: 'Medium length message with some more content to process.',
        ),
        TestMessageFactory.create(
          content: '''
          Very long message with multiple lines and paragraphs.
          
          This message should be chunked into multiple pieces
          to demonstrate the pipeline's ability to handle
          varied content lengths and structures.
          
          The chunking strategy should adapt appropriately
          to maintain semantic coherence while respecting
          token and character limits.
          ''',
        ),
      ];

      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.production,
      );

      final result = await processor.processMessages(
        messages,
        config.processingConfig,
      );

      expect(result.errors.isEmpty, isTrue);
      expect(result.processedMessages.length, equals(3));

      // Should have more chunks than messages due to long message
      expect(result.chunks.length, greaterThan(3));

      // All embeddings should be generated successfully
      expect(
        result.embeddingResult!.embeddings.length,
        equals(result.chunks.length),
      );
      expect(result.embeddingResult!.failures.isEmpty, isTrue);
    });

    test('pipeline error handling and recovery', () async {
      final messages = [
        TestMessageFactory.create(content: 'Good message'),
        Message(
          id: 'bad_message',
          role: MessageRole.user,
          content: '', // Empty content might cause issues
          timestamp: DateTime.utc(2025, 1, 1),
        ),
        TestMessageFactory.create(content: 'Another good message'),
      ];

      final config =
          ProcessingPipelineConfig.fromPreset(
            ProcessingPreset.production,
          ).copyWith(
            processingConfig: const ProcessingConfig(
              stages: [
                ProcessingStage.validation,
                ProcessingStage.chunking,
                ProcessingStage.embedding,
                ProcessingStage.storage,
              ],
              continueOnError: true,
            ),
          );

      final result = await processor.processMessages(
        messages,
        config.processingConfig,
      );

      // Should filter out bad message during validation
      expect(result.processedMessages.length, equals(2));
      expect(
        result.processedMessages.every((m) => m.content.isNotEmpty),
        isTrue,
      );

      // Should still process good messages successfully
      expect(result.embeddingResult!.embeddings.length, equals(2));
    });

    test('pipeline statistics and monitoring', () async {
      final messages = List.generate(
        10,
        (i) => TestMessageFactory.create(
          content: 'Test message $i for statistics gathering.',
        ),
      );

      final config = ProcessingPipelineConfig.fromPreset(
        ProcessingPreset.production,
      );

      final result = await processor.processMessages(
        messages,
        config.processingConfig,
      );

      // Verify comprehensive statistics
      expect(result.stats.totalMessages, equals(10));
      expect(result.stats.successfulMessages, equals(10));
      expect(result.stats.totalChunks, greaterThanOrEqualTo(10));
      expect(result.stats.processingTimeMs, greaterThan(0));
      expect(result.stats.stageTimings.isNotEmpty, isTrue);

      // Verify embedding statistics
      final embeddingStats = result.embeddingResult!.stats;
      expect(embeddingStats.totalItems, equals(result.chunks.length));
      expect(embeddingStats.successfulItems, equals(result.chunks.length));
      expect(embeddingStats.averageTimePerItem, greaterThan(0.0));

      // Verify chunker statistics
      final chunkerStats = chunker.getStatistics();
      expect(chunkerStats.totalMessages, greaterThanOrEqualTo(10));
      expect(chunkerStats.averageChunksPerMessage, greaterThan(0.0));
    });

    test('custom configuration override', () async {
      final messages = [
        TestMessageFactory.create(
          content: 'Message with custom processing configuration.',
        ),
      ];

      final customConfig =
          ProcessingPipelineConfig.fromPreset(
            ProcessingPreset.development,
          ).copyWith(
            chunkingConfig: const ChunkingConfig(
              maxChunkTokens: 50,
              strategy: ChunkingStrategy.sentenceBoundary,
              preserveSentences: true,
            ),
            embeddingConfig: const EmbeddingConfig(
              maxBatchSize: 1,
              enableCaching: false,
              enableValidation: true,
            ),
          );

      final result = await processor.processMessages(
        messages,
        customConfig.processingConfig,
      );

      expect(result.errors.isEmpty, isTrue);
      expect(result.processedMessages.length, equals(1));

      // Custom chunking should create appropriate chunks
      expect(result.chunks.isNotEmpty, isTrue);

      // Should process successfully with custom settings
      expect(result.embeddingResult!.isSuccess, isTrue);
    });
  });
}

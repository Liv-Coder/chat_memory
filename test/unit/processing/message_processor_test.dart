import 'package:test/test.dart';
import 'package:chat_memory/src/processing/message_processor.dart';
import 'package:chat_memory/src/processing/message_chunker.dart';
import 'package:chat_memory/src/processing/embedding_pipeline.dart';
import 'package:chat_memory/src/memory/session_store.dart';
import 'package:chat_memory/src/memory/memory_manager.dart';
import 'package:chat_memory/src/core/models/message.dart';
import 'package:chat_memory/src/memory/embeddings/embedding_service.dart'
    hide EmbeddingConfig;
import '../../test_utils.dart';

/// Mock components for testing
class MockMessageChunker extends MessageChunker {
  final List<MessageChunk> _mockChunks = [];

  MockMessageChunker() : super(tokenCounter: FakeTokenCounter());

  void setMockChunks(List<MessageChunk> chunks) {
    _mockChunks.clear();
    _mockChunks.addAll(chunks);
  }

  @override
  Future<List<MessageChunk>> chunkMessage(
    Message message,
    ChunkingConfig config,
  ) async {
    if (_mockChunks.isNotEmpty) {
      return _mockChunks;
    }

    // Default: return single chunk
    return [
      MessageChunk(
        id: '${message.id}_chunk_0',
        content: message.content,
        parentMessageId: message.id,
        chunkIndex: 0,
        totalChunks: 1,
        startPosition: 0,
        endPosition: message.content.length,
        estimatedTokens: message.content.length ~/ 4,
      ),
    ];
  }
}

class MockEmbeddingPipeline extends EmbeddingPipeline {
  bool _shouldFail = false;
  EmbeddingResult? _mockResult;

  MockEmbeddingPipeline() : super(embeddingService: _MockEmbeddingService());

  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  void setMockResult(EmbeddingResult result) {
    _mockResult = result;
  }

  @override
  Future<EmbeddingResult> processChunks(
    List<MessageChunk> chunks,
    EmbeddingConfig config,
  ) async {
    if (_shouldFail) {
      throw Exception('Mock embedding pipeline failure');
    }

    if (_mockResult != null) {
      return _mockResult!;
    }

    // Default: return successful results
    final embeddings = chunks
        .map(
          (chunk) => EmbeddingInfo(
            content: chunk.content,
            embedding: List.generate(128, (i) => i / 128.0),
            qualityScore: 0.8,
            processingTimeMs: 100,
          ),
        )
        .toList();

    return EmbeddingResult(
      embeddings: embeddings,
      failures: [],
      stats: EmbeddingStats(
        totalItems: chunks.length,
        successfulItems: chunks.length,
        failedItems: 0,
        totalTimeMs: embeddings.length * 100,
        averageTimePerItem: 100.0,
        peakBatchSize: chunks.length,
        totalRetries: 0,
        cacheHitRate: 0.0,
      ),
      metadata: {},
    );
  }
}

class _MockEmbeddingService implements EmbeddingService {
  @override
  int get dimensions => 128;

  @override
  String get name => 'MockEmbedding';

  @override
  Future<List<double>> embed(String text) async {
    return List.generate(dimensions, (i) => i / dimensions);
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    return texts
        .map((text) => List.generate(dimensions, (i) => i / dimensions))
        .toList();
  }
}

class MockSessionStore extends SessionStore {
  final List<Message> _storedMessages = [];
  bool _shouldFail = false;

  MockSessionStore()
    : super(
        vectorStore: null,
        embeddingService: _MockEmbeddingService(),
        config: const MemoryConfig(),
      );

  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  List<Message> get storedMessages => List.unmodifiable(_storedMessages);

  void clearStored() {
    _storedMessages.clear();
  }

  @override
  Future<void> storeMessage(Message message) async {
    if (_shouldFail) {
      throw Exception('Mock session store failure');
    }
    _storedMessages.add(message);
  }
}

void main() {
  group('MessageProcessor', () {
    late MessageProcessor processor;
    late MockMessageChunker mockChunker;
    late MockEmbeddingPipeline mockEmbeddingPipeline;
    late MockSessionStore mockSessionStore;

    setUp(() {
      mockChunker = MockMessageChunker();
      mockEmbeddingPipeline = MockEmbeddingPipeline();
      mockSessionStore = MockSessionStore();

      processor = MessageProcessor(
        chunker: mockChunker,
        embeddingPipeline: mockEmbeddingPipeline,
        sessionStore: mockSessionStore,
      );
    });

    tearDown(() {
      mockSessionStore.clearStored();
    });

    test('processes messages through complete pipeline', () async {
      final messages = [
        TestMessageFactory.create(content: 'First message'),
        TestMessageFactory.create(content: 'Second message'),
      ];

      const config = ProcessingConfig(
        stages: [
          ProcessingStage.validation,
          ProcessingStage.chunking,
          ProcessingStage.embedding,
          ProcessingStage.storage,
        ],
      );

      final result = await processor.processMessages(messages, config);

      expect(result.processedMessages.length, equals(2));
      expect(result.chunks.length, equals(2));
      expect(result.embeddingResult, isNotNull);
      expect(result.embeddingResult!.embeddings.length, equals(2));
      expect(result.errors.isEmpty, isTrue);
      expect(result.stats.totalMessages, equals(2));
      expect(result.stats.successfulMessages, equals(2));

      // Check that messages were stored
      expect(mockSessionStore.storedMessages.length, equals(2));
    });

    test('handles validation stage correctly', () async {
      final messages = [
        TestMessageFactory.create(content: 'Valid message'),
        Message(
          id: 'empty_content',
          role: MessageRole.user,
          content: '', // Empty content should be filtered out
          timestamp: DateTime.utc(2025, 1, 1),
        ),
        Message(
          id: '', // Empty ID should be filtered out
          role: MessageRole.user,
          content: 'Valid content',
          timestamp: DateTime.utc(2025, 1, 1),
        ),
      ];

      const config = ProcessingConfig(stages: [ProcessingStage.validation]);

      final result = await processor.processMessages(messages, config);

      // Only one message should pass validation
      expect(result.processedMessages.length, equals(1));
      expect(result.processedMessages.first.content, equals('Valid message'));
    });

    test('handles chunking stage', () async {
      final messages = [
        TestMessageFactory.create(content: 'Message to be chunked'),
      ];

      // Set up mock chunker to return multiple chunks
      mockChunker.setMockChunks([
        MessageChunk(
          id: 'chunk_0',
          content: 'First chunk',
          parentMessageId: messages.first.id,
          chunkIndex: 0,
          totalChunks: 2,
          startPosition: 0,
          endPosition: 11,
          estimatedTokens: 3,
        ),
        MessageChunk(
          id: 'chunk_1',
          content: 'Second chunk',
          parentMessageId: messages.first.id,
          chunkIndex: 1,
          totalChunks: 2,
          startPosition: 12,
          endPosition: 24,
          estimatedTokens: 3,
        ),
      ]);

      const config = ProcessingConfig(stages: [ProcessingStage.chunking]);

      final result = await processor.processMessages(messages, config);

      expect(result.chunks.length, equals(2));
      expect(result.chunks.first.content, equals('First chunk'));
      expect(result.chunks.last.content, equals('Second chunk'));
    });

    test('handles embedding stage', () async {
      final messages = [TestMessageFactory.create(content: 'Message to embed')];

      const config = ProcessingConfig(
        stages: [ProcessingStage.chunking, ProcessingStage.embedding],
      );

      final result = await processor.processMessages(messages, config);

      expect(result.embeddingResult, isNotNull);
      expect(result.embeddingResult!.embeddings.length, equals(1));
      expect(
        result.embeddingResult!.embeddings.first.content,
        equals('Message to embed'),
      );
    });

    test('handles storage stage', () async {
      final messages = [TestMessageFactory.create(content: 'Message to store')];

      const config = ProcessingConfig(
        stages: [ProcessingStage.chunking, ProcessingStage.storage],
      );

      final result = await processor.processMessages(messages, config);

      expect(result, isNotNull);
      expect(mockSessionStore.storedMessages.length, equals(1));
      expect(
        mockSessionStore.storedMessages.first.content,
        equals('Message to store'),
      );
    });

    test('continues processing on errors when configured', () async {
      final messages = [
        TestMessageFactory.create(content: 'Good message'),
        TestMessageFactory.create(content: 'Bad message'),
      ];

      // Make embedding pipeline fail
      mockEmbeddingPipeline.setShouldFail(true);

      const config = ProcessingConfig(
        stages: [ProcessingStage.chunking, ProcessingStage.embedding],
        continueOnError: true,
      );

      final result = await processor.processMessages(messages, config);

      expect(result.errors.isNotEmpty, isTrue);
      expect(result.stats.successfulMessages, lessThan(2));

      // Should have attempted to process all messages despite failures
      expect(result.chunks.length, equals(2));
    });

    test(
      'stops processing on errors when not configured to continue',
      () async {
        final messages = [
          TestMessageFactory.create(content: 'Message that will fail'),
        ];

        // Make session store fail
        mockSessionStore.setShouldFail(true);

        const config = ProcessingConfig(
          stages: [ProcessingStage.chunking, ProcessingStage.storage],
          continueOnError: false,
        );

        expect(
          () => processor.processMessages(messages, config),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('tracks processing statistics correctly', () async {
      final messages = List.generate(
        5,
        (i) => TestMessageFactory.create(content: 'Message $i'),
      );

      const config = ProcessingConfig(
        stages: [
          ProcessingStage.validation,
          ProcessingStage.chunking,
          ProcessingStage.embedding,
        ],
      );

      final result = await processor.processMessages(messages, config);

      expect(result.stats.totalMessages, equals(5));
      expect(result.stats.totalChunks, equals(5));
      expect(result.stats.processingTimeMs, greaterThan(0));
      expect(result.stats.stageTimings.length, equals(3));
      expect(
        result.stats.stageTimings.containsKey(ProcessingStage.validation),
        isTrue,
      );
      expect(
        result.stats.stageTimings.containsKey(ProcessingStage.chunking),
        isTrue,
      );
      expect(
        result.stats.stageTimings.containsKey(ProcessingStage.embedding),
        isTrue,
      );
    });

    test('handles empty message list', () async {
      const config = ProcessingConfig();

      final result = await processor.processMessages([], config);

      expect(result.processedMessages.isEmpty, isTrue);
      expect(result.chunks.isEmpty, isTrue);
      expect(result.embeddingResult, isNull);
      expect(result.errors.isEmpty, isTrue);
      expect(result.stats.totalMessages, equals(0));
    });

    test('handles missing components gracefully', () async {
      // Create processor without chunker
      final minimalProcessor = MessageProcessor();

      final messages = [TestMessageFactory.create(content: 'Test message')];

      const config = ProcessingConfig(stages: [ProcessingStage.chunking]);

      final result = await minimalProcessor.processMessages(messages, config);

      // Should handle missing chunker gracefully
      expect(result.chunks.isEmpty, isTrue);
      expect(result.errors.isEmpty, isTrue);
    });

    test('post-processing stage executes', () async {
      final messages = [TestMessageFactory.create(content: 'Test message')];

      const config = ProcessingConfig(
        stages: [
          ProcessingStage.chunking,
          ProcessingStage.embedding,
          ProcessingStage.postProcessing,
        ],
      );

      final result = await processor.processMessages(messages, config);

      // Post-processing doesn't modify the result in the base implementation,
      // but it should complete without errors
      expect(result.errors.isEmpty, isTrue);
      expect(
        result.stats.stageTimings.containsKey(ProcessingStage.postProcessing),
        isTrue,
      );
    });

    test('processes stages in correct order', () async {
      final messages = [TestMessageFactory.create(content: 'Test message')];

      const config = ProcessingConfig(
        stages: [
          ProcessingStage.validation,
          ProcessingStage.chunking,
          ProcessingStage.embedding,
          ProcessingStage.storage,
          ProcessingStage.postProcessing,
        ],
      );

      final result = await processor.processMessages(messages, config);

      // All stages should be in timing results in order
      final stageNames = result.stats.stageTimings.keys
          .map((s) => s.toString())
          .toList();
      expect(stageNames.length, equals(5));
    });
  });
}

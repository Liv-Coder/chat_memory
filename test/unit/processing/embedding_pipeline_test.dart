import 'package:test/test.dart';
import 'package:chat_memory/src/processing/embedding_pipeline.dart';
import 'package:chat_memory/src/processing/message_chunker.dart';
import 'package:chat_memory/src/memory/embeddings/embedding_service.dart'
    hide EmbeddingConfig;

/// Mock embedding service for testing
class MockEmbeddingService implements EmbeddingService {
  final int _dimensions;
  final List<String> _processedTexts = [];
  bool _shouldFail = false;

  MockEmbeddingService({int dimensions = 128}) : _dimensions = dimensions;

  @override
  int get dimensions => _dimensions;

  @override
  String get name => 'MockEmbedding';

  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  List<String> get processedTexts => List.unmodifiable(_processedTexts);

  void reset() {
    _processedTexts.clear();
    _shouldFail = false;
  }

  @override
  Future<List<double>> embed(String text) async {
    _processedTexts.add(text);

    if (_shouldFail) {
      throw Exception('Mock embedding service failure');
    }

    return List.generate(_dimensions, (i) => i / _dimensions);
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final results = <List<double>>[];
    for (final text in texts) {
      results.add(await embed(text));
    }
    return results;
  }
}

MessageChunk _createTestChunk(String id, String content) {
  return MessageChunk(
    id: id,
    content: content,
    parentMessageId: 'parent_msg',
    chunkIndex: 0,
    totalChunks: 1,
    startPosition: 0,
    endPosition: content.length,
    estimatedTokens: content.split(' ').length,
  );
}

void main() {
  group('EmbeddingPipeline', () {
    late EmbeddingPipeline pipeline;
    late MockEmbeddingService mockEmbeddingService;

    setUp(() {
      mockEmbeddingService = MockEmbeddingService();
      pipeline = EmbeddingPipeline(embeddingService: mockEmbeddingService);
    });

    tearDown(() {
      mockEmbeddingService.reset();
      pipeline.resetStatistics();
    });

    test('processes chunks successfully with default config', () async {
      final chunks = [
        _createTestChunk('chunk1', 'Content for chunk 1'),
        _createTestChunk('chunk2', 'Content for chunk 2'),
        _createTestChunk('chunk3', 'Content for chunk 3'),
      ];

      final config = EmbeddingConfig();
      final result = await pipeline.processChunks(chunks, config);

      expect(result.embeddings.length, equals(3));
      expect(result.failures.isEmpty, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.successRate, equals(1.0));
      expect(mockEmbeddingService.processedTexts.length, equals(3));
    });

    test('handles embedding failures gracefully', () async {
      mockEmbeddingService.setShouldFail(true);

      final chunks = [_createTestChunk('chunk1', 'Content that will fail')];

      final config = EmbeddingConfig();
      final result = await pipeline.processChunks(chunks, config);

      expect(result.embeddings.isEmpty, isTrue);
      expect(result.failures.length, equals(1));
      expect(result.isSuccess, isFalse);
      expect(result.successRate, equals(0.0));
    });

    test('respects circuit breaker configuration', () async {
      final config = EmbeddingConfig(
        circuitBreaker: CircuitBreakerConfig(maxFailures: 2, enabled: true),
      );

      mockEmbeddingService.setShouldFail(true);

      final chunks = [_createTestChunk('chunk1', 'Content 1')];

      // Process chunks and expect failures
      try {
        await pipeline.processChunks(chunks, config);
      } catch (e) {
        // Expected to fail
      }

      final status = pipeline.getCircuitBreakerStatus();
      expect(status.containsKey('state'), isTrue);
    });

    test('tracks processing statistics', () async {
      final config = EmbeddingConfig();

      final chunks = List.generate(
        5,
        (i) => _createTestChunk('chunk$i', 'Content $i'),
      );

      await pipeline.processChunks(chunks, config);

      final stats = pipeline.getStatistics();
      expect(stats.totalItems, equals(5));
      expect(stats.successfulItems, equals(5));
      expect(stats.failedItems, equals(0));
      expect(stats.averageTimePerItem, greaterThan(0.0));
    });
  });
}

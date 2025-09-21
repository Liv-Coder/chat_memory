import 'package:test/test.dart';
import 'package:chat_memory/src/processing/message_chunker.dart';
import 'package:chat_memory/src/core/models/message.dart';
import 'package:chat_memory/src/core/utils/token_counter.dart';
import '../../test_utils.dart';

void main() {
  group('MessageChunker', () {
    late MessageChunker chunker;
    late HeuristicTokenCounter tokenCounter;

    setUp(() {
      tokenCounter = HeuristicTokenCounter();
      chunker = MessageChunker(tokenCounter: tokenCounter);
    });

    test('chunks message with fixed token strategy', () async {
      final message = TestMessageFactory.create(
        content:
            'This is a test message that should be chunked into smaller pieces based on token limits.',
      );

      final config = ChunkingConfig(
        strategy: ChunkingStrategy.fixedToken,
        maxChunkTokens: 5,
      );

      final chunks = await chunker.chunkMessage(message, config);

      expect(chunks.isNotEmpty, isTrue);
      expect(chunks.length, greaterThan(1));

      for (final chunk in chunks) {
        expect(chunk.parentMessageId, equals(message.id));
        expect(chunk.estimatedTokens, lessThanOrEqualTo(config.maxChunkTokens));
      }
    });

    test('chunks message with word boundary strategy', () async {
      final message = TestMessageFactory.create(
        content:
            'This is a message with clear word boundaries that should be respected.',
      );

      final config = ChunkingConfig(
        strategy: ChunkingStrategy.wordBoundary,
        maxChunkTokens: 8,
      );

      final chunks = await chunker.chunkMessage(message, config);

      expect(chunks.isNotEmpty, isTrue);

      for (final chunk in chunks) {
        expect(chunk.parentMessageId, equals(message.id));
      }
    });

    test('creates overlapping chunks when configured', () async {
      final message = TestMessageFactory.create(
        content:
            'This is a longer message that will be chunked with overlap to maintain context.',
      );

      final config = ChunkingConfig(
        strategy: ChunkingStrategy.fixedToken,
        maxChunkTokens: 6,
        overlapRatio: 0.3,
      );

      final chunks = await chunker.chunkMessage(message, config);

      expect(chunks.length, greaterThan(1));

      // Check that consecutive chunks have some overlapping content
      for (int i = 1; i < chunks.length; i++) {
        final prevChunk = chunks[i - 1];
        final currentChunk = chunks[i];

        expect(currentChunk.startPosition, lessThan(prevChunk.endPosition));
      }
    });

    test('preserves chunk metadata and positioning', () async {
      final message = TestMessageFactory.create(
        content: 'Test message for metadata preservation.',
        metadata: {'source': 'test'},
      );

      final config = ChunkingConfig(
        strategy: ChunkingStrategy.fixedToken,
        maxChunkTokens: 4,
      );

      final chunks = await chunker.chunkMessage(message, config);

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];

        expect(chunk.id, isNotEmpty);
        expect(chunk.parentMessageId, equals(message.id));
        expect(chunk.chunkIndex, equals(i));
        expect(chunk.totalChunks, equals(chunks.length));
        expect(chunk.startPosition, isNonNegative);
        expect(chunk.endPosition, greaterThan(chunk.startPosition));
        expect(chunk.estimatedTokens, greaterThan(0));
      }
    });

    test('handles error conditions gracefully', () async {
      final message = TestMessageFactory.create(content: 'Test content');

      // Test with invalid configuration
      expect(
        () => chunker.chunkMessage(message, ChunkingConfig(maxChunkTokens: 0)),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => chunker.chunkMessage(message, ChunkingConfig(overlapRatio: 1.5)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('processes multiple messages correctly', () async {
      final messages = [
        TestMessageFactory.create(content: 'First message content'),
        TestMessageFactory.create(content: 'Second message content'),
        TestMessageFactory.create(content: 'Third message content'),
      ];

      final config = ChunkingConfig(maxChunkTokens: 3);

      final allChunks = <MessageChunk>[];
      for (final message in messages) {
        final chunks = await chunker.chunkMessage(message, config);
        allChunks.addAll(chunks);
      }

      expect(allChunks.length, greaterThanOrEqualTo(messages.length));

      // Verify that chunks from different messages have different parent IDs
      final parentIds = allChunks.map((chunk) => chunk.parentMessageId).toSet();
      expect(parentIds.length, equals(messages.length));
    });

    test('tracks chunking statistics', () async {
      chunker.resetStatistics();

      final messages = List.generate(
        5,
        (i) =>
            TestMessageFactory.create(content: 'Message $i with some content'),
      );

      final config = ChunkingConfig(maxChunkTokens: 3);

      for (final message in messages) {
        await chunker.chunkMessage(message, config);
      }

      final stats = chunker.getStatistics();
      expect(stats.totalMessages, equals(5));
      expect(stats.totalChunks, greaterThan(5));
      expect(stats.averageChunksPerMessage, greaterThan(1.0));
      expect(stats.averageChunkSize, greaterThan(0.0));
    });

    test('MessageChunk toMessage conversion works correctly', () {
      final chunk = MessageChunk(
        id: 'test_chunk',
        content: 'Chunk content',
        parentMessageId: 'parent_msg',
        chunkIndex: 1,
        totalChunks: 3,
        startPosition: 10,
        endPosition: 23,
        estimatedTokens: 5,
        metadata: {'custom': 'value'},
      );

      final message = chunk.toMessage(
        role: MessageRole.user,
        timestamp: DateTime.utc(2025, 1, 1),
      );

      expect(message.id, equals('test_chunk'));
      expect(message.content, equals('Chunk content'));
      expect(message.role, equals(MessageRole.user));
      expect(message.metadata?['isChunk'], isTrue);
      expect(message.metadata?['parentMessageId'], equals('parent_msg'));
      expect(message.metadata?['chunkIndex'], equals(1));
      expect(message.metadata?['totalChunks'], equals(3));
      expect(message.metadata?['custom'], equals('value'));
    });
  });
}
